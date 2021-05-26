`timescale 1 ns/1 ns  // time-unit = 1 ns, precision = 10 ps

module SPIFlashTest;
  integer       cycles;

  reg           clk = 0;
  reg           reset = 0;
  wire          spiOut;
  wire          spiIn;
  wire          spiClk;
  wire          spiCs;

  wire          ready;
  reg           valid = 0;

  reg   [23:0]  address = 0;
  wire  [31:0]  data;

  SPIFlash flash (
    .clk(clk),
    .reset(reset),

    // SPI Port
    .spiOut(spiOut),
    .spiIn(spiIn),
    .spiClk(spiClk),
    .spiCs(spiCs),

    // Memory Interface
    .address(address),
    .data(data),

    .ready(ready),  // Core is ready
    .valid(valid)   // Input data is valid
  );

  reg [7:0]   currentBit    = 0;
  reg [63:0]  testInputData = 0;
  reg [63:0]  readData      = 0;
  reg         lastSpiClk    = 1;

  integer c;

  assign spiIn = testInputData[currentBit];

  always @(posedge clk)
  begin
    if (reset)
    begin
      currentBit = 0;
      lastSpiClk = 1;
      readData   = 0;
      c = 0;
    end
    else if (spiClk & !lastSpiClk) // Nothing
    begin
      currentBit = currentBit == 0 ? 63 : currentBit - 1;
      readData[c] = spiOut;
      c = c + 1;
    end
    lastSpiClk = spiClk;
  end

  initial begin
    $dumpfile("spi_flash_tb.vcd");
    $dumpvars(0, SPIFlashTest);

    clk = 0;
    reset = 1;
    #10
    clk = 1;
    #10
    clk = 0;
    reset = 0;

    // Test
    address       = 24'hDEADFF;
    // readData      = 64'h00000000DEADBEEF;
    testInputData = 64'h000000001ACFFC1D;
    #40
    valid         = 1;
    #10
    clk = 1;
    #10
    clk = 0;

    cycles = 0;
    while (ready)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
      cycles = cycles + 1;
      if (cycles == 64)
      begin
        $error("timeout waiting ready");
        $finish;
      end
    end
    valid         = 0;

    cycles = 0;
    while (!ready)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
      cycles = cycles + 1;
      if (cycles == 512)
      begin
        $error("timeout waiting ready");
        $finish;
      end
    end

    if (readData != 64'h00000000DEADFF03) $error("expected readData to be 64'h00000000DEADFF03 got 64'h%08X", readData);
    if (data     != 32'h1ACFFC1D)         $error("expected data to be 32'h1ACFFC1D got 32'h%08X", data);


    // if (dataRx   != 8'hDE) $error("expected dataRx to be 8'hde got 8'h%02X", dataRx);
    // if (readData != 8'hAD) $error("expected readData to be 8'had got 8'h%02X", readData);

    repeat(64)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
    end
  end

endmodule
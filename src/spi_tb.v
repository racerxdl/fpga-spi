`timescale 1 ns/1 ns  // time-unit = 1 ns, precision = 10 ps

module SPITest;
  integer       cycles;

  reg           clk = 0;
  reg           reset = 0;
  wire          spiOut;
  wire          spiIn;
  wire          spiClk;

  reg   [7:0]   dataTx = 0;
  wire  [7:0]   dataRx;

  wire          ready;
  reg           valid = 0;

  SPIController spic (
    .clk(clk),
    .reset(reset),

    // SPI Port
    .spiOut(spiOut),
    .spiIn(spiIn),
    .spiClk(spiClk),

    // SPI Data
    .dataTx(dataTx),
    .dataRx(dataRx),

    .ready(ready),  // Core is ready
    .valid(valid)   // Input data is valid
  );

  reg [3:0] currentBit = 0;
  reg [7:0] testInputData = 0;
  reg [7:0] readData = 0;
  reg lastSpiClk = 1;

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
      currentBit = currentBit == 0 ? 7 : currentBit - 1;
      readData[c] = spiOut;
      c = c + 1;
    end
    lastSpiClk = spiClk;
  end

  initial begin
    $dumpfile("spi_tb.vcd");
    $dumpvars(0, SPITest);

    clk = 0;
    reset = 1;
    #10
    clk = 1;
    #10
    clk = 0;
    reset = 0;

    // Test
    testInputData = 16'hDE;
    dataTx        = 16'hAD;
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
      if (cycles == 64)
      begin
        $error("timeout waiting ready");
        $finish;
      end
    end

    if (dataRx   != 8'hDE) $error("expected dataRx to be 8'hde got 8'h%02X", dataRx);
    if (readData != 8'hAD) $error("expected readData to be 8'had got 8'h%02X", readData);

    repeat(16)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
    end

    #100
    valid = 0;

    repeat(64)
    begin
      #10
      clk = 1;
      #10
      clk = 0;
    end
  end

endmodule
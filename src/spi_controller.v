module SPIController (
  input   wire          clk,
  input   wire          reset,

  // SPI Port
  output  reg           spiOut,
  input   wire          spiIn,
  output  reg           spiClk,

  // SPI Data
  input   wire  [7:0]   dataTx,
  output  reg   [7:0]   dataRx,

  output  wire          ready,  // Core is ready
  input   wire          valid   // Input data is valid
);

reg isRunning;
reg isDone;
reg start;
reg [3:0] bitCount;

reg [7:0] tmpInput;
reg [7:0] tmpOutput;

assign ready = ~isRunning;

// SPI Data Interface
always @(posedge clk)
begin
  if (reset)
  begin
    dataRx    <= 0;
    isRunning <= 0;
    start     <= 0;
  end
  else
  begin
    if (ready & valid)            // Start sending data
    begin
      isRunning <= 1;             // Start send
      start     <= 1;
    end
    else if (isRunning && isDone && !start) // Data done
    begin
      dataRx    <= tmpInput;      // Latch RX data
      isRunning <= 0;             // Stop sending data
    end
    else
      start     <= 0;             // Reset start
  end
end

// SPI Port
always @(posedge clk)
begin
  if (reset)
  begin
    spiOut    <= 1;
    spiClk    <= 0;
    isDone    <= 1;
    tmpInput  <= 0;
    bitCount  <= 0;
    tmpOutput <= 0;
  end
  else
  begin
    if (start && isDone) // Start
    begin
      isDone            <= 0;       // Started
      tmpInput          <= 0;       // Reset input buffer
      tmpOutput         <= dataTx;  // Latch TX data
      bitCount          <= 0;
      spiOut            <= dataTx[7];
    end
    else
    if (isRunning && !isDone) // Normal operation
    begin
      if (spiClk)
      begin
        if (bitCount == 7) isDone    <= 1;
        bitCount    <= bitCount + 1;
        spiClk      <= 0;
        tmpInput[0] <= spiIn;
        spiOut      <= tmpOutput[7];
      end
      else        // Shift internal buffers
      begin
        spiClk      <= 1;
        // tmpOutput   <= {1'b0, tmpOutput[7:1]}; // Shift data >>
        tmpOutput   <= {tmpOutput[6:0], 1'b0}; // Shift data >>
        tmpInput    <= { tmpInput[6:0], 1'b0}; // Shift data <<
      end
    end
  end
end

endmodule
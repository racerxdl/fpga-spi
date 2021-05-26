module FIFO
  #(
    parameter NUMSAMPLES = 16,
    parameter NUMBITS = 16
) (
  input   wire                    rclk,
  input   wire                    wclk,
  input   wire                    reset,
  input   wire  [NUMBITS-1:0]     wdata,
  input   wire                    readEnable,
  input   wire                    writeEnable,
  output        [NUMBITS-1:0]     rdata,
  output  wire                    isEmpty,
  output  wire                    isFull
);
localparam ABITS  = $clog2(NUMSAMPLES); // Minimum required address bits

reg   [NUMBITS-1:0]       rdata;
reg   [NUMBITS-1:0]       fifo [0:NUMSAMPLES];
wire  [ABITS:0]           writePtr;
wire  [ABITS:0]           readPtr;

GrayCounter #(
  .BITS(ABITS+1)
) writeCounter (
  wclk,
  reset,
  writeEnable,
  writePtr
);

wire              fullOrEmpty = (writePtr[ABITS-1:0] == readPtr[ABITS-1:0]);
wire              empty       = (writePtr == readPtr);
wire  [ABITS-1:0] wAddr       = writePtr[ABITS-1:0];
wire  [ABITS-1:0] rAddr       = readPtr[ABITS-1:0];

GrayCounter #(
  .BITS(ABITS+1)
) readCounter (
  .clk(rclk),
  .reset(reset),
  .enable(readEnable && !empty),
  .out(readPtr)
);


assign            isEmpty     = empty;
assign            isFull      = fullOrEmpty && !empty;

always @(posedge rclk)
begin
  if (readEnable)
    rdata <= reset ? 0 : fifo[rAddr];
  else
    rdata <= 0;
end

always @(posedge wclk)
begin
  if (!reset && writeEnable) fifo[wAddr] <= wdata;
end

endmodule
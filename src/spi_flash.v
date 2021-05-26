module SPIFlash #(
  parameter WORD_BYTE_LEN = 4
) (
  input   wire          clk,
  input   wire          reset,

  // SPI Port
  output  reg           spiOut,
  input   wire          spiIn,
  output  reg           spiClk,
  output  reg           spiCs,

  // Memory Interface
  input   wire   [23:0] address,
  output  reg    [WORD_BYTE_LEN*8-1:0] data,

  output  reg           ready,  // Core is ready
  input   wire          valid   // Input data is valid
);

localparam WORD_BIT_LEN = WORD_BYTE_LEN * 8;
localparam BITS_TO_XLEN = $clog2(WORD_BIT_LEN);

reg   [7:0]   dataTx = 0;
wire  [7:0]   dataRx;
wire          spicReady;
reg           spicValid;

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

  .ready(spicReady),  // Core is ready
  .valid(spicValid)   // Input data is valid
);

localparam STATE_IDLE     = 0;
localparam STATE_CMD      = 1;
localparam STATE_ADDR     = 2;
localparam STATE_DATA     = 3;

localparam STATE_WAIT_ACK = 98; // Wait ready low
localparam STATE_WAIT     = 99; // Wait ready high

reg   [7:0]             tmpData        [0:WORD_BYTE_LEN];
reg   [23:0]            tmpAddr        = 0;
reg   [15:0]            state          = STATE_IDLE;
reg   [15:0]            nextState      = STATE_IDLE;
reg   [3:0]             addrBytesWrote = 0;
reg   [BITS_TO_XLEN:0]  dataBytesRead  = 0;

wire   [WORD_BIT_LEN-1:0] tmpDataUnfolded;

generate
  genvar idx;
  for (idx = 0; idx < WORD_BYTE_LEN; idx = idx+1) begin: unfoldTmpData
    assign tmpDataUnfolded[((idx+1)*8)-1:(idx*8)] = tmpData[idx];
  end
endgenerate

integer i;

always @(posedge clk)
begin
  if (reset)
  begin
    dataTx          <= 0;
    spiCs           <= 1;
    spicValid       <= 0;
    state           <= STATE_IDLE;
    nextState       <= STATE_IDLE;
    addrBytesWrote  <= 0;
    dataBytesRead   <= 0;
  end
  else
  begin
    case (state)
      STATE_IDLE:
      begin
        if (ready & valid)
        begin
          tmpAddr         <= address; // Latch address
          state           <= STATE_CMD;
          ready           <= 0;
        end
        else
        begin
          spiCs           <= 1;
          ready           <= 1;
          data            <= tmpDataUnfolded;
        end
      end

      STATE_CMD:
      begin
        dataTx          <= 8'h03;     // Read Data Command
        nextState       <= STATE_ADDR;
        state           <= STATE_WAIT_ACK;
        spicValid       <= 1;
        spiCs           <= 0;
        addrBytesWrote  <= 0;
        dataBytesRead   <= 0;
      end

      STATE_ADDR:
      begin
        case (addrBytesWrote)
          2: dataTx <= tmpAddr[7:0];
          1: dataTx <= tmpAddr[15:8];
          0: dataTx <= tmpAddr[23:16];
        endcase
        if (spicReady) // Wait to be ready
        begin
          nextState       <= addrBytesWrote == 2 ? STATE_DATA : STATE_ADDR;
          spicValid       <= 1;
          addrBytesWrote  <= addrBytesWrote + 1;
          state           <= STATE_WAIT_ACK;
        end
      end

      STATE_DATA:
      begin
        dataTx <= 8'hFF; // Empty data
        if (spicReady)   // Wait to be ready
        begin
          nextState       <= dataBytesRead == WORD_BYTE_LEN - 1 ? STATE_IDLE : STATE_DATA;
          dataBytesRead   <= dataBytesRead + 1;
          spicValid       <= 1;
          state           <= STATE_WAIT_ACK;
        end
      end

      STATE_WAIT_ACK:
      begin
        if (!spicReady) // Wait SPIC to ack ready
        begin
          state           <= STATE_WAIT;
          spicValid       <= 0;
        end
      end

      STATE_WAIT: // Wait for spic be ready
      begin
        if (spicReady) // SPIC read/wrote data
        begin
          tmpData[dataBytesRead-1] <= dataRx;
          state <= nextState;
        end
      end
    endcase
  end
end

endmodule
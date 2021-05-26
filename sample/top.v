module top (
    input wire clk,

    /*
     * USER I/O (Button, LED)
     */
    input wire button,
    output reg led,
    output wire uart0_txd,

    // SPI Port
    output  reg           spiOut,
    inout   wire          spiIn,
    // output  reg           spiClk, // ECP5 has a primitive to that
    output  reg           spiCs
);

  wire                 reset = ~button;

  wire spiClk;

  `ifndef SIMULATION
  USRMCLK u1 (
      .USRMCLKI(spiClk),
      .USRMCLKTS(reset)
  )/* synthesis syn_noprune=1 */;
  `endif

  wire    [7:0] rdata;
  reg     [7:0] wdata;
  reg     readEnable;
  reg     writeEnable;
  reg     txsend;
  wire    busy;

  SerialTX tx(
      .reset(reset),
      .clk(clk),
      .send(txsend),
      .data(rdata),
      .busy(busy),
      .tx(uart0_txd)
  );

  FIFO #(
      .NUMSAMPLES(128),
      .NUMBITS(8)
  ) stateFifo (
      .rclk(clk), // Read Clock
      .wclk(clk), // Write Clock
      .reset(reset),
      .wdata(wdata),
      .readEnable(readEnable),
      .writeEnable(writeEnable),
      .rdata(rdata),
      .isEmpty(isEmpty),
      .isFull(isFull)
  );

  // FIFO to Serial
  always @(posedge clk)
  begin
      if (reset)
      begin
          txsend      <= 0;
          readEnable  <= 0;
      end
      else
      begin
          if (!isEmpty && !busy && !txsend)
          begin
              if (readEnable)
              begin
                  // Data ready to send
                  txsend      <= 1;
                  readEnable  <= 0;
              end
              else
              begin
                  readEnable  <= 1;
              end
          end
          else
          begin
              txsend      <= 0;
              readEnable  <= 0;
          end
      end
  end

  // reg   [23:0]  flashAddress = 0;
  // wire  [31:0]  flashData;
  // wire          flashDataReady;

  reg [7:0] dataTx;
  wire [7:0] dataRx;
  reg spicValid;

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

  reg [7:0] cmdQueue [0:16];
  reg [7:0] queueBytes;
  reg [7:0] wroteBytes;

  localparam STATE_WRITE_ENABLE = 8'h0,
             STATE_WRITE_REGISTER = 8'h1,
             STATE_SECTOR_ERASE = 8'h2,
             STATE_READ_REG0 = 8'h3,
             STATE_READ_REG1 = 8'h4,
             STATE_READ_FLASH = 8'h5,
             STATE_SPI = 8'hFC,
             STATE_WAIT_ACK = 8'hFD,
             STATE_WAIT= 8'hFE,
             STATE_DONE = 8'hFF;

  reg [7:0] currentState;
  reg [7:0] nextState;

  always @(posedge clk)
  begin
    if (reset)
    begin
      currentState  <= STATE_READ_REG0; //STATE_WRITE_ENABLE;
      spiCs         <= 1;
      led           <= 1;
      wroteBytes    <= 0;
      spicValid     <= 0;
      dataTx        <= 0;
      queueBytes    <= 0;
      cmdQueue[0]   <= 8'h00;
      cmdQueue[1]   <= 8'h00;
      cmdQueue[2]   <= 8'h00;
      cmdQueue[3]   <= 8'h00;
      cmdQueue[4]   <= 8'h00;
      cmdQueue[5]   <= 8'h00;
      writeEnable   <= 0;
    end
    else
    begin
      case (currentState)
        // STATE_WRITE_ENABLE:
        // begin
        //   led           <= 1;
        //   queueBytes    <= 1;
        //   cmdQueue[0]   <= 8'h06; // Write Enable
        //   spiCs         <= 0;
        //   currentState  <= STATE_SPI;
        //   nextState     <= STATE_WRITE_REGISTER;
        // end
        // STATE_WRITE_REGISTER:
        // begin
        //   queueBytes    <= 3;
        //   cmdQueue[0]   <= 8'h01; // Write Register
        //   cmdQueue[1]   <= 8'h00; //
        //   cmdQueue[2]   <= 8'h00; //
        //   cmdQueue[3]   <= 8'h00; //
        //   spiCs         <= 0;
        //   currentState  <= STATE_SPI;
        //   nextState     <= STATE_READ_REG0;
        // end
        // STATE_SECTOR_ERASE:
        // begin
        //   queueBytes    <= 4;
        //   cmdQueue[0]   <= 8'h20; // Erase Sector
        //   cmdQueue[1]   <= 8'h00; //
        //   cmdQueue[2]   <= 8'h00; //
        //   cmdQueue[3]   <= 8'h00; //
        //   spiCs         <= 0;
        //   currentState  <= STATE_SPI;
        //   nextState     <= STATE_READ_REG0;
        // end
        STATE_READ_REG0:
        begin
          queueBytes    <= 2;
          cmdQueue[0]   <= 8'h05; // Read Register
          cmdQueue[1]   <= 8'h00; //
          cmdQueue[2]   <= 8'h00; //
          cmdQueue[3]   <= 8'h00; //
          spiCs         <= 0;
          currentState  <= STATE_SPI;
          nextState     <= STATE_READ_REG1;
        end
        STATE_READ_REG1:
        begin
          queueBytes    <= 2;
          cmdQueue[0]   <= 8'h35; // Read Register
          cmdQueue[1]   <= 8'h00; //
          cmdQueue[2]   <= 8'h00; //
          cmdQueue[3]   <= 8'h00; //
          spiCs         <= 0;
          currentState  <= STATE_SPI;
          nextState     <= STATE_READ_FLASH;
        end
        STATE_READ_FLASH:
        begin
          queueBytes    <= 32;
          cmdQueue[0]   <= 8'h03; // Read Data
          cmdQueue[1]   <= 8'h00; //
          cmdQueue[2]   <= 8'h00; //
          cmdQueue[3]   <= 8'h00; //
          spiCs         <= 0;
          currentState  <= STATE_SPI;
          nextState     <= STATE_DONE;
        end
        STATE_DONE:
        begin
          led           <= 0;
        end

        // SPI Flow
        STATE_SPI:
        begin
          writeEnable   <= 0;
          if (spicReady)   // Wait to be ready
          begin
            if (wroteBytes == queueBytes)
            begin
              // Cycle finished
              spiCs         <= 1;
              currentState  <= nextState;
              wroteBytes    <= 0;
            end
            else
            begin
              dataTx        <= (wroteBytes > 4) ? 0 : cmdQueue[wroteBytes];
              wroteBytes    <= wroteBytes + 1;
              spicValid     <= 1;
              currentState  <= STATE_WAIT_ACK;
            end
          end
        end

        STATE_WAIT_ACK:
        begin
          if (!spicReady) // Wait SPIC to ack ready
          begin
            currentState    <= STATE_WAIT;
            spicValid       <= 0;
          end
        end

        STATE_WAIT: // Wait for spic be ready
        begin
          if (spicReady && !isFull) // SPIC read/wrote data
          begin
            currentState  <= STATE_SPI;
            writeEnable   <= 1; // Write to serial fifo
            wdata         <= dataRx;
          end
        end
      endcase
    end
  end
endmodule
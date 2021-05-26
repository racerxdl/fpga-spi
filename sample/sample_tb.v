`timescale 1 ns/1 ns  // time-unit = 1 ns, precision = 10 ps

module SampleTest;
  reg clk = 0;
  always #10 clk = !clk;

  wire          spiOut;
  wire          spiIn = 0;
  wire          spiClk;
  wire          spiCs;

  reg           reset;
  wire          led;
  wire          uart0_txd;

  top dut (
      clk,
      reset,
      led,
      uart0_txd,
      spiOut,
      spiIn,
      spiCs
  );

  reg d;

  initial begin
    $dumpfile("sampletest.vcd");
    $dumpvars(0, SampleTest);
    d = 0;
    reset = 0;
    #40
    reset = 1;
    #40

    while (dut.currentState != 8'hFF)
    begin
      #20
      d = !d;
    end

    #80000
    $finish;
  end

endmodule
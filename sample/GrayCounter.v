module GrayCounter
  #(
    parameter BITS = 1
  ) (
    input clk,
    input reset,
    input enable,
    output reg [BITS-1:0] out
  );

reg [BITS-1:0] counter;

assign out = {counter[BITS-1], counter[BITS-1:1] ^ counter[BITS-2:0]};

always @(posedge clk)
begin
  if (reset)
    counter <= 0;
  else
    counter <= !enable ? counter : counter + 1;
end

endmodule
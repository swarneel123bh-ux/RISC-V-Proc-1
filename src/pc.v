`timescale 1ns / 1ps

module pc(
  input clk, rstb,
  output [31:0] out
);

  reg [31:0] out_;

  always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
      out_ = 0;
    end
    else begin
      out_ <= out_ + 4;
    end
  end

  assign out = out_;

endmodule;

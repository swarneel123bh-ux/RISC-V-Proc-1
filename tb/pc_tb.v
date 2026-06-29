`timescale 1ns / 1ps

module pc_tb();

  reg clk;
  reg rstb;
  wire [31:0] out;
  pc PC( .clk(clk), .rstb(rstb), .out(out));

  always begin #5; clk = ~clk; end

  initial begin
    $dumpfile("build/pc_tb.vcd");
    $dumpvars(0, pc_tb);
    clk = 0;
    rstb = 0;
    #4;
    rstb = 1;
    #17;
    rstb = 0;
    #20;
    $finish;
  end
endmodule

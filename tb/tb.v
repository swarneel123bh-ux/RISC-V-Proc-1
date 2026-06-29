`timescale 1ns / 1ps

module tb();

  

  initial begin
    $dumpfile("build/tb.vcd");
    $dumpvars(0, tb);
    $finish;
  end
endmodule

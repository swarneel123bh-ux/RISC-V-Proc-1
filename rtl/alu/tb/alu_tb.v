`timescale 1ns / 1ps
module alu_tb ();
  // TODO: declare signals and instantiate alu
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/alu_tb.vcd");
      $dumpvars(0, alu_tb);
    end
    // TODO: stimulus
    #100;
    $finish;
  end
endmodule

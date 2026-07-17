`timescale 1ns / 1ps
module alu_control_tb ();
  // TODO: declare signals and instantiate alu_control
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/alu_control_tb.vcd");
      $dumpvars(0, alu_control_tb);
    end
    // TODO: stimulus
    #100;
    $finish;
  end
endmodule

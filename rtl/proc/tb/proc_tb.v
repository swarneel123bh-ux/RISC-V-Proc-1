`timescale 1ns/1ps

module proc_tb();
  reg rstb;
  proc uut(.rstb(rstb));

  integer i;

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/proc_tb.vcd");
      $dumpvars(0, proc_tb);
    end
    rstb = 0;
    #30;
    rstb = 1;
    #200;
    $finish;
  end
endmodule

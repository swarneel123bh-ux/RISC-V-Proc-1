`timescale 1ns/1ps

module proc_tb();
  reg rstb;
  proc uut(.rstb(rstb));
  integer k;
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/proc_tb.vcd");
      $dumpvars(0, proc_tb);
      $dumpvars(0, uut.regfile[1], uut.regfile[2], uut.regfile[3], uut.regfile[4], uut.regfile[5]);
    end
    rstb = 0; #30; rstb = 1;
    #200;
    for (k = 1; k <= 5; k = k + 1) $display("x%0d = %08h", k, uut.regfile[k]);
    $finish;
  end
endmodule

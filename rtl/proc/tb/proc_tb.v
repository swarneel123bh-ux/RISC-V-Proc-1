`timescale 1ns/1ps

module proc_tb();
  reg rstb;
  proc uut(.rstb(rstb));

  integer i, j;

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/proc_tb.vcd");
      $dumpvars(0, proc_tb);
    end
    $uart_init();
    rstb = 0;
    #30;
    rstb = 1;
    #2000;
    for (j = 0; j <= 31; j = j + 1)
      $display("x%0d = %08h", j, uut.registerfile.registers[j]);
    $finish;
  end
endmodule

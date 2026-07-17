`timescale 1ns / 1ps
module cu_tb ();
  // TODO: declare signals and instantiate cu
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/cu_tb.vcd");
      $dumpvars(0, cu_tb);
    end
    // TODO: stimulus
    #100;
    $finish;
  end
endmodule

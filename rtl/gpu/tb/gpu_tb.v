`timescale 1ns / 1ps
module gpu_tb ();
  // TODO: declare signals and instantiate gpu
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/gpu_tb.vcd");
      $dumpvars(0, gpu_tb);
    end
    // TODO: stimulus
    #100;
    $finish;
  end
endmodule

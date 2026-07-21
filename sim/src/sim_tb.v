`timescale 1ns/1ps

module sim_tb();
  reg rstb;
  proc uut(.rstb(rstb));
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/sim_tb.vcd");
      $dumpvars(0, sim_tb);
    end
    $uart_init();        // raw non-blocking terminal for live UART RX
    rstb = 0;
    #30;
    rstb = 1;

    // No #delay, no dump loop, no $finish: runs until Ctrl-C or a trap.
    // proc.v's own `always #5 clk` keeps simulation time advancing.
  end

  // heartbeat — proves sim time is moving
  // integer beats = 0;
  // always #100000 begin
  //   beats = beats + 1;
  //   $display("[sim] tick %0d @ %0t", beats, $time);
  // end

endmodule

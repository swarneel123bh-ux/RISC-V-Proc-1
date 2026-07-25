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

  // crude done-detector: watch for the CPU storing EOT to UART TX
  always @(posedge uut.clk) begin
    if (uut.dataMem.is_uart && (|uut.memwrap_wstrb) && uut.exmem_alu_out==32'hFFFF0000
        && uut.memwrap_store_out[7:0]==8'h04) begin
      $display("cycles=%0d branches=%0d mispredicts=%0d percentage_mispredicts=%00d%%",
               uut.cyc_count, uut.branch_count, uut.mispredict_count, (uut.mispredict_count*100/uut.branch_count));
      $finish;
    end
  end


endmodule

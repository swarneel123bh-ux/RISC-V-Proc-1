`timescale 1ns/1ps

// ============================================================================
// sim_tb.v -- Claude-authored harness, NOT Swarneel's RTL.
//
// System-level interactive harness: full proc + the gpu_vpi/sdl_screen display
// chain + a live serial console. Runs indefinitely; termination is owned by
// gpu_vpi (closing the SDL window) or by the CPU storing EOT to UART TX.
//
// The console is uart_host.v, shared with proc_tb.v. ESC is passed through to
// the CPU as an ordinary byte here rather than killing the sim, because the SDL
// window already uses ESC as its own quit key (HANDOFF s2).
// ============================================================================

module sim_tb();

  localparam integer CLK_HZ = 27_000_000;
`ifdef SLOW_UART
  localparam integer SIM_DIV = 234;
`else
  localparam integer SIM_DIV = 4;
`endif

  defparam uut.dataMem.uartInst_.BAUD_RATE = CLK_HZ / SIM_DIV;

  reg  rstb;
  wire dut_ser_tx, host_ser_tx;
  reg clk;
  always begin #5; clk = ~clk; end

  proc uut(
  	.clk(clk),
    .rstb   (rstb),
    .ser_rx (host_ser_tx),
    .ser_tx (dut_ser_tx)
  );

  // wire clk = uut.clk;

  uart_host #(
    .CLK_FREQ  (CLK_HZ),
    .SIM_DIV   (SIM_DIV),
    .ESC_QUITS (0)          // the SDL window owns ESC
  ) console (
    .clk    (clk),
    .rstb   (rstb),
    .dut_tx (dut_ser_tx),
    .dut_rx (host_ser_tx),
    .quit   ()
  );

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/sim_tb.vcd");
      $dumpvars(0, sim_tb);
    end
    rstb = 0;
    clk = 0;
    #30;
    rstb = 1;
    // No #delay and no $finish: proc.v's own `always #5 clk` keeps time moving.
  end

  // Done-detector: the CPU storing EOT (0x04) to UART TX.
  always @(posedge clk) begin
    if (uut.dataMem.is_uart && (|uut.memwrap_wstrb) && uut.exmem_alu_out == 32'hFFFF0000
        && uut.memwrap_store_out[7:0] == 8'h04) begin
      $display("");
      if (uut.branch_count == 0)
        $display("cycles=%0d branches=0 mispredicts=%0d percentage_mispredicts=n/a",
                 uut.cyc_count, uut.mispredict_count);
      else
        $display("cycles=%0d branches=%0d mispredicts=%0d percentage_mispredicts=%0d%%",
                 uut.cyc_count, uut.branch_count, uut.mispredict_count,
                 (uut.mispredict_count * 100 / uut.branch_count));
      $finish;
    end
  end

endmodule

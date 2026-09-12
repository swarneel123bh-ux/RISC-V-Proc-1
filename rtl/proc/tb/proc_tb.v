`timescale 1ns/1ps

// ============================================================================
// proc_tb.v -- Claude-authored harness, NOT Swarneel's RTL.
//
// Headless / console testbench for `proc`. The interactive serial console lives
// in uart_host.v (rtl/uart/tb/), shared with sim_tb.v.
//
// Plusargs:
//   +cycles=<n>       run length in clock cycles; 0 = run until ESC (default 0)
//   +mem=<hex> +n=<w> memory dump window
//   +dump             write build/vcd/proc_tb.vcd
//   +noregs           skip the register-file dump on exit
//
// Compile-time:
//   -DSLOW_UART       leave the DUT at its real 115200 divisor (234 clks/bit).
// ============================================================================

module proc_tb();

  // --------------------------------------------------------------------------
  // Sim-speed baud override.
  //
  // 27 MHz / 115200 = 234 clocks per bit, 2340 per byte: a program printing 200
  // characters would cost ~470,000 simulated cycles. The divisor is a runtime
  // register (CTL[16 +: CW]) and the real value is exercised on hardware, so
  // sim runs at the DIV_MIN floor of 4 instead -- the documented lowest
  // reliably-sampling divisor. BAUD_MIN is untouched, so CW and the CTL field
  // positions do not move.
  // --------------------------------------------------------------------------
  localparam integer CLK_HZ = 27_000_000;
`ifdef SLOW_UART
  localparam integer SIM_DIV = 234;
`else
  localparam integer SIM_DIV = 4;
`endif

  // TB-only retune of the DUT's uart_top. No source file is edited.
  defparam uut.dataMem.uartInst_.BAUD_RATE = CLK_HZ / SIM_DIV;

  // --------------------------------------------------------------------------
  // DUT + host console
  // --------------------------------------------------------------------------
  reg  rstb;
  wire dut_ser_tx, host_ser_tx, quit;

  reg clk;
  always begin #5; clk = ~clk; end
  proc uut(
  	.clk(clk),
    .rstb   (rstb),
    .ser_rx (host_ser_tx),
    .ser_tx (dut_ser_tx)
  );

  // proc.v generates its own clock internally; borrow it so both UARTs sit in
  // the same domain. (On hardware the host is genuinely asynchronous -- that
  // case is covered by uart_rx's 2-FF synchroniser, not by this harness.)
  // wire clk = uut.clk;

  uart_host #(
    .CLK_FREQ  (CLK_HZ),
    .SIM_DIV   (SIM_DIV),
    .ESC_QUITS (1)
  ) console (
    .clk    (clk),
    .rstb   (rstb),
    .dut_tx (dut_ser_tx),
    .dut_rx (host_ser_tx),
    .quit   (quit)
  );

  always @(posedge quit) finish_up;

  // --------------------------------------------------------------------------
  // Reporting
  // --------------------------------------------------------------------------
  integer j, memaddr, memwords, widx, ncycles;
  localparam integer NS_PER_CYCLE = 10;   // proc.v drives clk with #5 half-periods

  task finish_up;
    begin
      $display("");
      if (!$test$plusargs("noregs"))
        for (j = 0; j <= 31; j = j + 1)
          $display("x%0d = %08h", j, uut.registerfile.registers[j]);

      if (memwords > 0) begin
        $display("");
        $display("memory dump: %0d words from 0x%08h", memwords, memaddr);
        for (j = 0; j < memwords; j = j + 1) begin
          widx = (memaddr >> 2) + j;
          $display("  [0x%08h] = %08h  (%0d)",
                   memaddr + 4*j,
                   uut.unifiedMemory.memory[widx],
                   $signed(uut.unifiedMemory.memory[widx]));
        end
      end

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
  endtask

  initial begin

    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/proc_tb.vcd");
      $dumpvars(0, proc_tb);
    end
    clk = 0;
    ncycles  = 0;                         // 0 = run until ESC
    memaddr  = 0;
    memwords = 0;
    void'($value$plusargs("cycles=%d", ncycles));
    void'($value$plusargs("mem=%h",    memaddr));
    void'($value$plusargs("n=%d",      memwords));

    rstb = 0;
    #30;
    rstb = 1;

    if (ncycles > 0) begin
      #(ncycles * NS_PER_CYCLE);
      finish_up;
    end
  end

  // Harness, Claude-suggested — not mine. Decision 17: only the low
  // IMEM_WORDS*4 bytes are fetchable; above it the fetch aliases back
  // into the mirror and the program appears to restart.
  localparam IMEM_WORDS = 2048;
  reg ceiling_hit = 1'b0;

  always @(posedge clk) begin
    if (rstb === 1'b1 && !ceiling_hit &&
        uut.pcout >= (IMEM_WORDS * 4)) begin
      ceiling_hit <= 1'b1;
      $display("FATAL: PC %h above fetch ceiling %h",
               uut.pcout, IMEM_WORDS * 4);
    end
  end
endmodule

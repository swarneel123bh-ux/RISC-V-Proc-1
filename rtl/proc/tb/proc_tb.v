`timescale 1ns/1ps

// ============================================================================
// proc_tb.v -- Claude-authored harness, NOT Swarneel's RTL.
//
// Adds to the previous version:
//   - run length via +cycles=<n>          (default 2000)
//   - memory dump via +mem=<hex byte addr> +n=<words>
//   - divide-by-zero guard on the mispredict percentage
//
// Get the array address from the ELF, e.g.:
//   riscv64-elf-objdump -t software/c_bubblesort.elf | grep -i arr
// then:
//   make prog PROG=c_bubblesort PROG_TARGET=rtl-proc-run
//   vvp build/vvp/proc_tb.vvp +cycles=200000 +mem=7fa4 +n=16
// ============================================================================

module proc_tb();

  reg rstb;
  proc uut(.rstb(rstb));

  integer j;
  integer ncycles;
  integer memaddr;
  integer memwords;
  integer widx;

  // Clock period is 10ns (proc.v drives clk with #5 half-periods).
  localparam integer NS_PER_CYCLE = 10;

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/proc_tb.vcd");
      $dumpvars(0, proc_tb);
    end

    // ---- run length ----
    ncycles = 2000;
    void'($value$plusargs("cycles=%d", ncycles));

    // ---- memory dump window (0 words = disabled) ----
    memaddr  = 0;
    memwords = 0;
    void'($value$plusargs("mem=%h", memaddr));
    void'($value$plusargs("n=%d",   memwords));

    rstb = 0;
    #30;
    rstb = 1;
    #(ncycles * NS_PER_CYCLE);

    // ---- register file ----
    for (j = 0; j <= 31; j = j + 1)
      $display("x%0d = %08h", j, uut.registerfile.registers[j]);

    // ---- memory window ----
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

    // ---- counters ----
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

endmodule

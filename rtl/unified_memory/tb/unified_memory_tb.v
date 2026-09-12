`timescale 1ns / 1ps

// Testbench for unified_memory.v  — SYNC-READ revision.
//
// Rewritten after the WRITE_MODE0 / PA2122 fix. The previous version was
// written against async reads (set addr, #1, sample) and would pass against
// sync-read RTL by sampling stale data (see HANDOFF s9).
//
// Sampling contract, used by every task here:
//   address driven on negedge N  ->  captured at posedge N  ->  data valid
//   from just after posedge N. Always sample with @(posedge clk); #1;
//
// Claude-authored harness. Not Swarneel's code.

module unified_memory_tb;

  // Decision 10: 32 KB main memory.
  localparam DEPTH_WORDS = 8192;
  localparam AW          = 13;            // $clog2(DEPTH_WORDS)
  localparam ALIAS_BIT   = 32'h1 << (AW + 2);   // first ignored address bit

  reg         clk;
  reg         imem_en;
  reg  [31:0] imem_addr;
  wire [31:0] imem_rdata;
  reg  [31:0] dmem_addr;
  reg  [31:0] dmem_wdata;
  reg  [3:0]  dmem_wstrb;
  reg         dmem_read;
  wire [31:0] dmem_rdata;

  integer pass = 0;
  integer fail = 0;

  initial clk = 0;                        // NEVER a bare `reg clk;` — s8
  always #5 clk = ~clk;

  unified_memory #(
    .DEPTH_WORDS(DEPTH_WORDS),
    .HEXFILE("../../software/rom/umem_test.hex")
  ) dut (
    .clk(clk),
    .imem_en(imem_en),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),
    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .dmem_wstrb(dmem_wstrb),
    .dmem_read(dmem_read),
    .dmem_rdata(dmem_rdata)
  );

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------
  task check32;
    input [255:0] name;
    input [31:0]  got;
    input [31:0]  exp;
    begin
      if (got === exp) begin
        pass = pass + 1;
        $display("[PASS] %0s: 0x%08h", name, got);
      end else begin
        fail = fail + 1;
        $display("[FAIL] %0s: got 0x%08h expected 0x%08h", name, got, exp);
      end
    end
  endtask

  // note: informational only, never counted. Used where sim and hardware
  // are allowed to disagree (cross-port RDW).
  task note32;
    input [255:0] name;
    input [31:0]  got;
    begin
      $display("[NOTE] %0s: 0x%08h (sim behaviour, not a hardware guarantee)",
               name, got);
    end
  endtask

  // One fetch. Address presented for one cycle, data sampled after the edge.
  task fetch;
    input  [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk);
      imem_addr = addr;
      imem_en   = 1'b1;
      @(posedge clk); #1;
      data = imem_rdata;
    end
  endtask

  // One data-port read. Strobes held low so this is a read cycle.
  task dread;
    input  [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk);
      dmem_addr  = addr;
      dmem_wstrb = 4'b0000;
      dmem_read  = 1'b1;
      @(posedge clk); #1;
      data      = dmem_rdata;
      dmem_read = 1'b0;
    end
  endtask

  // One strobed write. dmem_read low, as the core drives it on a store.
  task dwrite;
    input [31:0] addr;
    input [31:0] data;
    input [3:0]  strb;
    begin
      @(negedge clk);
      dmem_addr  = addr;
      dmem_wdata = data;
      dmem_wstrb = strb;
      dmem_read  = 1'b0;
      @(posedge clk); #1;
      dmem_wstrb = 4'b0000;
    end
  endtask

  reg [31:0] rdval;
  reg [31:0] ival;
  reg [31:0] held;

  initial begin
    imem_en    = 1'b0;
    imem_addr  = 32'h0;
    dmem_addr  = 32'h0;
    dmem_wdata = 32'h0;
    dmem_wstrb = 4'b0000;
    dmem_read  = 1'b0;
    #2;

    // ================================================================
    // 1. Preload + fetch, port A
    //    umem_test.hex: word0=DEADBEEF word1=11223344 word2=A5A5A5A5
    // ================================================================
    $display("--- preload / fetch ---");
    fetch(32'h0000_0000, ival);
    check32("fetch word0 @0x00", ival, 32'hDEADBEEF);
    fetch(32'h0000_0004, ival);
    check32("fetch word1 @0x04", ival, 32'h11223344);
    fetch(32'h0000_0008, ival);
    check32("fetch word2 @0x08", ival, 32'hA5A5A5A5);

    dread(32'h0000_0004, rdval);
    check32("dport sees preload @0x04", rdval, 32'h11223344);

    // ================================================================
    // 2. imem_en HOLD  -- the highest-value check in this file.
    //    mem.optionb: the conditional-update form must HOLD on a stall.
    //    The ternary form zeroes instead, which drops one instruction per
    //    stall and is invisible in a register dump.
    // ================================================================
    $display("--- imem_en hold (stall behaviour) ---");
    fetch(32'h0000_0008, ival);
    check32("armed with word2", ival, 32'hA5A5A5A5);

    @(negedge clk);
    imem_en   = 1'b0;
    imem_addr = 32'h0000_0000;          // PC has moved on; must be ignored
    @(posedge clk); #1;
    check32("stall cycle 1 holds word2", imem_rdata, 32'hA5A5A5A5);
    @(posedge clk); #1;
    check32("stall cycle 2 holds word2", imem_rdata, 32'hA5A5A5A5);

    @(negedge clk);
    imem_en = 1'b1;                      // release; address still 0x00
    @(posedge clk); #1;
    check32("release fetches word0", imem_rdata, 32'hDEADBEEF);

    // ================================================================
    // 3. WRITE_MODE0 == 2'b00 : a write cycle must not read.
    //    Direct regression guard for PA2122.
    // ================================================================
    $display("--- write cycle is no-change on rdata ---");
    dread(32'h0000_0004, held);          // rdata now holds 0x11223344
    check32("rdata armed", held, 32'h11223344);

    dwrite(32'h0000_0100, 32'hCAFEF00D, 4'b1111);
    check32("rdata held across write", dmem_rdata, 32'h11223344);

    // Same thing with dmem_read ASSERTED alongside the strobes. The core
    // never does this, but it is the exact condition the primitive rejects,
    // so prove the port is structurally incapable of it.
    @(negedge clk);
    dmem_addr  = 32'h0000_0000;          // would read DEADBEEF if it read
    dmem_wdata = 32'h5A5A5A5A;
    dmem_wstrb = 4'b1111;
    dmem_read  = 1'b1;                   // illegal combination, on purpose
    @(posedge clk); #1;
    check32("read+write same cycle: no read", dmem_rdata, 32'h11223344);
    dmem_wstrb = 4'b0000;
    dmem_read  = 1'b0;
    dread(32'h0000_0000, rdval);
    check32("...but the write still landed", rdval, 32'h5A5A5A5A);

    // restore word0 for later checks
    dwrite(32'h0000_0000, 32'hDEADBEEF, 4'b1111);

    // ================================================================
    // 4. Read gating.
    //    *** FLIP THIS CHECK if you took the bare `else if` form: with no
    //        else arm, an idle cycle HOLDS rather than zeroing, and the
    //        expected value becomes 0x11223344 (whatever was last read). ***
    // ================================================================
    $display("--- read gating ---");
    dread(32'h0000_0100, rdval);
    check32("read enabled @0x100", rdval, 32'hCAFEF00D);
    @(negedge clk);
    dmem_addr  = 32'h0000_0100;
    dmem_wstrb = 4'b0000;
    dmem_read  = 1'b0;
    @(posedge clk); #1;
    check32("idle cycle drives zero", dmem_rdata, 32'h00000000);

    // ================================================================
    // 5. Byte / halfword lanes
    // ================================================================
    $display("--- strobed lanes ---");
    dwrite(32'h0000_0200, 32'h00000000, 4'b1111);
    dwrite(32'h0000_0200, 32'hFFFFFF77, 4'b0001);
    dread (32'h0000_0200, rdval);
    check32("SB lane0", rdval, 32'h00000077);

    dwrite(32'h0000_0200, 32'hFFFF88FF, 4'b0100);
    dread (32'h0000_0200, rdval);
    check32("SB lane2 preserves lane0", rdval, 32'h00FF0077);

    dwrite(32'h0000_0300, 32'h00000000, 4'b1111);
    dwrite(32'h0000_0300, 32'hBEEF0000, 4'b1100);
    dread (32'h0000_0300, rdval);
    check32("SH upper half", rdval, 32'hBEEF0000);

    dwrite(32'h0000_0300, 32'h0000ABCD, 4'b0011);
    dread (32'h0000_0300, rdval);
    check32("SH lower half preserves upper", rdval, 32'hBEEFABCD);

    // A strobe of 0 must not write. Guards the |dmem_wstrb condition
    // against being replaced by something always-true.
    dwrite(32'h0000_0300, 32'h00000000, 4'b0000);
    dread (32'h0000_0300, rdval);
    check32("zero strobe does not write", rdval, 32'hBEEFABCD);

    // ================================================================
    // 6. Aliasing: address bits above AW+1 are ignored
    // ================================================================
    $display("--- aliasing ---");
    dwrite(32'h0000_0000, 32'h12345678, 4'b1111);
    dread (ALIAS_BIT, rdval);
    check32("alias wraps to word0", rdval, 32'h12345678);

    // ================================================================
    // 7. Cross-port, different words: the dual-port property.
    //    This is what the WRITE_MODE fix must NOT have cost.
    // ================================================================
    $display("--- dual port, different words ---");
    dwrite(32'h0000_0400, 32'h00000000, 4'b1111);
    @(negedge clk);
    imem_en    = 1'b1;
    imem_addr  = 32'h0000_0008;          // fetch word2
    dmem_addr  = 32'h0000_0400;          // write elsewhere, same cycle
    dmem_wdata = 32'h0F0F0F0F;
    dmem_wstrb = 4'b1111;
    dmem_read  = 1'b0;
    @(posedge clk); #1;
    check32("fetch unaffected by concurrent write", imem_rdata, 32'hA5A5A5A5);
    dmem_wstrb = 4'b0000;
    dread(32'h0000_0400, rdval);
    check32("concurrent write landed", rdval, 32'h0F0F0F0F);

    // ================================================================
    // 8. Cross-port, SAME word. NOT a pass/fail check.
    //    mem.rdw: this is the collision WRITE_MODE does not govern. Sim
    //    returns the pre-write value by nonblocking semantics; hardware is
    //    not obliged to agree. Recorded so a future write-forward change
    //    has a before/after, and deliberately not asserted so this file
    //    cannot be cited as evidence the hardware behaves this way.
    // ================================================================
    $display("--- cross-port same word (informational) ---");
    dwrite(32'h0000_0500, 32'h11111111, 4'b1111);
    @(negedge clk);
    imem_en    = 1'b1;
    imem_addr  = 32'h0000_0500;
    dmem_addr  = 32'h0000_0500;
    dmem_wdata = 32'h22222222;
    dmem_wstrb = 4'b1111;
    dmem_read  = 1'b0;
    @(posedge clk); #1;
    note32("imem fetch during same-word write", imem_rdata);
    dmem_wstrb = 4'b0000;
    fetch(32'h0000_0500, ival);
    check32("same word reads new value next cycle", ival, 32'h22222222);

    // ================================================================
    $display("");
    $display("==== unified_memory_tb: %0d passed, %0d failed ====", pass, fail);
    if (fail == 0) $display("ALL TESTS PASSED");
    else           $display("SOME TESTS FAILED");
    $finish;
  end

  initial begin
    #100000;
    $display("[FAIL] timeout");
    $finish;
  end

endmodule

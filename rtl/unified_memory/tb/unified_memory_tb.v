`timescale 1ns / 1ps

// Testbench for unified_memory.v
// Drives both ports, checks: hexfile preload + fetch (port A, read-only),
// byte/half/word strobed writes and readback (port B), read gating,
// address aliasing (wrap), and simultaneous same-cycle dual-port access.
// Self-checking: prints [PASS]/[FAIL] per check and a final summary.
// Loads its own tiny hex via -DUMEM_HEXFILE so it does not depend on the
// software build.

module unified_memory_tb;

  localparam DEPTH_WORDS = 16384;

  reg         clk;
  reg  [31:0] imem_addr;
  wire [31:0] imem_rdata;
  reg  [31:0] dmem_addr;
  reg  [31:0] dmem_wdata;
  reg  [3:0]  dmem_wstrb;
  reg         dmem_read;
  wire [31:0] dmem_rdata;

  integer pass = 0;
  integer fail = 0;

  // 10 ns clock
  initial clk = 0;
  always #5 clk = ~clk;

  unified_memory #(
    .DEPTH_WORDS(DEPTH_WORDS),
    .HEXFILE("../../software/rom/umem_test.hex")
  ) dut (
    .clk(clk),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),
    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .dmem_wstrb(dmem_wstrb),
    .dmem_read(dmem_read),
    .dmem_rdata(dmem_rdata)
  );

  // ---- helpers ----
  task check32;
    input [255:0] name;
    input [31:0]  got;
    input [31:0]  exp;
    begin
      if (got === exp) begin
        pass = pass + 1;
        $display("[PASS] %0s: got 0x%08h", name, got);
      end else begin
        fail = fail + 1;
        $display("[FAIL] %0s: got 0x%08h expected 0x%08h", name, got, exp);
      end
    end
  endtask

  // Synchronous strobed write on port B (one clock), strobes cleared after.
  task wr;
    input [31:0] addr;
    input [31:0] data;
    input [3:0]  strb;
    begin
      @(negedge clk);
      dmem_addr  = addr;
      dmem_wdata = data;
      dmem_wstrb = strb;
      @(posedge clk);         // write commits here
      @(negedge clk);
      dmem_wstrb = 4'b0000;   // deassert so no further writes
    end
  endtask

  // Combinational read on port B (async): set addr+read, sample after settle.
  task rd;
    input  [31:0] addr;
    output [31:0] data;
    begin
      dmem_addr = addr;
      dmem_read = 1'b1;
      #1;
      data = dmem_rdata;
    end
  endtask

  reg [31:0] rdval;

  initial begin
    imem_addr  = 32'h0;
    dmem_addr  = 32'h0;
    dmem_wdata = 32'h0;
    dmem_wstrb = 4'b0000;
    dmem_read  = 1'b0;
    #2;

    // ---- 1. Hexfile preload + instruction fetch (port A, async, read-only) ----
    // umem_test.hex fills words 0..3 with known values (see below).
    imem_addr = 32'h0000_0000; #1;
    check32("fetch word0 @0x00", imem_rdata, 32'hDEADBEEF);
    imem_addr = 32'h0000_0004; #1;
    check32("fetch word1 @0x04", imem_rdata, 32'h11223344);
    imem_addr = 32'h0000_0008; #1;
    check32("fetch word2 @0x08", imem_rdata, 32'hA5A5A5A5);

    // Data port sees the same preloaded image (single array)
    rd(32'h0000_0004, rdval);
    check32("dport reads preload @0x04", rdval, 32'h11223344);

    // ---- 2. Full-word write + readback (port B) ----
    wr(32'h0000_0100, 32'hCAFEF00D, 4'b1111);
    rd(32'h0000_0100, rdval);
    check32("SW @0x100", rdval, 32'hCAFEF00D);

    // Fetch of a written word also sees it (shared array), port A
    imem_addr = 32'h0000_0100; #1;
    check32("fetch sees dport write @0x100", imem_rdata, 32'hCAFEF00D);

    // ---- 3. Byte write (SB) touches only its lane ----
    wr(32'h0000_0200, 32'h00000000, 4'b1111);   // clear word
    wr(32'h0000_0200, 32'hFFFFFF77, 4'b0001);   // write only byte lane 0 (0x77)
    rd(32'h0000_0200, rdval);
    check32("SB lane0 @0x200", rdval, 32'h00000077);

    wr(32'h0000_0200, 32'hFFFF88FF, 4'b0100);   // write only byte lane 2 (0x88)
    rd(32'h0000_0200, rdval);
    check32("SB lane2 keeps lane0 @0x200", rdval, 32'h00FF0077);

    // ---- 4. Halfword write (SH) upper half only ----
    wr(32'h0000_0300, 32'h00000000, 4'b1111);
    wr(32'h0000_0300, 32'hBEEF0000, 4'b1100);   // upper 16 bits
    rd(32'h0000_0300, rdval);
    check32("SH upper half @0x300", rdval, 32'hBEEF0000);

    // ---- 5. Read gating: dmem_read=0 => 0 ----
    dmem_addr = 32'h0000_0100;
    dmem_read = 1'b0; #1;
    check32("read gated (read=0)", dmem_rdata, 32'h00000000);
    dmem_read = 1'b1;

    // ---- 6. Address aliasing: bits above ADDRWIDTHS+1 ignored ----
    // DEPTH_WORDS=16384 => index = addr[15:2]; 0x10000 aliases 0x00000.
    wr(32'h0000_0000, 32'h12345678, 4'b1111);
    rd(32'h0001_0000, rdval);                    // aliases word 0
    check32("alias 0x10000 -> word0", rdval, 32'h12345678);

    // ---- 7. Simultaneous same-cycle dual-port: fetch one word while
    //         writing a different word in the same cycle ----
    wr(32'h0000_0400, 32'h00000000, 4'b1111);
    @(negedge clk);
    imem_addr  = 32'h0000_0008;    // port A reads word2 (0xA5A5A5A5)
    dmem_addr  = 32'h0000_0400;    // port B writes word 0x100 idx
    dmem_wdata = 32'h0F0F0F0F;
    dmem_wstrb = 4'b1111;
    #1;
    check32("dualport fetch during write (A)", imem_rdata, 32'hA5A5A5A5);
    @(posedge clk);                // B commits
    @(negedge clk);
    dmem_wstrb = 4'b0000;
    rd(32'h0000_0400, rdval);
    check32("dualport write landed (B)", rdval, 32'h0F0F0F0F);

    // ---- summary ----
    $display("");
    $display("==== unified_memory_tb: %0d passed, %0d failed ====", pass, fail);
    if (fail == 0) $display("ALL TESTS PASSED");
    else           $display("SOME TESTS FAILED");
    $finish;
  end

  // safety timeout
  initial begin
    #100000;
    $display("[FAIL] timeout");
    $finish;
  end

endmodule

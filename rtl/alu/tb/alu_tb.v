// ============================================================
// SCAFFOLDING — written by Claude, NOT swarneel's code.
// ALU testbench: base ops + MUL* + multi-cycle DIV/DIVU.
// Divide protocol modelled like a stalled EX stage:
//   op/operands held while alu_busy=1 AND across the edge
//   that retires the op; next op applied after that edge.
// REM/REMU not tested (no opcode yet).
// Signed DIV cases gated by SIGNED_DIV_ENABLED.
// ============================================================
`timescale 1ns / 1ps

module alu_tb ();
  reg         clk = 1'b0, rstb = 1'b0;
  reg  [3:0]  aluop_ctrl = 4'b0000;
  reg  [31:0] alu_a = 32'd0, alu_b = 32'd0;
  wire [31:0] alu_out;
  wire        alu_zero, alu_busy;
  integer     errors = 0;
  integer     i, k, seed, cyc, max_cyc;
  reg  [63:0] ref_ss, ref_uu, ref_su;
  reg  [31:0] ra, rb;

  localparam DIV_TIMEOUT = 100;

  // TEMP: set to 1 once the signed wrapper lands
  localparam SIGNED_DIV_ENABLED = 0;

  alu DUT (.clk(clk), .rstb(rstb), .aluop_ctrl(aluop_ctrl),
           .alu_a(alu_a), .alu_b(alu_b),
           .alu_out(alu_out), .alu_zero(alu_zero), .alu_busy(alu_busy));

  always #5 clk = ~clk;

  localparam ALUOP_ADD=4'b0000, ALUOP_SUB=4'b0001, ALUOP_SLL=4'b0010,
             ALUOP_SLT=4'b0011, ALUOP_SLTU=4'b0100, ALUOP_XOR=4'b0101,
             ALUOP_SRL=4'b0110, ALUOP_SRA=4'b0111, ALUOP_OR=4'b1000,
             ALUOP_AND=4'b1001, ALUOP_MUL=4'b1010, ALUOP_MULH=4'b1011,
             ALUOP_MULHU=4'b1100, ALUOP_MULHSU=4'b1101,
             ALUOP_DIV=4'b1110, ALUOP_DIVU=4'b1111;

  // RISC-V spec reference for DIV/DIVU (truncates toward zero)
  function [31:0] ref_div(input [31:0] a, input [31:0] b, input sgn);
    reg [31:0] ma, mb, q;
    begin
      if (b == 32'd0)
        ref_div = 32'hFFFFFFFF;
      else if (!sgn)
        ref_div = a / b;
      else if (a == 32'h80000000 && b == 32'hFFFFFFFF)
        ref_div = 32'h80000000;
      else begin
        ma = a[31] ? -a : a;
        mb = b[31] ? -b : b;
        q  = ma / mb;
        ref_div = (a[31] ^ b[31]) ? -q : q;
      end
    end
  endfunction

  task report;
  begin
    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end endtask

  // combinational op check; busy must stay low
  task chk(input [3:0] op, input [31:0] a, input [31:0] b,
           input [31:0] exp, input [80*8:1] name);
  begin
    aluop_ctrl = op; alu_a = a; alu_b = b; #1;
    if (alu_out !== exp || alu_busy !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL %-24s a=%08h b=%08h -> %08h busy=%b  exp %08h busy=0",
               name, a, b, alu_out, alu_busy, exp);
    end else
      $display("PASS %-24s a=%08h b=%08h -> %08h", name, a, b, alu_out);
  end endtask

  task chkq(input [3:0] op, input [31:0] a, input [31:0] b,
            input [31:0] exp, input [8*8:1] name);
  begin
    aluop_ctrl = op; alu_a = a; alu_b = b; #1;
    if (alu_out !== exp || alu_busy !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL rand %-8s a=%08h b=%08h -> %08h busy=%b  exp %08h",
               name, a, b, alu_out, alu_busy, exp);
    end
  end endtask

  task chkz(input [3:0] op, input [31:0] a, input [31:0] b,
            input exp_z, input [80*8:1] name);
  begin
    aluop_ctrl = op; alu_a = a; alu_b = b; #1;
    if (alu_zero !== exp_z) begin
      errors = errors + 1;
      $display("FAIL %-24s zero=%b exp %b", name, alu_zero, exp_z);
    end else
      $display("PASS %-24s zero=%b", name, alu_zero);
  end endtask

  // Call after any clock edge (not exactly on one). Applies a divide,
  // holds it while busy, checks the result in the cycle busy drops,
  // then holds it across the edge that retires it (pipeline advances
  // there). Returns just after that edge with op STILL applied; caller
  // must call retire() or issue the next op immediately.
  task div_run(input [3:0] op, input [31:0] a, input [31:0] b,
               input [31:0] exp, input [80*8:1] name, input quiet);
  begin
    aluop_ctrl = op; alu_a = a; alu_b = b; #1;
    if (alu_busy !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL %-24s busy not high in first cycle", name);
    end
    cyc = 0;
    while (alu_busy === 1'b1 && cyc < DIV_TIMEOUT) begin
      @(negedge clk); #1;
      cyc = cyc + 1;
    end
    if (cyc >= DIV_TIMEOUT) begin
      errors = errors + 1;
      $display("FAIL %-24s TIMEOUT: busy stuck high %0d cycles", name, cyc);
      $display("ABORT: divider hung, remaining divide tests skipped");
      report;
    end
    if (cyc > max_cyc) max_cyc = cyc;
    if (alu_out !== exp) begin
      errors = errors + 1;
      $display("FAIL %-24s a=%08h b=%08h -> %08h  exp %08h (%0d cyc)",
               name, a, b, alu_out, exp, cyc);
    end else if (!quiet)
      $display("PASS %-24s a=%08h b=%08h -> %08h (%0d cyc)",
               name, a, b, alu_out, cyc);
    // hold the finished op across the edge that retires it;
    // the next instruction only enters EX after this edge
    @(posedge clk); #1;
  end endtask

  // instruction leaves EX: switch to a non-divide op for one cycle
  task retire;
  begin
    aluop_ctrl = ALUOP_ADD; alu_a = 32'd0; alu_b = 32'd0;
    @(negedge clk); #1;
  end endtask

  // after retire, the divider must not restart on its own
  task idle_check(input [80*8:1] name);
  begin
    for (k = 0; k < 4; k = k + 1) begin
      @(negedge clk); #1;
      if (alu_busy !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL %-24s busy=1 while idle (cycle %0d)", name, k);
      end
    end
    $display("INFO %-24s done", name);
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/alu_tb.vcd");
      $dumpvars(0, alu_tb);
    end
    max_cyc = 0;
    #12 rstb = 1'b1;
    @(negedge clk); #1;

    // ---------------- base RV32I ops ----------------
    chk(ALUOP_ADD, 32'd5, 32'd3, 32'd8, "ADD 5+3");
    chk(ALUOP_ADD, 32'hFFFFFFFF, 32'd1, 32'h00000000, "ADD -1+1 wrap");
    chk(ALUOP_ADD, 32'h7FFFFFFF, 32'd1, 32'h80000000, "ADD overflow");
    chk(ALUOP_SUB, 32'd8, 32'd3, 32'd5, "SUB 8-3");
    chk(ALUOP_SUB, 32'd0, 32'd1, 32'hFFFFFFFF, "SUB 0-1");
    chk(ALUOP_SLL, 32'd1, 32'd4,  32'h00000010, "SLL 1<<4");
    chk(ALUOP_SLL, 32'd1, 32'd31, 32'h80000000, "SLL 1<<31");
    chk(ALUOP_SLL, 32'd1, 32'd33, 32'h00000002, "SLL shamt mask");
    chk(ALUOP_SLT, 32'd3, 32'd5, 32'd1, "SLT 3<5");
    chk(ALUOP_SLT, 32'd5, 32'd3, 32'd0, "SLT 5<3");
    chk(ALUOP_SLT, 32'd5, 32'd5, 32'd0, "SLT 5<5");
    chk(ALUOP_SLT, 32'hFFFFFFFF, 32'd1, 32'd1, "SLT -1<1");
    chk(ALUOP_SLT, 32'd1, 32'hFFFFFFFF, 32'd0, "SLT 1<-1");
    chk(ALUOP_SLT, 32'hFFFFFFFB, 32'hFFFFFFFD, 32'd1, "SLT -5<-3");
    chk(ALUOP_SLTU, 32'd3, 32'd5, 32'd1, "SLTU 3<5");
    chk(ALUOP_SLTU, 32'd5, 32'd3, 32'd0, "SLTU 5<3");
    chk(ALUOP_SLTU, 32'hFFFFFFFF, 32'd1, 32'd0, "SLTU big<1");
    chk(ALUOP_SLTU, 32'd1, 32'hFFFFFFFF, 32'd1, "SLTU 1<big");
    chk(ALUOP_XOR, 32'hF0F0F0F0, 32'h0F0F0F0F, 32'hFFFFFFFF, "XOR");
    chk(ALUOP_XOR, 32'hAAAA5555, 32'hFFFFFFFF, 32'h5555AAAA, "XOR invert");
    chk(ALUOP_SRL, 32'hFFFFFFF8, 32'd2,  32'h3FFFFFFE, "SRL -8>>2");
    chk(ALUOP_SRL, 32'h80000000, 32'd31, 32'h00000001, "SRL msb");
    chk(ALUOP_SRA, 32'hFFFFFFF8, 32'd2,  32'hFFFFFFFE, "SRA -8>>>2");
    chk(ALUOP_SRA, 32'h80000000, 32'd31, 32'hFFFFFFFF, "SRA min>>>31");
    chk(ALUOP_SRA, 32'h7FFFFFFF, 32'd1,  32'h3FFFFFFF, "SRA pos>>>1");
    chk(ALUOP_SRA, 32'hFFFFFFFF, 32'd4,  32'hFFFFFFFF, "SRA -1>>>4");
    chk(ALUOP_OR,  32'hF0F0F0F0, 32'h0F0F0F0F, 32'hFFFFFFFF, "OR");
    chk(ALUOP_AND, 32'hF0F0F0F0, 32'h0F0F0F0F, 32'h00000000, "AND");
    chk(ALUOP_AND, 32'hFFFF0000, 32'hAAAAAAAA, 32'hAAAA0000, "AND mask");

    // ---------------- MUL* directed ----------------
    chk(ALUOP_MUL, 32'd3, 32'd7, 32'd21, "MUL 3*7");
    chk(ALUOP_MUL, 32'hDEADBEEF, 32'd0, 32'd0, "MUL x*0");
    chk(ALUOP_MUL, 32'd1, 32'hDEADBEEF, 32'hDEADBEEF, "MUL 1*x");
    chk(ALUOP_MUL, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'h00000001, "MUL -1*-1");
    chk(ALUOP_MUL, 32'hFFFFFFFE, 32'd3, 32'hFFFFFFFA, "MUL -2*3");
    chk(ALUOP_MUL, 32'h80000000, 32'hFFFFFFFF, 32'h80000000, "MUL min*-1");
    chk(ALUOP_MUL, 32'h00010000, 32'h00010000, 32'h00000000, "MUL 2^16*2^16 lo");
    chk(ALUOP_MUL, 32'h7FFFFFFF, 32'h7FFFFFFF, 32'h00000001, "MUL max*max lo");
    chk(ALUOP_MULH, 32'd3, 32'd7, 32'h00000000, "MULH 3*7");
    chk(ALUOP_MULH, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'h00000000, "MULH -1*-1");
    chk(ALUOP_MULH, 32'hFFFFFFFF, 32'd1, 32'hFFFFFFFF, "MULH -1*1");
    chk(ALUOP_MULH, 32'hFFFFFFFE, 32'd3, 32'hFFFFFFFF, "MULH -2*3");
    chk(ALUOP_MULH, 32'h80000000, 32'h80000000, 32'h40000000, "MULH min*min");
    chk(ALUOP_MULH, 32'h80000000, 32'h7FFFFFFF, 32'hC0000000, "MULH min*max");
    chk(ALUOP_MULH, 32'h7FFFFFFF, 32'h7FFFFFFF, 32'h3FFFFFFF, "MULH max*max");
    chk(ALUOP_MULH, 32'h00010000, 32'h00010000, 32'h00000001, "MULH 2^16*2^16");
    chk(ALUOP_MULHU, 32'd3, 32'd7, 32'h00000000, "MULHU 3*7");
    chk(ALUOP_MULHU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, "MULHU big*big");
    chk(ALUOP_MULHU, 32'hFFFFFFFF, 32'd1, 32'h00000000, "MULHU big*1");
    chk(ALUOP_MULHU, 32'h80000000, 32'd2, 32'h00000001, "MULHU 2^31*2");
    chk(ALUOP_MULHU, 32'h80000000, 32'h80000000, 32'h40000000, "MULHU 2^31*2^31");
    chk(ALUOP_MULHU, 32'hFFFFFFFE, 32'd3, 32'h00000002, "MULHU (2^32-2)*3");
    chk(ALUOP_MULHSU, 32'd3, 32'd7, 32'h00000000, "MULHSU 3*7");
    chk(ALUOP_MULHSU, 32'd1, 32'hFFFFFFFF, 32'h00000000, "MULHSU 1*big");
    chk(ALUOP_MULHSU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, "MULHSU -1*big");
    chk(ALUOP_MULHSU, 32'hFFFFFFFF, 32'd0, 32'h00000000, "MULHSU -1*0");
    chk(ALUOP_MULHSU, 32'h7FFFFFFF, 32'hFFFFFFFF, 32'h7FFFFFFE, "MULHSU max*big");
    chk(ALUOP_MULHSU, 32'hFFFFFFFE, 32'd3, 32'hFFFFFFFF, "MULHSU -2*3");
    chk(ALUOP_MULH,   32'hFFFFFFFF, 32'h80000000, 32'h00000000, "DISC1 MULH");
    chk(ALUOP_MULHU,  32'hFFFFFFFF, 32'h80000000, 32'h7FFFFFFF, "DISC1 MULHU");
    chk(ALUOP_MULHSU, 32'hFFFFFFFF, 32'h80000000, 32'hFFFFFFFF, "DISC1 MULHSU");
    chk(ALUOP_MULH,   32'h80000000, 32'hFFFFFFFF, 32'h00000000, "DISC2 MULH");
    chk(ALUOP_MULHU,  32'h80000000, 32'hFFFFFFFF, 32'h7FFFFFFF, "DISC2 MULHU");
    chk(ALUOP_MULHSU, 32'h80000000, 32'hFFFFFFFF, 32'h80000000, "DISC2 MULHSU");

    // ---------------- zero flag ----------------
    chkz(ALUOP_SUB, 32'd5, 32'd5, 1'b1, "zero: SUB 5-5");
    chkz(ALUOP_SUB, 32'd5, 32'd3, 1'b0, "zero: SUB 5-3");
    chkz(ALUOP_ADD, 32'd0, 32'd0, 1'b1, "zero: ADD 0+0");
    chkz(ALUOP_MUL, 32'h00010000, 32'h00010000, 1'b1, "zero: MUL lo=0");
    chkz(ALUOP_MULH, 32'h00010000, 32'h00010000, 1'b0, "zero: MULH hi=1");

    // ---------------- MUL* random sweep ----------------
    seed = 32'h1234_5678;
    for (i = 0; i < 2000; i = i + 1) begin
      ra = $random(seed); rb = $random(seed);
      ref_ss = {{32{ra[31]}}, ra} * {{32{rb[31]}}, rb};
      ref_uu = {32'd0, ra} * {32'd0, rb};
      ref_su = {{32{ra[31]}}, ra} * {32'd0, rb};
      chkq(ALUOP_MUL,    ra, rb, ref_uu[31:0],  "MUL");
      chkq(ALUOP_MULH,   ra, rb, ref_ss[63:32], "MULH");
      chkq(ALUOP_MULHU,  ra, rb, ref_uu[63:32], "MULHU");
      chkq(ALUOP_MULHSU, ra, rb, ref_su[63:32], "MULHSU");
    end
    $display("INFO MUL random sweep: 2000 vectors x 4 ops done");

    // ================= DIVISION (multi-cycle) =================
    @(negedge clk); #1;

    // first divide straight after reset: catches ready's reset value
    div_run(ALUOP_DIVU, 32'd20, 32'd3, 32'd6, "DIVU first after rst", 0); retire;
    idle_check("no restart after retire");

    // DIVU directed
    div_run(ALUOP_DIVU, 32'd5, 32'd7, 32'd0, "DIVU 5/7", 0); retire;
    div_run(ALUOP_DIVU, 32'd0, 32'd5, 32'd0, "DIVU 0/5", 0); retire;
    div_run(ALUOP_DIVU, 32'hFFFFFFFF, 32'd1, 32'hFFFFFFFF, "DIVU big/1", 0); retire;
    div_run(ALUOP_DIVU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'd1, "DIVU big/big", 0); retire;
    div_run(ALUOP_DIVU, 32'h80000000, 32'd2, 32'h40000000, "DIVU 2^31/2", 0); retire;
    div_run(ALUOP_DIVU, 32'hFFFFFFFE, 32'hFFFFFFFF, 32'd0, "DIVU (-2)/(-1) uns", 0); retire;
    div_run(ALUOP_DIVU, 32'h80000000, 32'hFFFFFFFF, 32'd0, "DIVU min/-1 uns", 0); retire;
    div_run(ALUOP_DIVU, 32'hFFFFFFEC, 32'd3, 32'h5555554E, "DIVU (-20)/3 uns", 0); retire;
    div_run(ALUOP_DIVU, 32'd1234, 32'd0, 32'hFFFFFFFF, "DIVU x/0", 0); retire;
    div_run(ALUOP_DIVU, 32'd0, 32'd0, 32'hFFFFFFFF, "DIVU 0/0", 0); retire;

    // DIV: sign-agnostic cases (same answer signed or unsigned);
    // these prove the DIV opcode reaches the divider
    div_run(ALUOP_DIV, 32'd20, 32'd3, 32'd6, "DIV 20/3", 0); retire;
    div_run(ALUOP_DIV, 32'h80000000, 32'd1, 32'h80000000, "DIV min/1", 0); retire;
    div_run(ALUOP_DIV, 32'hFFFFFFEC, 32'd0, 32'hFFFFFFFF, "DIV x/0", 0); retire;

    // DIV: signed cases (truncate toward zero)
    if (SIGNED_DIV_ENABLED) begin
      div_run(ALUOP_DIV, 32'hFFFFFFEC, 32'd3, 32'hFFFFFFFA, "DIV -20/3", 0); retire;
      div_run(ALUOP_DIV, 32'd20, 32'hFFFFFFFD, 32'hFFFFFFFA, "DIV 20/-3", 0); retire;
      div_run(ALUOP_DIV, 32'hFFFFFFEC, 32'hFFFFFFFD, 32'd6, "DIV -20/-3", 0); retire;
      div_run(ALUOP_DIV, 32'hFFFFFFF9, 32'd2, 32'hFFFFFFFD, "DIV -7/2 trunc", 0); retire;
      div_run(ALUOP_DIV, 32'd7, 32'hFFFFFFFE, 32'hFFFFFFFD, "DIV 7/-2 trunc", 0); retire;
      div_run(ALUOP_DIV, 32'hFFFFFFFE, 32'hFFFFFFFF, 32'd2, "DIV -2/-1", 0); retire;
      div_run(ALUOP_DIV, 32'h7FFFFFFF, 32'hFFFFFFFF, 32'h80000001, "DIV max/-1", 0); retire;
      div_run(ALUOP_DIV, 32'h80000000, 32'hFFFFFFFF, 32'h80000000, "DIV overflow", 0); retire;
    end

    // back-to-back: second must not return first's result (stale ready)
    div_run(ALUOP_DIVU, 32'd100, 32'd7, 32'd14, "B2B #1", 0);
    div_run(ALUOP_DIVU, 32'd1000, 32'd10, 32'd100, "B2B #2 (stale?)", 0);
    if (SIGNED_DIV_ENABLED)
      div_run(ALUOP_DIV, 32'hFFFFFFEC, 32'd3, 32'hFFFFFFFA, "B2B #3 DIV", 0);
    div_run(ALUOP_DIVU, 32'hFFFFFFEC, 32'd3, 32'h5555554E, "B2B #4 DIVU same ops", 0);
    retire;
    idle_check("no restart after B2B");

    // comb op right after a divide: must be single-cycle, busy low
    div_run(ALUOP_DIVU, 32'd9, 32'd3, 32'd3, "DIV then ADD", 0);
    chk(ALUOP_ADD, 32'd5, 32'd3, 32'd8, "ADD right after DIV");
    @(negedge clk); #1;

    // random sweep vs spec reference
    for (i = 0; i < 300; i = i + 1) begin
      ra = $random(seed); rb = $random(seed);
      if (i % 16 == 0)      rb = 32'd0;
      else if (i % 4 == 1)  rb = rb & 32'h000000FF;
      if (i % 50 == 7) begin ra = 32'h80000000; rb = 32'hFFFFFFFF; end
      if (SIGNED_DIV_ENABLED) begin
        div_run(ALUOP_DIV, ra, rb, ref_div(ra, rb, 1'b1), "rand DIV", 1); retire;
      end
      div_run(ALUOP_DIVU, ra, rb, ref_div(ra, rb, 1'b0), "rand DIVU", 1); retire;
    end
    if (SIGNED_DIV_ENABLED)
      $display("INFO DIV random sweep: 300 vectors x DIV+DIVU done");
    else
      $display("INFO DIV random sweep: 300 vectors x DIVU done (signed DIV gated)");
    $display("INFO worst-case divide latency: %0d cycles", max_cyc);

    report;
  end
endmodule

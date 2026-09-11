`timescale 1ns / 1ps

module cu_tb ();

  // ---- DUT ----
  reg  [6:0] opcode;
  wire       reg_write;
  wire [1:0] alu_src_a;
  wire       alu_src_b;
  wire [1:0] alu_op;
  wire       mem_read;
  wire       mem_write;
  wire [1:0] wb_sel;
  wire       branch;
  wire       jump;
  wire       jalr;
  wire       uses_rs1;
  wire       uses_rs2;

  cu dut (
    .opcode    (opcode),
    .reg_write (reg_write),
    .alu_src_a (alu_src_a),
    .alu_src_b (alu_src_b),
    .alu_op    (alu_op),
    .mem_read  (mem_read),
    .mem_write (mem_write),
    .wb_sel    (wb_sel),
    .branch    (branch),
    .jump      (jump),
    .jalr      (jalr),
    .uses_rs1  (uses_rs1),
    .uses_rs2  (uses_rs2)
  );

  // ---- opcode constants (duplicated deliberately: see note at bottom) ----
  localparam OP_LUI    = 7'b0110111;
  localparam OP_AUIPC  = 7'b0010111;
  localparam OP_JAL    = 7'b1101111;
  localparam OP_JALR   = 7'b1100111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_LOAD   = 7'b0000011;
  localparam OP_STORE  = 7'b0100011;
  localparam OP_OPIMM  = 7'b0010011;
  localparam OP_OP     = 7'b0110011;
  localparam OP_FENCE  = 7'b0001111;
  localparam OP_SYSTEM = 7'b1110011;

  localparam A_RS1   = 2'b00;
  localparam A_PC    = 2'b01;
  localparam A_ZERO  = 2'b10;
  localparam B_RS2   = 1'b0;
  localparam B_IMM   = 1'b1;
  localparam ALU_ADD = 2'b00;
  localparam ALU_BR  = 2'b01;
  localparam ALU_R   = 2'b10;
  localparam ALU_I   = 2'b11;
  localparam WB_ALU  = 2'b00;
  localparam WB_MEM  = 2'b01;
  localparam WB_PC4  = 2'b10;

  integer pass = 0;
  integer fail = 0;
  integer i;

  // ---- one check per opcode: compares the whole output vector at once ----
  // Widths are explicit on every argument. A narrow literal into a wide port
  // zero-extends and passes silently (s9: "check the argument widths").
  task expect_;
    input [8*12-1:0] label;   // name for the failure message
    input [6:0]      op;
    input            e_reg_write;
    input [1:0]      e_alu_src_a;
    input            e_alu_src_b;
    input [1:0]      e_alu_op;
    input            e_mem_read;
    input            e_mem_write;
    input [1:0]      e_wb_sel;
    input            e_branch;
    input            e_jump;
    input            e_jalr;
    input            e_uses_rs1;
    input            e_uses_rs2;
    begin
      opcode = op;
      #1;
      if (reg_write === e_reg_write &&
          alu_src_a === e_alu_src_a &&
          alu_src_b === e_alu_src_b &&
          alu_op    === e_alu_op    &&
          mem_read  === e_mem_read  &&
          mem_write === e_mem_write &&
          wb_sel    === e_wb_sel    &&
          branch    === e_branch    &&
          jump      === e_jump      &&
          jalr      === e_jalr      &&
          uses_rs1  === e_uses_rs1  &&
          uses_rs2  === e_uses_rs2) begin
        pass = pass + 1;
      end else begin
        fail = fail + 1;
        $display("FAIL %0s (opcode %b)", label, op);
        $display("      got rw=%b a=%b b=%b op=%b mr=%b mw=%b wb=%b br=%b j=%b jr=%b u1=%b u2=%b",
                 reg_write, alu_src_a, alu_src_b, alu_op, mem_read, mem_write,
                 wb_sel, branch, jump, jalr, uses_rs1, uses_rs2);
        $display("      exp rw=%b a=%b b=%b op=%b mr=%b mw=%b wb=%b br=%b j=%b jr=%b u1=%b u2=%b",
                 e_reg_write, e_alu_src_a, e_alu_src_b, e_alu_op, e_mem_read, e_mem_write,
                 e_wb_sel, e_branch, e_jump, e_jalr, e_uses_rs1, e_uses_rs2);
      end
    end
  endtask

  // every illegal / NOP opcode must produce exactly the default vector
  task expect_nop;
    input [8*12-1:0] label;
    input [6:0]      op;
    begin
      expect_(label, op, 1'b0, A_RS1, B_RS2, ALU_ADD, 1'b0, 1'b0,
             WB_ALU, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    end
  endtask

  // dirty the outputs before an illegal opcode, so a latch shows up as
  // retention rather than as a value that happens to already be 0
  task dirty_rs;
    input both;
    begin
      opcode = both ? OP_OP : OP_JALR;
      #1;
    end
  endtask

  function is_legal;
    input [6:0] op;
    begin
      is_legal = (op == OP_LUI)    || (op == OP_AUIPC)  || (op == OP_JAL)   ||
                 (op == OP_JALR)   || (op == OP_BRANCH) || (op == OP_LOAD)  ||
                 (op == OP_STORE)  || (op == OP_OPIMM)  || (op == OP_OP)    ||
                 (op == OP_FENCE)  || (op == OP_SYSTEM);
    end
  endfunction

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/cu_tb.vcd");
      $dumpvars(0, cu_tb);
    end

    opcode = 7'b0;
    #1;

    // ---- A. the nine decoding opcodes ----
    expect_("LUI",    OP_LUI,    1'b1, A_ZERO, B_IMM, ALU_ADD, 1'b0, 1'b0, WB_ALU, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    expect_("AUIPC",  OP_AUIPC,  1'b1, A_PC,   B_IMM, ALU_ADD, 1'b0, 1'b0, WB_ALU, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    expect_("JAL",    OP_JAL,    1'b1, A_PC,   B_IMM, ALU_ADD, 1'b0, 1'b0, WB_PC4, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
    expect_("JALR",   OP_JALR,   1'b1, A_RS1,  B_IMM, ALU_ADD, 1'b0, 1'b0, WB_PC4, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
    expect_("BRANCH", OP_BRANCH, 1'b0, A_RS1,  B_RS2, ALU_BR,  1'b0, 1'b0, WB_ALU, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
    expect_("LOAD",   OP_LOAD,   1'b1, A_RS1,  B_IMM, ALU_ADD, 1'b1, 1'b0, WB_MEM, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
    expect_("STORE",  OP_STORE,  1'b0, A_RS1,  B_IMM, ALU_ADD, 1'b0, 1'b1, WB_ALU, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);
    expect_("OPIMM",  OP_OPIMM,  1'b1, A_RS1,  B_IMM, ALU_I,   1'b0, 1'b0, WB_ALU, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
    expect_("OP",     OP_OP,     1'b1, A_RS1,  B_RS2, ALU_R,   1'b0, 1'b0, WB_ALU, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);

    // ---- B. FENCE / SYSTEM decode to the default vector ----
    dirty_rs(1); expect_nop("FENCE",  OP_FENCE);
    dirty_rs(1); expect_nop("SYSTEM", OP_SYSTEM);

    // ---- C. injected-NOP encoding ----
    // The pipeline's NOP is addi x0,x0,0 = OP_OPIMM, so it decodes as an
    // I-type and legitimately asserts uses_rs1. The HDU sees rs1 = x0 and
    // must be killed by the idex_rd != 0 guard, NOT by uses_rs1.
    // This check exists to record that, so nobody "fixes" it later.
    expect_("NOP=OPIMM", OP_OPIMM, 1'b1, A_RS1, B_IMM, ALU_I, 1'b0, 1'b0, WB_ALU, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);

    // ---- D. full 128-opcode sweep, each illegal value seen twice ----
    // First after OP_OP (both uses_rs* high), then after OP_JALR (only rs1
    // high). A latch on either output retains a 1 and fails here; a correct
    // default block gives the NOP vector both times.
    for (i = 0; i < 128; i = i + 1) begin
      if (!is_legal(i[6:0])) begin
        dirty_rs(1); expect_nop("illegal/afterOP",   i[6:0]);
        dirty_rs(0); expect_nop("illegal/afterJALR", i[6:0]);
      end
    end

    // ---- E. no output may ever be X ----
    for (i = 0; i < 128; i = i + 1) begin
      opcode = i[6:0];
      #1;
      if ((^{reg_write, alu_src_a, alu_src_b, alu_op, mem_read, mem_write,
             wb_sel, branch, jump, jalr, uses_rs1, uses_rs2}) === 1'bx) begin
        fail = fail + 1;
        $display("FAIL X-check: opcode %b drives an X output", i[6:0]);
      end else begin
        pass = pass + 1;
      end
    end

    $display("");
    $display("cu_tb: %0d/%0d passed, %0d failed", pass, pass + fail, fail);
    if (fail == 0) $display("cu_tb: PASS");
    else           $display("cu_tb: FAIL");
    $finish;
  end

endmodule

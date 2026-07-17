`timescale 1ns / 1ps

module alu_control_tb ();
  reg  [1:0] aluOp;
  reg  [2:0] funct3;
  reg  [6:0] funct7;
  wire [3:0] alu_control_out;
  integer    errors = 0;

  alu_control DUT (.aluOp(aluOp), .funct3(funct3), .funct7(funct7),
                   .alu_control_out(alu_control_out));

  localparam ALUOP_ADD=4'b0000, ALUOP_SUB=4'b0001, ALUOP_SLL=4'b0010,
             ALUOP_SLT=4'b0011, ALUOP_SLTU=4'b0100, ALUOP_XOR=4'b0101,
             ALUOP_SRL=4'b0110, ALUOP_SRA=4'b0111, ALUOP_OR=4'b1000,
             ALUOP_AND=4'b1001;

  // funct7 values that actually occur in RV32I
  localparam F7_ZERO = 7'b0000000;   // bit5=0
  localparam F7_ALT  = 7'b0100000;   // bit5=1  (SUB / SRA / SRAI)
  localparam F7_M1   = 7'b1111111;   // imm=-1    -> bit5=1
  localparam F7_2047 = 7'b0111111;   // imm=2047  -> bit5=1

  task chk(input [1:0] ao, input [2:0] f3, input [6:0] f7,
           input [3:0] exp, input [80*8:1] name);
  begin
    aluOp = ao; funct3 = f3; funct7 = f7; #1;
    if (alu_control_out !== exp) begin
      errors = errors + 1;
      $display("FAIL %-24s aluOp=%b f3=%b f7=%b -> %b  exp %b",
               name, ao, f3, f7, alu_control_out, exp);
    end else
      $display("PASS %-24s aluOp=%b f3=%b f7=%b -> %b", name, ao, f3, f7, alu_control_out);
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/alu_control_tb.vcd");
      $dumpvars(0, alu_control_tb);
    end

    $display("--- aluOp=00 : force ADD, funct3/funct7 must be ignored ---");
    chk(2'b00, 3'b000, F7_ZERO, ALUOP_ADD, "LUI/AUIPC/LOAD");
    chk(2'b00, 3'b101, F7_ALT,  ALUOP_ADD, "STORE (f3/f7 ignored)");
    chk(2'b00, 3'b111, F7_M1,   ALUOP_ADD, "JALR (f3/f7 ignored)");

    $display("--- aluOp=01 : force SUB ---");
    chk(2'b01, 3'b000, F7_ZERO, ALUOP_SUB, "BEQ");
    chk(2'b01, 3'b101, F7_ALT,  ALUOP_SUB, "BGE (f3/f7 ignored)");

    $display("--- aluOp=10 : R-type ---");
    chk(2'b10, 3'b000, F7_ZERO, ALUOP_ADD,  "ADD");
    chk(2'b10, 3'b000, F7_ALT,  ALUOP_SUB,  "SUB");
    chk(2'b10, 3'b001, F7_ZERO, ALUOP_SLL,  "SLL");
    chk(2'b10, 3'b010, F7_ZERO, ALUOP_SLT,  "SLT");
    chk(2'b10, 3'b011, F7_ZERO, ALUOP_SLTU, "SLTU");
    chk(2'b10, 3'b100, F7_ZERO, ALUOP_XOR,  "XOR");
    chk(2'b10, 3'b101, F7_ZERO, ALUOP_SRL,  "SRL");
    chk(2'b10, 3'b101, F7_ALT,  ALUOP_SRA,  "SRA");
    chk(2'b10, 3'b110, F7_ZERO, ALUOP_OR,   "OR");
    chk(2'b10, 3'b111, F7_ZERO, ALUOP_AND,  "AND");

    $display("--- aluOp=11 : OP-IMM, bit30 used ONLY for funct3=101 ---");
    chk(2'b11, 3'b000, F7_ZERO, ALUOP_ADD,  "ADDI +5");
    chk(2'b11, 3'b000, F7_M1,   ALUOP_ADD,  "ADDI -1   (bit30=1!)");
    chk(2'b11, 3'b000, F7_2047, ALUOP_ADD,  "ADDI 2047 (bit30=1!)");
    chk(2'b11, 3'b001, F7_ZERO, ALUOP_SLL,  "SLLI");
    chk(2'b11, 3'b010, F7_ZERO, ALUOP_SLT,  "SLTI +n");
    chk(2'b11, 3'b010, F7_M1,   ALUOP_SLT,  "SLTI -1  (bit30=1!)");
    chk(2'b11, 3'b011, F7_M1,   ALUOP_SLTU, "SLTIU -1 (bit30=1!)");
    chk(2'b11, 3'b100, F7_M1,   ALUOP_XOR,  "XORI -1  (bit30=1!)");
    chk(2'b11, 3'b101, F7_ZERO, ALUOP_SRL,  "SRLI");
    chk(2'b11, 3'b101, F7_ALT,  ALUOP_SRA,  "SRAI");
    chk(2'b11, 3'b110, F7_M1,   ALUOP_OR,   "ORI -1   (bit30=1!)");
    chk(2'b11, 3'b111, F7_M1,   ALUOP_AND,  "ANDI -1  (bit30=1!)");

    $display("--- latch check: prime, then feed an X input ---");
    chk(2'b10, 3'b111, F7_ZERO, ALUOP_AND, "prime with AND");
    aluOp = 2'bxx; funct3 = 3'b000; funct7 = F7_ZERO; #1;
    if (alu_control_out === ALUOP_AND) begin
      errors = errors + 1;
      $display("FAIL %-24s retained AND -> latch (add a default)", "X aluOp");
    end else
      $display("PASS %-24s -> %b (no stale hold)", "X aluOp", alu_control_out);

    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

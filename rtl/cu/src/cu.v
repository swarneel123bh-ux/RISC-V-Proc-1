`timescale 1ns / 1ps

module cu (
  input  		 [6:0] opcode,
  output reg       reg_write,
  output reg [1:0] alu_src_a,    // 00=rs1, 01=pc, 10=zero    <- LUI/AUIPC
  output reg       alu_src_b,    // 0=rs2, 1=imm
  output reg [1:0] alu_op,
  output reg       mem_read,
  output reg       mem_write,
  output reg [1:0] wb_sel,       // 00=alu, 01=mem, 10=pc+4    <- JAL/JALR
  output reg       branch,       // conditional
  output reg       jump,         // JAL
  output reg       jalr          // JALR (target from ALU, not adder)
);

	// OPCODES
	localparam OP_LUI = 7'b0110111;
	localparam OP_AUIPC = 7'b0010111;
  localparam OP_JAL = 7'b1101111;
  localparam OP_JALR = 7'b1100111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_LOAD = 7'b0000011;
  localparam OP_STORE = 7'b0100011;
  localparam OP_OPIMM = 7'b0010011;
  localparam OP_OP = 7'b0110011;
  localparam OP_FENCE = 7'b0001111;
  localparam OP_SYSTEM = 7'b1110011;

  // MUX signals
  localparam A_RS1 = 2'b00;
  localparam A_PC = 2'b01;
  localparam A_ZERO = 2'b10;
  localparam B_RS2 = 1'b0;
  localparam B_IMM = 1'b1;
  localparam ALU_ADD = 2'b00;
  localparam ALU_BR = 2'b01;
  localparam ALU_R = 2'b10;
  localparam ALU_I = 2'b11;
  localparam WB_ALU = 2'b00;
  localparam WB_MEM = 2'b01;
  localparam WB_PC4 = 2'b10;


  always @(*) begin
  	reg_write = 1'b0;
  	mem_read  = 1'b0;
  	mem_write = 1'b0;
  	branch = 1'b0;
  	jump = 1'b0;
  	jalr = 1'b0;
  	alu_src_a = A_RS1;
  	alu_src_b = B_RS2;
  	alu_op = ALU_ADD;
  	wb_sel = WB_ALU;

   	case (opcode)
    	OP_LUI: begin
     		reg_write = 1;
       	alu_src_a = A_ZERO;
        alu_src_b = B_IMM;
        alu_op = ALU_ADD;
        wb_sel = WB_ALU;
     end

      OP_AUIPC: begin
      	reg_write = 1;
       	alu_src_a = A_PC;
        alu_src_b = B_IMM;
        alu_op = ALU_ADD;
        wb_sel = WB_ALU;
      end

      // Unused since branch unit should take care of jumps
      OP_JAL: begin
      	reg_write = 1;
       	alu_src_a = A_PC;
        alu_src_b = B_IMM;
        alu_op = ALU_ADD;
        wb_sel = WB_PC4;
        jump = 1;
      end

      // Unused since pc+4 is passed from the pipeline register to the
      // wb mux
      OP_JALR: begin
      	reg_write = 1;
       	alu_src_a = A_RS1;
        alu_src_b = B_IMM;
        alu_op = ALU_ADD;
        wb_sel = WB_PC4;
        jalr = 1;
      end

      OP_BRANCH: begin
      	alu_src_a = A_RS1;
       	alu_src_b = B_RS2;
        alu_op = ALU_BR;
        branch = 1;
      end

      OP_LOAD: begin
      	reg_write = 1;
       	alu_src_a = A_RS1;
        alu_src_b = B_IMM;
        alu_op = ALU_ADD;
        wb_sel = WB_MEM;
        mem_read = 1;
      end

      OP_STORE: begin
      	alu_src_a = A_RS1;
       	alu_src_b = B_IMM;
        alu_op = ALU_ADD;
        mem_write = 1;
      end

      OP_OPIMM: begin
      	reg_write = 1;
       	alu_src_a = A_RS1;
        alu_src_b = B_IMM;
        alu_op = ALU_I;
        wb_sel = WB_ALU;
      end

      OP_OP: begin
      	reg_write = 1;
       	alu_src_a = A_RS1;
        alu_src_b = B_RS2;
        alu_op = ALU_R;
        wb_sel = WB_ALU;
      end

      OP_FENCE:  ;   // NOP
      OP_SYSTEM: ;   // ECALL/EBREAK -> NOP for now
      default:   ;   // defaults above: writes off
    endcase

  end


endmodule

`timescale 1ns / 1ps

module alu_control (
	input [1:0] aluOp,
	input [2:0] funct3,
	input [6:0] funct7,
	output reg [3:0] alu_control_out
);

	// All possible outputs
	localparam ALUOP_ADD = 4'b0000;
	localparam ALUOP_SUB = 4'b0001;
	localparam ALUOP_SLL = 4'b0010;
	localparam ALUOP_SLT = 4'b0011;
	localparam ALUOP_SLTU = 4'b0100;
	localparam ALUOP_XOR = 4'b0101;
	localparam ALUOP_SRL = 4'b0110;
	localparam ALUOP_SRA = 4'b0111;
	localparam ALUOP_OR = 4'b1000;
	localparam ALUOP_AND = 4'b1001;

	always @(*) begin
		alu_control_out = ALUOP_ADD;
		case (aluOp)
			2'b00: begin alu_control_out = ALUOP_ADD; end
			2'b01: begin alu_control_out = ALUOP_SUB; end
			2'b10: begin
				case (funct3)
					3'b000: begin alu_control_out = (funct7[5]) ? ALUOP_SUB : ALUOP_ADD; end
					3'b001: begin alu_control_out = ALUOP_SLL; end
					3'b010: begin alu_control_out = ALUOP_SLT; end
					3'b011: begin alu_control_out = ALUOP_SLTU; end
					3'b100: begin alu_control_out = ALUOP_XOR; end
					3'b101: begin alu_control_out = (funct7[5]) ? ALUOP_SRA : ALUOP_SRL; end
					3'b110: begin alu_control_out = ALUOP_OR; end
					3'b111: begin alu_control_out = ALUOP_AND; end
				endcase
			end
			2'b11: begin
				case (funct3)
					3'b000: begin alu_control_out = ALUOP_ADD; end
					3'b001: begin alu_control_out = ALUOP_SLL; end
					3'b010: begin alu_control_out = ALUOP_SLT; end
					3'b011: begin alu_control_out = ALUOP_SLTU; end
					3'b100: begin alu_control_out = ALUOP_XOR; end
					3'b101: begin alu_control_out = (funct7[5]) ? ALUOP_SRA : ALUOP_SRL; end
					3'b110: begin alu_control_out = ALUOP_OR; end
					3'b111: begin alu_control_out = ALUOP_AND; end
				endcase
			end
		endcase
	end

endmodule

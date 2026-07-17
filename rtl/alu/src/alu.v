`timescale 1ns / 1ps
module alu (
	input [3:0] aluop_ctrl,
	input [31:0] alu_a, alu_b,
	output reg [31:0] alu_out,
	output alu_zero
);

	// All Outputs from alu_control
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
		case (aluop_ctrl)
			ALUOP_ADD 	: begin alu_out = alu_a + alu_b; end
			ALUOP_SUB 	: begin alu_out = alu_a - alu_b; end
			ALUOP_SLL 	: begin alu_out = alu_a << alu_b[4:0]; end
			ALUOP_SLT 	: begin alu_out = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0; end
			ALUOP_SLTU 	: begin alu_out = (alu_a < alu_b) ? 32'd1 : 32'd0;end
			ALUOP_XOR 	: begin alu_out = alu_a ^ alu_b; end
			ALUOP_SRL 	: begin alu_out = alu_a >> alu_b[4:0]; end
			ALUOP_SRA 	: begin alu_out = $signed(alu_a) >>> alu_b[4:0]; end
			ALUOP_OR 		: begin alu_out = alu_a | alu_b; end
			ALUOP_AND 	: begin alu_out = alu_a & alu_b; end
			default: begin alu_out = 32'h0; end
		endcase
	end

	assign alu_zero = (alu_out == 0);

endmodule

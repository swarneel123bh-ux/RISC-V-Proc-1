`timescale 1ns / 1ps
module alu (
	input [3:0] aluop_ctrl,
	input [31:0] alu_a, alu_b,
	output reg [31:0] alu_out,
	output alu_zero
);

	// All Outputs from alu_control
	localparam ALUOP_ADD 		= 4'b0000;
	localparam ALUOP_SUB 		= 4'b0001;
	localparam ALUOP_SLL 		= 4'b0010;
	localparam ALUOP_SLT 		= 4'b0011;
	localparam ALUOP_SLTU 	= 4'b0100;
	localparam ALUOP_XOR 		= 4'b0101;
	localparam ALUOP_SRL 		= 4'b0110;
	localparam ALUOP_SRA 		= 4'b0111;
	localparam ALUOP_OR 		= 4'b1000;
	localparam ALUOP_AND 		= 4'b1001;
	localparam ALUOP_MUL 		= 4'b1010;
	localparam ALUOP_MULH 	= 4'b1011;
	localparam ALUOP_MULHU 	= 4'b1100;
	localparam ALUOP_MULHSU = 4'b1101;
	localparam ALUOP_DIV 		= 4'b1110;
	localparam ALUOP_DIVU 	= 4'b1111;  // Note: DIV for signed, DIVU for unsigned; same for REM
	// (funct3 distinguishes DIV vs REM)

	// M extension instantiations
	alu_mult multiplier (
		.a         (a),
		.b         (b),
		.prod_lo   (prod_lo),
		.prod_hi_s (prod_hi_s),
		.prod_hi_u (prod_hi_u),
		.prod_hi_su(prod_hi_su)
	);

	div_iter div_iter (
		.clk      (clk),
		.rstb     (rstb),
		.start    (start),
		.dividend (dividend),
		.divisor  (divisor),
		.quotient (quotient),
		.remainder(remainder),
		.ready    (ready),
		.dbz      (dbz)
	);

	always @(*) begin
		case (aluop_ctrl)
			ALUOP_ADD 		: begin alu_out = alu_a + alu_b; end
			ALUOP_SUB 		: begin alu_out = alu_a - alu_b; end
			ALUOP_SLL 		: begin alu_out = alu_a << alu_b[4:0]; end
			ALUOP_SLT 		: begin alu_out = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0; end
			ALUOP_SLTU 		: begin alu_out = (alu_a < alu_b) ? 32'd1 : 32'd0;end
			ALUOP_XOR 		: begin alu_out = alu_a ^ alu_b; end
			ALUOP_SRL 		: begin alu_out = alu_a >> alu_b[4:0]; end
			ALUOP_SRA 		: begin alu_out = $signed(alu_a) >>> alu_b[4:0]; end
			ALUOP_OR 			: begin alu_out = alu_a | alu_b; end
			ALUOP_AND 		: begin alu_out = alu_a & alu_b; end
			ALUOP_MUL 		: begin end;
			ALUOP_MULH 		: begin end;
			ALUOP_MULHU 	: begin end;
			ALUOP_MULHSU 	: begin end;
			ALUOP_DIV 		: begin end;
			ALUOP_DIVU 		: begin end;
			default: begin alu_out = 32'h0; end
		endcase
	end

	assign alu_zero = (alu_out == 0);

endmodule

`timescale 1ns / 1ps
module alu (
	input clk, rstb,
	input [3:0] aluop_ctrl,
	input [31:0] alu_a, alu_b,
	output reg [31:0] alu_out,
	output alu_zero, alu_busy
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
	localparam ALUOP_DIVU 	= 4'b1111;
	// (funct3 distinguishes DIV vs REM)

	// M extension instantiations
	wire [31:0] multiplier_prod_lo;
	wire [31:0] multiplier_prod_hi_s;
	wire [31:0] multiplier_prod_hi_u;
	wire [31:0] multiplier_prod_hi_su;
	alu_mult multiplier (
		.a         (alu_a),
		.b         (alu_b),
		.prod_lo   (multiplier_prod_lo),
		.prod_hi_s (multiplier_prod_hi_s),
		.prod_hi_u (multiplier_prod_hi_u),
		.prod_hi_su(multiplier_prod_hi_su)
	);

	localparam DIV_STATE_IDLE = 2'b00;
	localparam DIV_STATE_WAITING = 2'b01;
	localparam DIV_STATE_DONE = 2'b10;
	reg [1:0] div_state;
	wire div_start = (div_state == DIV_STATE_IDLE) && ((aluop_ctrl == ALUOP_DIV) || aluop_ctrl == ALUOP_DIVU);
	wire [31:0] div_quotient;
	wire [31:0] div_remainder;
	wire div_ready;
	wire div_dbz;
	div_iter div_iter (
		.clk      (clk),
		.rstb     (rstb),
		.start    (div_start),
		.dividend (alu_a),
		.divisor  (alu_b),
		.quotient (div_quotient),
		.remainder(div_remainder),
		.ready    (div_ready),
		.dbz      (div_dbz)
	);

	// Division module FSM
	always @(posedge clk or negedge rstb) begin
		if (!rstb) begin
			div_state <= DIV_STATE_IDLE;
		end else begin
			case (div_state)
				DIV_STATE_IDLE: begin
					if (aluop_ctrl == ALUOP_DIV || aluop_ctrl == ALUOP_DIVU) begin
						div_state <= DIV_STATE_WAITING;
					end
				end

				DIV_STATE_WAITING: begin
					if (div_ready) div_state <= DIV_STATE_DONE;
					else div_state <= DIV_STATE_WAITING;
				end

				DIV_STATE_DONE: begin
					div_state <= DIV_STATE_IDLE;
				end

				default: div_state <= DIV_STATE_IDLE;
			endcase
		end
	end

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
			ALUOP_MUL 		: begin alu_out = multiplier_prod_lo; end
			ALUOP_MULH 		: begin alu_out = multiplier_prod_hi_s; end
			ALUOP_MULHU 	: begin alu_out = multiplier_prod_hi_u; end
			ALUOP_MULHSU 	: begin alu_out = multiplier_prod_hi_su; end
			ALUOP_DIV 		: begin alu_out = div_quotient; end
			ALUOP_DIVU 		: begin alu_out = div_quotient; end
			default: begin alu_out = 32'h0; end
		endcase
	end

	assign alu_zero = (alu_out == 0);
	assign alu_busy =
	((aluop_ctrl == ALUOP_DIV) && (div_state != DIV_STATE_DONE))
	|| ((aluop_ctrl == ALUOP_DIVU) && (div_state != DIV_STATE_DONE));

endmodule

`timescale 1ns / 1ps

module alu_mult (
	input [31:0] a,
	input [31:0] b,
	output [31:0] prod_lo,			// MUL
	output [31:0] prod_hi_s,		// MULH
	output [31:0] prod_hi_u,		// MULHU
	output [31:0] prod_hi_su		// MULHSU
);
	wire signed [63:0] a_sign_ext = {{32{a[31]}}, a};
	wire [63:0] prod_signed = $signed(a) * $signed(b);
	wire [63:0] prod_mixed 	= a_sign_ext * b;
	wire [63:0] prod_usigned = a * b;
	assign prod_lo 			= prod_usigned[31:0];
	assign prod_hi_s 		= prod_signed[63:32];
	assign prod_hi_u 		= prod_usigned[63:32];
	assign prod_hi_su 	= prod_mixed[63:32];
endmodule

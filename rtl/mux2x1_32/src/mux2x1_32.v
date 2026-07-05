
`timescale 1ns/1ps;

module mux2x1_32(
	input wire sel,
	input wire [31:0] in1, in2,
	output wire [31:0] out
);

	assign out = (sel) ? in2 : in1;

endmodule

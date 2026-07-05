
`timescale 1ns/1ps

module add4(
	input wire [31:0] in,
	output wire [31:0] out
);

	assign out = in + 4;

endmodule

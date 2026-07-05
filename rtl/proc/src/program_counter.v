`timescale 1ns/1ps

module program_counter(
	input wire rstb,
	input wire clk,
	input wire [31:0] in,
	output reg [31:0] out
);

	always @(posedge clk or negedge rstb) begin
		if (!rstb) begin
			out <= 32'h00000000;
		end else begin
			out <= in;
		end
	end

endmodule

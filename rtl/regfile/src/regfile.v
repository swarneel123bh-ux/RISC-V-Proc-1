`timescale 1ns / 1ps
module regfile (
	input clk,
	input rstb,
	input wen,
	input wire [4:0] raddr1,
	input wire [4:0] raddr2,
	output wire [31:0] rdata1,
	output wire [31:0] rdata2,
	input wire [4:0] waddr,
	input wire [31:0] wdata
);

	reg [31:0] registers [0:31];
	integer i;

	always @(posedge clk or negedge rstb) begin
		if (!rstb) begin
			for (i = 0; i < 32; i = i + 1) begin
				registers[i] <= 32'h00000000;
			end
		end else begin
			if (wen && waddr != 5'h0) begin
				registers[waddr] <= wdata;
			end else begin end
		end
	end

	assign rdata1 = (raddr1 == 5'd0) ? 32'h0
              : (wen && waddr == raddr1) ? wdata
              : registers[raddr1];
	assign rdata2 = (raddr2 == 5'd0) ? 32'h0
              : (wen && waddr == raddr2) ? wdata
              : registers[raddr2];

endmodule

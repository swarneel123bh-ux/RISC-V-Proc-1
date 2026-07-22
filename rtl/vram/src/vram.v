`timescale 1ns / 1ps

module vram #(
	parameter PIX_W = 160,
	parameter PIX_H = 120
) (
	input wire clk,
	// CPU side ports
	input wire [31:0] cpu_addr,
	input wire [31:0] cpu_wdata,
	input wire [3:0] 	cpu_wstrb,
	input wire 			  cpu_read,
	output wire [31:0] cpu_rdata,
	// Scanout side ports (for SDL)
	input wire [31:0] scan_widx,
	output wire [31:0] scan_rdata
);
	localparam DEPTH_WORDS = (PIX_W * PIX_H) / 4;	// 4800 bytes for default resolution
	localparam AW = $clog2(DEPTH_WORDS);	// Address Width
	reg [31:0] mem[0:DEPTH_WORDS-1];

	integer k;
	initial begin
		for (k = 0; k < DEPTH_WORDS; k = k + 1) begin
			mem[k] = 32'h0;
		end
	end

	wire [AW-1:0] cpu_widx = cpu_addr[AW+1:2];

	always @(posedge clk) begin
		if (cpu_wstrb[0]) mem[cpu_widx][7:0] 		<= cpu_wdata[7:0];
		if (cpu_wstrb[1]) mem[cpu_widx][15:8] 	<= cpu_wdata[15:8];
		if (cpu_wstrb[2]) mem[cpu_widx][23:16] 	<= cpu_wdata[23:16];
		if (cpu_wstrb[3]) mem[cpu_widx][31:24] 	<= cpu_wdata[31:24];
	end

	assign cpu_rdata = cpu_read ? mem[cpu_widx] : 32'h0;
	assign scan_rdata = mem[scan_widx[AW-1:0]];

  // TODO: implementation
endmodule

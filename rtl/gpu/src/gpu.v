`timescale 1ns / 1ps

// Graphics co-processor, MMIOd in datamem
//
// CPU must issue commands, allow DMA into VRAM
//
// VRAM simply is extra memory, will print to screen from
// video-controller
//
// GPU.V must calculate from (x,y) positions into where the
// pixel to be lit is, and modify VRAM accordinly. Later must
// extend into lines and circles (implement bresenhams),
// and finally implement 3D nets so 3D graphics can be allowed
module gpu #(
	parameter PIX_W = 160,
	parameter PIX_H = 120
) (
	input wire clk,
	input wire rstb,

	// CPU side ports
	input wire [31:0] 	cpu_addr,
	input wire [31:0] 	cpu_wdata,
	input wire [3:0] 		cpu_wstrb,
	input wire 			  	cpu_read,
	output wire [31:0] 	cpu_rdata,

	// Vram side ports (for SDL)
	input wire [31:0] 	vram_addr,
	input wire [31:0] 	vram_wdata,
	input wire [3:0] 		vram_wstrb,
	input wire 			  	vram_read,
	output wire [31:0] 	vram_rdata

	// input wire [31:0] scan_widx,
	// output wire [31:0] scan_rdata
);

	// VRAM Params to help calculations
	localparam DEPTH_WORDS = (PIX_W * PIX_H) / 4;	// 4800 bytes for default resolution
	localparam AW = $clog2(DEPTH_WORDS);	// Address Width
	// reg [31:0] mem[0:DEPTH_WORDS-1];


endmodule

`timescale 1ns / 1ps

`ifndef UMEM_HEXFILE
  `define UMEM_HEXFILE "../../software/rom/program.hex"
`endif

module unified_memory #(
	parameter DEPTH_WORDS = 16384,
	parameter HEXFILE = `UMEM_HEXFILE
)(
	input  wire        clk,

  // Instruction side ports, read-only, async
  input  wire [31:0] imem_addr,
  output wire [31:0] imem_rdata,

  // Data side ports, async read + sync byte-strobed write
  input  wire [31:0] dmem_addr,
  input  wire [31:0] dmem_wdata,
  input  wire [3:0]  dmem_wstrb,
  input  wire        dmem_read,
  output wire [31:0] dmem_rdata
);

	localparam ADDRWIDTHS = $clog2(DEPTH_WORDS);
	reg [31:0] memory [0:DEPTH_WORDS-1];

	// Initialization of memory from hexfile,
	// This is now needed because the instructions are also in this memory,
	// NOTE, this is NOT how real ram works, real instructions need to be loaded into disk
	// But we dont have a disk yet, so we do that work using this snippet
	integer k;
	initial begin
		for (k = 0; k < DEPTH_WORDS; k = k + 1) begin
			memory[k] = 32'h0;
		end
		$readmemh(HEXFILE, memory);
	end

	// Get the word indices from the address
	wire [ADDRWIDTHS-1:0] imem_wordidx  = imem_addr[ADDRWIDTHS+1 : 2];
	wire [ADDRWIDTHS-1:0] dmem_wordidx  = dmem_addr[ADDRWIDTHS+1 : 2];

	// Assign the full word,
	assign imem_rdata = memory[imem_wordidx];

	// Handle data_mem.v-writes work here
	always @(posedge clk) begin
		if (dmem_wstrb[0]) memory[dmem_wordidx][7:0] 		<= dmem_wdata[7:0];
		if (dmem_wstrb[1]) memory[dmem_wordidx][15:8] 	<= dmem_wdata[15:8] ;
		if (dmem_wstrb[2]) memory[dmem_wordidx][23:16] 	<= dmem_wdata[23:16];
		if (dmem_wstrb[3]) memory[dmem_wordidx][31:24] 	<= dmem_wdata[31:24];
	end

	// Assign data_mem reads
	assign dmem_rdata = dmem_read ? memory[dmem_wordidx] : 32'h0;

endmodule

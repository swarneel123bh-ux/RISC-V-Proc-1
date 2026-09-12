`timescale 1ns / 1ps

// `include "imem_params.vh"
// `ifndef IMEM_HEXFILE
//   `define IMEM_HEXFILE "../../software/rom/program.hex"
// `endif

module instruction_mem //#(
//  parameter DEPTH = `IMEM_DEPTH,        // Depth generated from software/imem_depth.py
//  parameter SYNC    = 1,                // 1 = synchronous readouts 0 = async (sim-only)
//  parameter HEXFILE = `IMEM_HEXFILE     // override with -DIMEM_HEXFILE='"..."' per run CWD )
(
	// Processor side ports
	input  wire        clk,
  input  wire [31:0] addr,
  input   wire      imem_en,
  //input wire imem_wen,
  output wire [31:0] instr,

  // Unified Memory side ports
  output wire [31:0] umem_addr,
  output wire        umem_imem_en,
  // output wire umem_imem_wen,
  input wire 	[31:0] umem_rdata
);

  assign umem_imem_en = imem_en;
  // assign umem_imem_wen = imem_wen;

	// Simple pass through, later will cache (meaning imem will also have its own memory)
	assign umem_addr = addr;
	assign instr = umem_rdata;

endmodule

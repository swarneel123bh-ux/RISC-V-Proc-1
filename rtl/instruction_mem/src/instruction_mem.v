`timescale 1ns / 1ps

`include "imem_params.vh"
module instruction_mem #(
	parameter DEPTH = `IMEM_DEPTH,				// Depth generated from the script software/imem_depth.py
  parameter SYNC    = 1,                // 1 = synchronous readouts 0 = async (sim-only)
  parameter HEXFILE = "../../software/rom/program.hex" // Must be the same for the sim to run
) (
  input  wire        clk,               // used only when SYNC=1
  input  wire [31:0] addr,
  output wire [31:0] instr
);
  localparam AW = $clog2(DEPTH);
  reg [31:0] mem [0:DEPTH-1];

  initial $readmemh(HEXFILE, mem);

  wire [AW-1:0] widx = addr[AW+1:2];    // word index, drop byte offset

  generate
    if (SYNC) begin : g_sync
      reg [31:0] rdata;
      always @(posedge clk) rdata <= mem[widx];
      assign instr = rdata;
    end else begin : g_async
      assign instr = mem[widx];
    end
  endgenerate
endmodule

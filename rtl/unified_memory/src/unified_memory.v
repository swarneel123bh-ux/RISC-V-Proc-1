`timescale 1ns / 1ps

`ifndef UMEM_HEXFILE
  `define UMEM_HEXFILE "../../software/rom/program.hex"
`endif

module unified_memory #(
  parameter DEPTH_WORDS = 8192,   // data/main memory, 32 KB
  parameter IMEM_WORDS  = 2048,   // instruction mirror, 8 KB — code must fit below this
  parameter HEXFILE     = `UMEM_HEXFILE
)(
  input  wire        clk,

  // Instruction side — sync read, mirror array, never written by this port
  input  wire [31:0] imem_addr,
  input  wire        imem_en,
  output reg  [31:0] imem_rdata,

  // Data side — sync read + sync byte-strobed write
  input  wire [31:0] dmem_addr,
  input  wire [31:0] dmem_wdata,
  input  wire [3:0]  dmem_wstrb,
  input  wire        dmem_read,
  output reg  [31:0] dmem_rdata
);

  localparam ADDRWIDTHS = $clog2(DEPTH_WORDS);
  localparam IAW        = $clog2(IMEM_WORDS);

  // Two physical arrays holding the same low-region contents.
  // Split so that NEITHER array is a true dual-port RAM:
  //   memory_i : one reader (imem), one writer (dmem)  -> SDPB
  //   memory   : one port, read or write, exclusive    -> SP
  // A single array with two readers infers DPB, whose read-only port gets
  // WRITE_MODE0 = 2'b10 by default and is rejected by PnR (PA2122). Adding a
  // write to that port makes it a true dual-port, which GowinSynthesis cannot
  // infer at all and falls back to 262144 DFF. Both dead ends; this is neither.
  reg [31:0] memory   [0:DEPTH_WORDS-1];
  reg [31:0] memory_i [0:IMEM_WORDS-1];

  initial begin
    $readmemh(HEXFILE, memory);
    $readmemh(HEXFILE, memory_i);
  end

  wire [ADDRWIDTHS-1:0] dmem_wordidx = dmem_addr[ADDRWIDTHS+1 : 2];
  wire [IAW-1:0]        imem_wordidx = imem_addr[IAW+1 : 2];

  // A data write lands in the mirror only if it targets the mirrored region.
  wire mirror_hit = (dmem_wordidx < IMEM_WORDS);

  // Instruction mirror. Read and write are INDEPENDENT — no else, they are
  // separate ports and must both act in the same cycle.
  always @(posedge clk) begin
    if (mirror_hit) begin
      if (dmem_wstrb[0]) memory_i[dmem_wordidx[IAW-1:0]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) memory_i[dmem_wordidx[IAW-1:0]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) memory_i[dmem_wordidx[IAW-1:0]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) memory_i[dmem_wordidx[IAW-1:0]][31:24] <= dmem_wdata[31:24];
    end
    if (imem_en) imem_rdata <= memory_i[imem_wordidx];
  end

  // Data port. Read and write are EXCLUSIVE — the else is what makes the
  // inferred write mode no-change rather than read-before-write.
  always @(posedge clk) begin
    if (|dmem_wstrb) begin
      if (dmem_wstrb[0]) memory[dmem_wordidx][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) memory[dmem_wordidx][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) memory[dmem_wordidx][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) memory[dmem_wordidx][31:24] <= dmem_wdata[31:24];
    end else begin
      dmem_rdata <= dmem_read ? memory[dmem_wordidx] : 32'h0;
    end
  end

endmodule

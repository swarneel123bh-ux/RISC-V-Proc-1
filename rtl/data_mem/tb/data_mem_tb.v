`timescale 1ns / 1ps
//============================================================================
// data_mem_tb.v  --  NOT MINE (Claude-authored harness, Phase 1.5 step 1)
//
// data_mem no longer stores anything. It is a region decoder plus an output
// mux with a registered select. This bench tests exactly that and nothing
// else; byte-lane merging, sub-word writes and retention now belong to
// unified_memory's own bench.
//
// Device stubs below respond with a per-device tag so a mis-selected source
// is visible as a wrong tag rather than as z. They deliberately respond
// regardless of their read strobe, so the mux select is exercised
// independently of the enables.
//
// Requires the vram and uart instances in data_mem.v to be uncommented, and
// the real vram.v / uart.v to be OUT of this target's file list.
//============================================================================

//---------------------------------------------------------------- vram stub
module vram (
  input  wire        clk,
  input  wire [31:0] cpu_addr,
  input  wire [31:0] cpu_wdata,
  input  wire [3:0]  cpu_wstrb,
  input  wire        cpu_read,
  output reg  [31:0] cpu_rdata,
  input  wire [31:0] scan_widx,
  output wire [31:0] scan_rdata
);
  assign scan_rdata = 32'h0;
  initial cpu_rdata = 32'h0;
  always @(posedge clk)
    cpu_rdata <= {16'hBBBB, cpu_addr[15:0]};
endmodule

//---------------------------------------------------------------- uart stub
module uart (
  input  wire        clk,
  input  wire        rst,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire        we,
  input  wire        re,
  input  wire        cs,
  output reg  [31:0] rdata,
  output wire        rx_ready
);
  assign rx_ready = 1'b0;
  initial rdata = 32'h0;
  always @(posedge clk)
    rdata <= {16'hCCCC, addr[15:0]};
endmodule

//---------------------------------------------------------------- testbench
module data_mem_tb ();

  localparam VRAMBASE = 32'hFFFE0000;
  localparam UARTBASE = 32'hFFFF0000;

  // region codes, decoded independently of the DUT
  localparam R_RAM  = 2'd0;
  localparam R_VRAM = 2'd1;
  localparam R_UART = 2'd2;

  reg         clk = 0;
  reg         rstb;
  reg  [31:0] addr, wdata;
  reg  [3:0]  wstrb;
  reg         mem_read;
  wire [31:0] rdata;

  wire [31:0] umem_addr, umem_wdata;
  wire [3:0]  umem_wstrb;
  wire        umem_read;
  reg  [31:0] umem_rdata;

  integer errors = 0;

  data_mem DUT (
    .clk(clk), .rstb(rstb), .addr(addr), .wdata(wdata),
    .wstrb(wstrb), .mem_read(mem_read), .rdata(rdata),
    .umem_addr(umem_addr), .umem_wdata(umem_wdata),
    .umem_wstrb(umem_wstrb), .umem_read(umem_read),
    .umem_rdata(umem_rdata));

  always #5 clk = ~clk;

  // unified_memory stub, same one-cycle shape as the internal devices
  initial umem_rdata = 32'h0;
  always @(posedge clk)
    umem_rdata <= {16'hAAAA, umem_addr[15:0]};

  //-------------------------------------------------------------- helpers
  task fail(input [80*8:1] name, input [31:0] got, input [31:0] exp);
  begin
    errors = errors + 1;
    $display("FAIL %-30s got %08h  exp %08h", name, got, exp);
  end
  endtask

  task pass(input [80*8:1] name);
  begin
    $display("PASS %-30s", name);
  end
  endtask

  // Check that only the addressed device sees strobes this cycle.
  // Combinational, so valid in the same cycle the address is presented.
  task check_strobes(input [1:0] region, input [3:0] s, input r,
                     input [80*8:1] name);
    reg ok;
  begin
    ok = 1'b1;
    if (umem_wstrb     !== ((region == R_RAM)  ? s : 4'b0000)) ok = 1'b0;
    if (umem_read      !== ((region == R_RAM)  & r))           ok = 1'b0;
    if (DUT.vram_wstrb !== ((region == R_VRAM) ? s : 4'b0000)) ok = 1'b0;
    if (DUT.vram_read  !== ((region == R_VRAM) & r))           ok = 1'b0;
    if (DUT.uart_we    !== ((region == R_UART) & (|s)))        ok = 1'b0;
    if (DUT.uart_re    !== ((region == R_UART) & r))           ok = 1'b0;
    if (!ok) begin
      errors = errors + 1;
      $display("FAIL %-30s strobes umem[%b,%b] vram[%b,%b] uart[%b,%b] region=%0d",
               name, umem_wstrb, umem_read, DUT.vram_wstrb, DUT.vram_read,
               DUT.uart_we, DUT.uart_re, region);
    end else
      pass(name);
  end
  endtask

  // One bus beat. Present the access, check its strobes in the same cycle,
  // then check rdata one cycle later. Sampling is always posedge + delta,
  // never at the edge.
  task beat(input [31:0] a, input [3:0] s, input r,
            input [1:0] region, input [31:0] exp,
            input [80*8:1] name);
  begin
    @(negedge clk);
    addr     = a;
    wdata    = 32'h5A5A5A5A;
    wstrb    = s;
    mem_read = r;
    #1;
    check_strobes(region, s, r, {name, " strobes"});
    @(posedge clk); #1;
    if (rdata !== exp) fail({name, " rdata"}, rdata, exp);
    else               pass({name, " rdata"});
  end
  endtask

  //-------------------------------------------------------------- sequence
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/data_mem_tb.vcd");
      $dumpvars(0, data_mem_tb);
    end

    rstb = 0; addr = 0; wdata = 0; wstrb = 0; mem_read = 0;

    // Reset: all selects low, mux default arm. Catches an X select, which
    // would otherwise be invisible on hardware and X-locked in sim.
    @(posedge clk); #1;
    if (rdata !== 32'h0) fail("reset -> rdata 0", rdata, 32'h0);
    else                 pass("reset -> rdata 0");

    @(negedge clk); rstb = 1;

    // Basic routing, one region at a time.
    beat(32'h0000_0100, 4'b0000, 1'b1, R_RAM,  32'hAAAA_0100, "read RAM");
    beat(32'hFFFE_0040, 4'b0000, 1'b1, R_VRAM, 32'hBBBB_0040, "read VRAM");
    beat(32'hFFFF_0008, 4'b0000, 1'b1, R_UART, 32'hCCCC_0008, "read UART");

    // Back-to-back region changes. A stale select passes every same-region
    // pair, so this is the only sequence that can catch one.
    beat(32'hFFFE_0080, 4'b0000, 1'b1, R_VRAM, 32'hBBBB_0080, "VRAM after UART");
    beat(32'h0000_0104, 4'b0000, 1'b1, R_RAM,  32'hAAAA_0104, "RAM after VRAM");
    beat(32'hFFFF_000C, 4'b0000, 1'b1, R_UART, 32'hCCCC_000C, "UART after RAM");
    beat(32'h0000_0108, 4'b0000, 1'b1, R_RAM,  32'hAAAA_0108, "RAM after UART");
    beat(32'hFFFE_00C0, 4'b0000, 1'b1, R_VRAM, 32'hBBBB_00C0, "VRAM after RAM");
    beat(32'hFFFF_0000, 4'b0000, 1'b1, R_UART, 32'hCCCC_0000, "UART after VRAM");

    // Decode boundaries.
    beat(32'hFFFD_FFFF, 4'b0000, 1'b1, R_RAM,  32'hAAAA_FFFF, "just below VRAMBASE");
    beat(32'hFFFE_0000, 4'b0000, 1'b1, R_VRAM, 32'hBBBB_0000, "VRAMBASE");
    beat(32'hFFFE_FFFF, 4'b0000, 1'b1, R_VRAM, 32'hBBBB_FFFF, "top of VRAM");
    beat(32'hFFFF_0000, 4'b0000, 1'b1, R_UART, 32'hCCCC_0000, "UARTBASE");

    // Writes: the point is that only the addressed device is strobed.
    beat(32'h0000_0200, 4'b1111, 1'b0, R_RAM,  32'hAAAA_0200, "write RAM");
    beat(32'hFFFE_0100, 4'b1111, 1'b0, R_VRAM, 32'hBBBB_0100, "write VRAM");
    beat(32'hFFFF_0000, 4'b1111, 1'b0, R_UART, 32'hCCCC_0000, "write UART");
    beat(32'h0000_0204, 4'b0010, 1'b0, R_RAM,  32'hAAAA_0204, "write RAM lane1");

    // Idle: strobes must all drop.
    beat(32'h0000_0300, 4'b0000, 1'b0, R_RAM,  32'hAAAA_0300, "idle RAM addr");

    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

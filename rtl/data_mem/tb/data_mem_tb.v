`timescale 1ns / 1ps
//============================================================================
// data_mem_tb.v  --  NOT MINE (Claude-authored harness, Phase 1.5 step 2)
//
// data_mem is a region decoder plus an output mux with a registered select.
// This bench tests that, and nothing about storage.
//
// vram and unified_memory are stubbed with per-device tags so a mis-selected
// source shows as a wrong tag rather than as z. The UART is the REAL
// uart_top: it is what step 2 changed, and the one fact this bench exists to
// establish is that its registered cpu_rdata has the same one-cycle shape the
// stubs model. uart_top's own behaviour is covered by uart_top_tb at 128/128
// and is not retested here.
//
// The serial side is tied idle. No loopback (locked decision 13).
//
// File list: data_mem.v, uart_top.v, uart_tx.v, uart_rx.v, the shared .vh,
// and this bench. The real vram.v must be OUT of the list.
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

//---------------------------------------------------------------- testbench
module data_mem_tb ();

  localparam VRAMBASE = 32'hFFFE0000;
  localparam UARTBASE = 32'hFFFF0000;

  localparam OFF_TX  = 32'd0;
  localparam OFF_RX  = 32'd4;
  localparam OFF_ST  = 32'd8;
  localparam OFF_CTL = 32'd12;

  localparam R_RAM  = 2'd0;
  localparam R_VRAM = 2'd1;
  localparam R_UART = 2'd2;

  localparam ALL = 32'hFFFF_FFFF;

  // Expected reset values, derived from the frozen layout in HANDOFF section 6.
  // If either fails, either the shared .vh drifted or the CLK_FREQ override
  // did not land. Both are worth knowing before step 3.
  //   STATUS: rx_buf_empty[0]=1, tx_buf_empty[2]=1, all pointers 0
  //   CTL:    baud_div at bit 16 = 27_000_000/115200 = 234 = 0xEA
  localparam [31:0] STATUS_RESET = 32'h0000_0005;
  localparam [31:0] CTL_RESET    = 32'h00EA_0000;

  localparam [31:0] M_RX_EMPTY = 32'h0000_0001;
  localparam [31:0] M_TX_EMPTY = 32'h0000_0004;

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

  wire        ser_tx;

  integer errors = 0;

  data_mem DUT (
    .clk(clk), .rstb(rstb), .addr(addr), .wdata(wdata),
    .wstrb(wstrb), .mem_read(mem_read), .rdata(rdata),
    .umem_addr(umem_addr), .umem_wdata(umem_wdata),
    .umem_wstrb(umem_wstrb), .umem_read(umem_read),
    .umem_rdata(umem_rdata),
    .ser_rx(1'b1),            // idle high, no serial stimulus
    .ser_tx(ser_tx));

  always #5 clk = ~clk;

  // unified_memory stub, same one-cycle shape as the real devices
  initial umem_rdata = 32'h0;
  always @(posedge clk)
    umem_rdata <= {16'hAAAA, umem_addr[15:0]};

  //-------------------------------------------------------------- helpers
  task pass(input [80*8:1] name);
  begin
    $display("PASS %-32s", name);
  end
  endtask

  task fail(input [80*8:1] name, input [31:0] got, input [31:0] exp);
  begin
    errors = errors + 1;
    $display("FAIL %-32s got %08h  exp %08h", name, got, exp);
  end
  endtask

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
      $display("FAIL %-32s strobes umem[%b,%b] vram[%b,%b] uart[%b,%b] region=%0d",
               name, umem_wstrb, umem_read, DUT.vram_wstrb, DUT.vram_read,
               DUT.uart_we, DUT.uart_re, region);
    end else
      pass(name);
  end
  endtask

  // One bus beat. Present the access, check its strobes in the same cycle,
  // then check rdata one cycle later. Sampling is posedge + delta, never at
  // the edge. mask selects which rdata bits are asserted on; ALL is exact.
  task beat(input [31:0] a, input [31:0] d, input [3:0] s, input r,
            input [1:0] region, input [31:0] exp, input [31:0] mask,
            input [80*8:1] name);
  begin
    @(negedge clk);
    addr     = a;
    wdata    = d;
    wstrb    = s;
    mem_read = r;
    #1;
    check_strobes(region, s, r, {name, " strobes"});
    @(posedge clk); #1;
    if ((rdata & mask) !== (exp & mask)) fail({name, " rdata"}, rdata, exp);
    else                                 pass({name, " rdata"});
  end
  endtask

  // A cycle with nothing asserted, so a held address does not strobe a
  // device a second time.
  task idle;
  begin
    @(negedge clk);
    addr = 32'h0000_0400; wdata = 32'h0; wstrb = 4'b0000; mem_read = 1'b0;
    @(posedge clk); #1;
  end
  endtask

  //-------------------------------------------------------------- sequence
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/data_mem_tb.vcd");
      $dumpvars(0, data_mem_tb);
    end

    rstb = 0; addr = 0; wdata = 0; wstrb = 0; mem_read = 0;
    repeat (4) @(posedge clk);
    #1;
    if (rdata !== 32'h0) fail("reset -> rdata 0", rdata, 32'h0);
    else                 pass("reset -> rdata 0");

    @(negedge clk); rstb = 1;
    repeat (2) @(posedge clk);

    //---- routing, one region at a time -------------------------------
    beat(32'h0000_0100, 32'h0, 4'b0000, 1'b1, R_RAM,
         32'hAAAA_0100, ALL, "read RAM");
    beat(VRAMBASE + 32'h40, 32'h0, 4'b0000, 1'b1, R_VRAM,
         32'hBBBB_0040, ALL, "read VRAM");

    //---- real UART: STATUS and CTL at reset ---------------------------
    // Exact compares. STATUS is an independent witness of the .vh layout;
    // CTL is the only check that the CLK_FREQ=27 MHz override took effect.
    beat(UARTBASE + OFF_ST, 32'h0, 4'b0000, 1'b1, R_UART,
         STATUS_RESET, ALL, "UART STATUS reset");
    beat(UARTBASE + OFF_CTL, 32'h0, 4'b0000, 1'b1, R_UART,
         CTL_RESET, ALL, "UART CTL reset (baud div)");

    //---- back-to-back region changes ---------------------------------
    // A stale select passes every same-region pair, so this block is the
    // only thing that can catch one. The UART entries also prove its
    // registered cpu_rdata lands on the same cycle as the stubs' -- the
    // fact step 2 exists to establish.
    beat(VRAMBASE + 32'h80, 32'h0, 4'b0000, 1'b1, R_VRAM,
         32'hBBBB_0080, ALL, "VRAM after UART");
    beat(32'h0000_0104, 32'h0, 4'b0000, 1'b1, R_RAM,
         32'hAAAA_0104, ALL, "RAM after VRAM");
    beat(UARTBASE + OFF_ST, 32'h0, 4'b0000, 1'b1, R_UART,
         STATUS_RESET, ALL, "UART after RAM");
    beat(32'h0000_0108, 32'h0, 4'b0000, 1'b1, R_RAM,
         32'hAAAA_0108, ALL, "RAM after UART");
    beat(VRAMBASE + 32'hC0, 32'h0, 4'b0000, 1'b1, R_VRAM,
         32'hBBBB_00C0, ALL, "VRAM after RAM");
    beat(UARTBASE + OFF_CTL, 32'h0, 4'b0000, 1'b1, R_UART,
         CTL_RESET, ALL, "UART after VRAM");

    //---- decode boundaries -------------------------------------------
    beat(32'hFFFD_FFFF, 32'h0, 4'b0000, 1'b1, R_RAM,
         32'hAAAA_FFFF, ALL, "just below VRAMBASE");
    beat(VRAMBASE, 32'h0, 4'b0000, 1'b1, R_VRAM,
         32'hBBBB_0000, ALL, "VRAMBASE");
    beat(32'hFFFE_FFFF, 32'h0, 4'b0000, 1'b1, R_VRAM,
         32'hBBBB_FFFF, ALL, "top of VRAM");
    beat(UARTBASE + OFF_ST, 32'h0, 4'b0000, 1'b1, R_UART,
         STATUS_RESET, ALL, "UARTBASE window");

    //---- csb polarity ------------------------------------------------
    // 0x00000200 is a RAM address whose low four bits alias OFF_TX. With csb
    // wired active-high this write would push a byte into the UART TX FIFO
    // and tx_buf_empty would drop. Effect test, not a register read-back.
    beat(32'h0000_0200, 32'h0000_0041, 4'b1111, 1'b0, R_RAM,
         32'hAAAA_0200, ALL, "RAM write aliasing OFF_TX");
    idle;
    beat(UARTBASE + OFF_ST, 32'h0, 4'b0000, 1'b1, R_UART,
         M_TX_EMPTY, M_TX_EMPTY, "UART untouched by RAM write");

    //---- writes reach only the addressed device ----------------------
    beat(VRAMBASE + 32'h100, 32'h1234_5678, 4'b1111, 1'b0, R_VRAM,
         32'hBBBB_0100, ALL, "write VRAM");
    beat(32'h0000_0204, 32'h0, 4'b0010, 1'b0, R_RAM,
         32'hAAAA_0204, ALL, "write RAM lane1");

    //---- UART write actually reaches the TX FIFO ---------------------
    // Four bytes, because one is popped into the shifter immediately. At
    // 27 MHz / 115200 a byte takes ~2340 cycles to leave, so the FIFO cannot
    // drain inside this window. Only tx_buf_empty is asserted on; the
    // pointer fields are timing-dependent and are not this bench's job.
    beat(UARTBASE + OFF_TX, 32'h0000_0041, 4'b1111, 1'b0, R_UART,
         32'h0, 32'h0, "push TX byte 0");
    beat(UARTBASE + OFF_TX, 32'h0000_0042, 4'b1111, 1'b0, R_UART,
         32'h0, 32'h0, "push TX byte 1");
    beat(UARTBASE + OFF_TX, 32'h0000_0043, 4'b1111, 1'b0, R_UART,
         32'h0, 32'h0, "push TX byte 2");
    beat(UARTBASE + OFF_TX, 32'h0000_0044, 4'b1111, 1'b0, R_UART,
         32'h0, 32'h0, "push TX byte 3");
    idle;
    beat(UARTBASE + OFF_ST, 32'h0, 4'b0000, 1'b1, R_UART,
         32'h0, M_TX_EMPTY, "TX not empty after pushes");
    beat(UARTBASE + OFF_ST, 32'h0, 4'b0000, 1'b1, R_UART,
         M_RX_EMPTY, M_RX_EMPTY, "RX still empty");

    //---- idle: strobes all drop --------------------------------------
    beat(32'h0000_0300, 32'h0, 4'b0000, 1'b0, R_RAM,
         32'hAAAA_0300, ALL, "idle RAM addr");

    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule

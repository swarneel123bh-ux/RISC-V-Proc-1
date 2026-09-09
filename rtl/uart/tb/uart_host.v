`timescale 1ns/1ps

// ============================================================================
// uart_host.v -- Claude-authored harness, NOT Swarneel's RTL. Simulation only.
//
// Stands in for the host terminal at the far end of the serial cable. A second
// uart_top, cross-wired to the DUT's serial pins, so the two talk over a real
// 8N1 line and the bit-level work is done by RTL rather than by C. VPI stays
// byte-granular.
//
//        dut_tx ---> host.ser_rx --> RX FIFO --> $uart_tx_write --> stdout
//        dut_rx <--- host.ser_tx <-- TX FIFO <-- $uart_rx_read  <-- stdin
//
// One instance serves both proc_tb.v and sim_tb.v so the console exists in
// exactly one place (HANDOFF s9: duplicated copies drift silently).
//
// WHAT THIS DOES NOT PROVE: both ends are the same uart_rx/uart_tx on the same
// clock, so a sampling or divisor bug cancels out and the link looks perfect
// regardless. The UART itself is proven by uart_top_tb and on hardware (s4).
// ============================================================================

module uart_host #(
  parameter CLK_FREQ    = 27_000_000,
  parameter SIM_DIV     = 4,      // clocks per bit; 4 = DIV_MIN floor (s6)
  parameter ESC_QUITS   = 1,      // 1: ESC raises `quit`. 0: ESC is just a byte
                                  //    (sim_tb lets gpu_vpi own termination)
  parameter DRAIN_BYTES = 40      // byte-times to keep draining after ESC, so
                                  // the last line of output is not lost
)(
  input  wire clk,
  input  wire rstb,
  input  wire dut_tx,             // DUT ser_tx  -> host ser_rx
  output wire dut_rx,             // host ser_tx -> DUT ser_rx
  output reg  quit                // pulses high once, after the post-ESC drain
);

  // Frozen in HANDOFF s6 (uart.mmio). Deliberately NOT `include top_params.vh:
  // that header has an include guard and uart_top.v is compiled first, so the
  // include would expand to nothing here -- and keeping a separate copy is the
  // independent witness s9 asks for. Checkable by text diff against s6.
  localparam [3:0] OFF_TX = 4'd0;
  localparam [3:0] OFF_RX = 4'd4;

  localparam integer BUFW     = 8;
  localparam integer SIM_BAUD = CLK_FREQ / SIM_DIV;

  reg  [3:0]  h_addr;
  reg         h_write;
  reg         h_read;
  reg  [31:0] h_wdata;
  wire [31:0] h_rdata;
  wire        h_tx_full, h_tx_empty, h_rx_full, h_rx_empty;

  uart_top #(
    .CLK_FREQ     (CLK_FREQ),
    .BAUD_RATE    (SIM_BAUD),
    .BUFFER_WIDTH (BUFW)
  ) host (
    .clk          (clk),
    .rstb         (rstb),
    .csb          (1'b0),        // permanently selected; nothing else on this bus
    .cpu_addr     (h_addr),
    .cpu_write    (h_write),
    .cpu_read     (h_read),
    .cpu_wdata    (h_wdata),
    .cpu_rdata    (h_rdata),
    .ser_rx       (dut_tx),
    .ser_tx       (dut_rx),
    .tx_buf_full  (h_tx_full),
    .tx_buf_empty (h_tx_empty),
    .rx_buf_full  (h_rx_full),
    .rx_buf_empty (h_rx_empty)
  );

  // The FIFO flags are wired straight out, so no STATUS read is needed -- only
  // the FIFO ports go through MMIO. Reads are assert-then-capture: cpu_read is
  // driven nonblocking, sampled on the next edge, and cpu_rdata updates on that
  // same edge, so the value is stable a delta later. The deassert keeps it to
  // one pop (defensive: the loop drains fast enough that two bytes rarely queue).
  task host_pop(output [7:0] b);
    begin
      @(posedge clk);
      h_read <= 1'b1;
      h_addr <= OFF_RX;
      @(posedge clk);
      h_read <= 1'b0;
      #1;
      b = h_rdata[7:0];
    end
  endtask

  task host_push(input [7:0] b);
    begin
      @(posedge clk);
      h_write <= 1'b1;
      h_addr  <= OFF_TX;
      h_wdata <= {24'h0, b};
      @(posedge clk);
      h_write <= 1'b0;
    end
  endtask

  // One process drives both directions, so nothing races on the bus regs.
  localparam integer POLL_CLKS  = 8 * SIM_DIV;             // ~one byte-time
  localparam integer DRAIN_CLKS = DRAIN_BYTES * 10 * SIM_DIV;
  localparam [7:0]   KEY_ESC    = 8'h1B;

  reg [7:0] rxb;
  integer   key;
  integer   pollctr;
  integer   draining;

  initial begin
    h_addr   = 4'd0;
    h_read   = 1'b0;
    h_write  = 1'b0;
    h_wdata  = 32'h0;
    quit     = 1'b0;
    pollctr  = 0;
    draining = 0;

    @(posedge rstb);
    $uart_init;

    forever begin
      if (!h_rx_empty) begin
        host_pop(rxb);
        $uart_tx_write(rxb);
      end

      if (draining > 0) begin
        draining = draining - 1;
        if (draining == 0) quit = 1'b1;
      end else if (!quit) begin
        pollctr = pollctr + 1;
        if (pollctr >= POLL_CLKS) begin
          pollctr = 0;
          key = $uart_rx_read();
          if (key >= 0) begin
            if (ESC_QUITS && key[7:0] == KEY_ESC) draining = DRAIN_CLKS;
            else if (!h_tx_full)                  host_push(key[7:0]);
          end
        end
      end

      @(posedge clk);
    end
  end

endmodule

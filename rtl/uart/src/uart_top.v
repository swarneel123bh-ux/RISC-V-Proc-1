`timescale 1ns/1ps


module uart_top #(
  parameter CLK_FREQ     = 27_000_000,
  parameter BAUD_RATE    = 115200,
  parameter BAUD_MIN     = 9600,
  parameter CW           = $clog2(CLK_FREQ/BAUD_MIN + 1),
  parameter BUFFER_WIDTH = 8,
  parameter DIV_MIN      = 4,
  parameter DIV_MAX      = CLK_FREQ/BAUD_MIN
)(
  input wire          clk,
  input wire         	rstb,     // Master resetb signal
  input wire         	csb,      // Chip select signal for decode


  // CPU side ports
  input wire [3:0]    cpu_addr,   // Only 4 bits used when csb is low, to distinguish registers
  input wire          cpu_write,  // Cpu wants to transmit a byte
  input wire          cpu_read,   // Cpu wants to read a byte if there
  input wire  [31:0]  cpu_wdata,  // Take 32-bit dat but discard upper 3 bytes
  output reg [31:0]   cpu_rdata,  // Pad to 32 bits (buffered internally) (syncrhonous reads)
  // output wire [31:0]  cpu_uart_ctrl, // Control register (unused for now)

  // Serial Side ports
  input wire          ser_rx,
  output wire         ser_tx,

  // Signal ports
  output wire         tx_buf_full,    // Sender must pause, or we overwrite
  output wire         tx_buf_empty,   // No remaining bytes to transmit
  output wire         rx_buf_full,    // Sender must stop sending, or we drop
  output wire         rx_buf_empty   	// No remaining bytes to read
);


  localparam PW = $clog2(BUFFER_WIDTH) + 1;   // pointer width incl. wrap bit
  `include "top_params.vh"


  // Async fifo for TX buffer
  reg [7:0] tx_fifo [0:BUFFER_WIDTH-1];
  reg [PW-1:0] tx_rptr, tx_wptr;
  reg [7:0] rx_fifo [0:BUFFER_WIDTH-1];
  reg [PW-1:0] rx_rptr, rx_wptr;

  // Status Byte 0 bitwise definition (fixed)
  // localparam ST_RX_BUF_EMPTY      = 0;  // [0]
  // localparam ST_RX_BUF_FULL       = 1;  // [1]
  // localparam ST_TX_BUF_EMPTY      = 2;  // [2]
  // localparam ST_TX_BUF_FULL       = 3;  // [3]
  // localparam ST_RX_FRM_ERROR      = 4;  // [4]
  // localparam ST_IRQ_ENABLE        = 5;  // [5]
  // localparam ST_RX_RESERVED       = 6;  // [6]
  // localparam ST_RX_OVERRUN        = 7;  // [7]

  // Variable fields depending on BUFFER_WIDTH (Must fix later)
  // ST_*_*PTR_LO => Index of *_*PTR's b0 inside STATUS register
  // ST_*_*PTR_HI => Index of *_*PTR's b($clog2(BUFFER_WIDTH)) inside STATUS register
  // localparam ST_RX_WPTR_LO    = 8;
  // localparam ST_RX_WPTR_HI    = 8 + PW - 1;
  // localparam ST_RX_RPTR_LO    = ST_RX_WPTR_HI + 1;
  // localparam ST_RX_RPTR_HI    = ST_RX_RPTR_LO + PW - 1;
  // localparam ST_TX_WPTR_LO    = ST_RX_RPTR_HI + 1;
  // localparam ST_TX_WPTR_HI    = ST_TX_WPTR_LO + PW - 1;
  // localparam ST_TX_RPTR_LO    = ST_TX_WPTR_HI + 1;
  // localparam ST_TX_RPTR_HI    = ST_TX_RPTR_LO + PW - 1;

  // Control register
  // localparam CTRL_CLR_RX_FRAME_ERR  = 0;          // W1C, read always 0
  // localparam CTRL_CLR_RX_OVERRUN    = 1;          // W1C
  // localparam CTRL_RESERVED1_LO      = 2;          // read and write 0 always
  // localparam CTRL_RESERVED1_HI      = 7;          // read and write 0 always
  // localparam CTRL_IRQ_ENABLE        = 8;          // R/W   (modifiable, STATUS reflects current value)
  // localparam CTRL_RESERVED2_LO      = 9;          // read and write 0 always
  // localparam CTRL_RESERVED2_HI      = 15;         // read and write 0 always
  // localparam CTRL_BAUD_DIV_LO       = 16;          // R/W
  // localparam CTRL_BAUD_DIV_HI       = 16 + CW - 1; // R/W

  // MMIO register decode
  // Chip decode needs to be done outside module,
  // module active when csb is low, meaning simple Addresses
  // decoder required outisde
  // localparam OFF_TX   = 4'd0;
  // localparam OFF_RX   = 4'd4;
  // localparam OFF_ST   = 4'd8;
  // localparam OFF_CTL  = 4'd12;
  wire sel = ~csb;
  wire wr  = sel & cpu_write;
  wire rd  = sel & cpu_read;

  // States
  // localparam STATE_IDLE                 = 3'd0;

  // TX States
  // localparam STATE_TX_DRAIN             = 3'd1;
  // localparam STATE_TX_DRAIN_WAITREADY   = 3'd2;
  // localparam STATE_TX_DRAIN_WAITVALID   = 3'd3;
  // localparam STATE_ERR_TXBUF_FULL       = 3'd4;
  reg [2:0] tx_state;

  // RX States
  // localparam STATE_RX_FILL              = 3'd1;
  // localparam STATE_ERR_RXBUF_FULL       = 3'd5;
  reg [2:0] rx_state;

  // Resigers
  // We need to elaborate status resigster further since we need to wire up
  // the sticky bits to it, so firmware can ack them
  reg rx_frame_error_sticky;
  reg rx_overrun_sticky;
  wire [31:0] status;
  reg [31:0] ctrl;

  // baud generator
  wire [CW-1:0] baud_div = ctrl[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO];
  // assign baud_div = ctrl[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO];

  // Status register
  assign status[ST_RX_BUF_EMPTY]              = rx_buf_empty;
  assign status[ST_RX_BUF_FULL]               = rx_buf_full;
  assign status[ST_TX_BUF_EMPTY]              = tx_buf_empty;
  assign status[ST_TX_BUF_FULL]               = tx_buf_full;
  assign status[ST_RX_FRM_ERROR]              = rx_frame_error_sticky;
  assign status[ST_IRQ_ENABLE]                = ctrl[CTRL_IRQ_ENABLE]; // Unused, Reserved
  assign status[ST_RX_RESERVED]               = 1'b0;//rx_frame_error_sticky;
  assign status[ST_RX_OVERRUN]                = rx_overrun_sticky;
  assign status[ST_RX_WPTR_HI:ST_RX_WPTR_LO]  = rx_wptr;
  assign status[ST_RX_RPTR_HI:ST_RX_RPTR_LO]  = rx_rptr;
  assign status[ST_TX_WPTR_HI:ST_TX_WPTR_LO]  = tx_wptr;
  assign status[ST_TX_RPTR_HI:ST_TX_RPTR_LO]  = tx_rptr;
  assign status[31:8 + 4*PW]                  = 0;


  // UART TX control
  reg tx_valid;
  wire tx_ready;
  reg [7:0] tx_send_byte;
  uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE),
    .BAUD_MIN(BAUD_MIN)
  ) tx (
    .clk(clk),
    .rstb(rstb),
    .data(tx_send_byte),
    .tx_valid(tx_valid),
    .tx_ready(tx_ready),
    .ser_tx_out(ser_tx),
    .clks_per_bit(baud_div)
  );

  // UART RX control
  wire rx_data_valid, rx_frame_error;
  wire [7:0] rx_rcv_byte;
  wire rx_busy;
  uart_rx #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE),
    .BAUD_MIN(BAUD_MIN)
  ) rx (
    .clk(clk),
    .rstb(rstb),
    .ser_rx(ser_rx),
    .data(rx_rcv_byte),
    .data_valid(rx_data_valid),
    .frame_error(rx_frame_error),
    .clks_per_bit(baud_div),
    .busy(rx_busy)
  );

  // Control
  always @(posedge clk or negedge rstb /*or posedge cpu_write or posedge cpu_read*/) begin
    if (!rstb) begin
      tx_rptr     <= 0;
      tx_wptr     <= 0;
      rx_rptr     <= 0;
      rx_wptr     <= 0;
      tx_valid    <= 0;
      cpu_rdata   <= 0;
      tx_state    <= STATE_IDLE;
      rx_state    <= STATE_IDLE;
      // baud_div    <= CLK_FREQ/BAUD_RATE;
      ctrl <= 0;
      ctrl[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO] <= CLK_FREQ / BAUD_RATE;
      ctrl[CTRL_BAUD_DIV_LO-1:0] <= 0;
      //$display("%d 0x%08h", CLK_FREQ/BAUD_RATE, ctrl);
      rx_frame_error_sticky <= 0;
      rx_overrun_sticky <= 0;
    end else begin


      // Write into fifos for writes and reads
      if (wr && cpu_addr == OFF_TX && !tx_buf_full) begin
        tx_fifo[tx_wptr[$clog2(BUFFER_WIDTH)-1:0]] <= cpu_wdata[7:0];
        tx_wptr <= tx_wptr + 1;

      end else if (rd && cpu_addr == OFF_RX && !rx_buf_empty) begin
        cpu_rdata <= {{24{1'b0}}, rx_fifo[rx_rptr[$clog2(BUFFER_WIDTH)-1:0]]};
        rx_rptr   <= rx_rptr + 1;

      end else if (rd && cpu_addr == OFF_ST) begin
        cpu_rdata <= status;

      end else if (wr && cpu_addr == OFF_CTL) begin

        if (tx_state == STATE_IDLE && tx_ready && !rx_busy) begin
          ctrl[CTRL_IRQ_ENABLE] <= cpu_wdata[CTRL_IRQ_ENABLE];
          if (cpu_wdata[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO] >= DIV_MIN &&
              cpu_wdata[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO] <= DIV_MAX)
            ctrl[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO] <= cpu_wdata[CTRL_BAUD_DIV_HI:CTRL_BAUD_DIV_LO];
        end

        if (cpu_wdata[CTRL_CLR_RX_FRAME_ERR]) rx_frame_error_sticky <= 1'b0;
        if (cpu_wdata[CTRL_CLR_RX_OVERRUN])   rx_overrun_sticky     <= 1'b0;

      end else if ( rd && cpu_addr == OFF_CTL) begin
        cpu_rdata <= ctrl;
      end

      case (rx_state)
        STATE_IDLE: begin
          if (!rx_buf_full) begin rx_state <= STATE_RX_FILL; end
          else begin
            rx_state <= STATE_ERR_RXBUF_FULL;
          end
        end

        STATE_RX_FILL: begin
          if (rx_buf_full) rx_state <= STATE_ERR_RXBUF_FULL;    // If buffer filled up last cycle
          else if (!rx_data_valid) rx_state <= STATE_RX_FILL;   // Else if data is not yet valid
          else if (rx_frame_error) rx_state <= STATE_RX_FILL;   // Else if data is erroneous (will never happen)
          else begin                                            // All good, write into fifo
            rx_fifo[rx_wptr[$clog2(BUFFER_WIDTH)-1:0]] <= rx_rcv_byte;
            rx_wptr <= rx_wptr + 1;
            if (!rx_buf_full) rx_state <= STATE_RX_FILL;  // Keep filling till full
            else rx_state <= STATE_ERR_RXBUF_FULL;        // Buffer full, error out
          end
        end

        STATE_ERR_RXBUF_FULL: begin
          if (rx_buf_full) begin
            rx_state <= STATE_ERR_RXBUF_FULL;
          end
          else rx_state <= STATE_IDLE;
        end

        default: begin
          rx_state <= STATE_IDLE;
        end

      endcase

      case (tx_state)
        STATE_IDLE: begin
          if (!tx_buf_empty) begin tx_state <= STATE_TX_DRAIN; end
          else begin tx_state <= STATE_IDLE; end
        end

        STATE_TX_DRAIN: begin
          tx_send_byte <= tx_fifo[tx_rptr[$clog2(BUFFER_WIDTH)-1:0]];
          tx_rptr <= tx_rptr + 1;
          if (!tx_ready) tx_state <= STATE_TX_DRAIN_WAITREADY;
          else begin
            tx_valid<= 1; tx_state <= STATE_TX_DRAIN_WAITVALID;
          end
        end

        STATE_TX_DRAIN_WAITREADY: begin
          if (!tx_ready) tx_state <= STATE_TX_DRAIN_WAITREADY;
          else begin
            tx_valid <= 1;
            tx_state <= STATE_TX_DRAIN_WAITVALID;
          end
        end

        STATE_TX_DRAIN_WAITVALID: begin
          tx_valid <= 0;
          if (tx_buf_empty) tx_state <= STATE_IDLE;
          else tx_state <= STATE_TX_DRAIN;
        end

        STATE_ERR_TXBUF_FULL: begin
          if (!tx_buf_full) tx_state <= STATE_IDLE;
          else tx_state <= STATE_ERR_TXBUF_FULL;
        end

        default: begin
          tx_state <= STATE_IDLE;
        end
      endcase

      if (rx_frame_error) rx_frame_error_sticky <= 1'b1;
      if (rx_data_valid && !rx_frame_error && rx_buf_full) rx_overrun_sticky <= 1'b1;

    end
  end

  // Check if fifos full for tx and rx sides
  // Combinational to avoid one cycle delay
  assign tx_buf_empty = (tx_wptr == tx_rptr);
  assign tx_buf_full  =
    ((tx_wptr[$clog2(BUFFER_WIDTH)-1:0] == tx_rptr[$clog2(BUFFER_WIDTH)-1:0])
  && (tx_wptr[$clog2(BUFFER_WIDTH)] !=     tx_rptr[$clog2(BUFFER_WIDTH)]));

  assign rx_buf_empty = (rx_wptr == rx_rptr);
  assign rx_buf_full  =
    ((rx_wptr[$clog2(BUFFER_WIDTH)-1:0] == rx_rptr[$clog2(BUFFER_WIDTH)-1:0])
  && (rx_wptr[$clog2(BUFFER_WIDTH)] !=     rx_rptr[$clog2(BUFFER_WIDTH)]));

endmodule

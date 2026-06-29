`timescale 1ns / 1ps

module uart (
  input             clk,
  input             rst,
  input      [31:0] addr,
  input      [31:0] wdata,
  input             we,
  input             re,
  input             cs,
  output reg [31:0] rdata,
  output reg        rx_ready
);
  localparam UART_TX     = 32'hFFFF0000;
  localparam UART_RX     = 32'hFFFF0004;
  localparam UART_STATUS = 32'hFFFF0008;

  reg [31:0] rx_buf;

  /* poll stdin every clock for incoming bytes */
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      rx_buf   <= 32'h0;
      rx_ready <= 1'b0;
    end else begin
      /* always poll — independent of cs */
      begin : rx_poll
        reg [31:0] rx_val;
        rx_val = $uart_rx_read();
        if (rx_val != 32'hFFFFFFFF) begin
          rx_buf   <= rx_val;
          rx_ready <= 1'b1;
        end else begin
          rx_ready <= 1'b0;
        end
      end
    end
  end

  /* TX and register reads */
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      rdata <= 32'h0;
    end else if (cs) begin
      if (we) begin
        case (addr)
          UART_TX: $write("%c", wdata[7:0]);
          default: $display("[UART] WARNING: write to unknown addr 0x%08X", addr);
        endcase
      end
      if (re) begin
        case (addr)
          UART_RX: begin
            rdata    <= rx_buf;
            rx_ready <= 1'b0;  /* clear after read */
          end
          UART_STATUS: rdata <= {30'b0, rx_ready, 1'b1};  /* bit1=rx_ready, bit0=tx_ready */
          default: begin
            $display("[UART] WARNING: read from unknown addr 0x%08X", addr);
            rdata <= 32'hDEADBEEF;
          end
        endcase
      end
    end
  end

endmodule

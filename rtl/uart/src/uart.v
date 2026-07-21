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
  /* RX state — single owner of rx_buf and rx_ready.
     - rx_ready asserts when a byte is latched, and HOLDS until the CPU
       reads UART_RX (which clears it).
     - The stdin poll is skipped while an unread byte is held, so a pending
       byte is never overwritten; surplus input simply waits in the OS
       buffer. On an UART_RX read we clear and immediately poll for the next
       byte, so no cycle is wasted.
     - If a read and a new byte land on the same cycle, the new byte wins
       (its assignment comes last), so nothing is dropped. */
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      rx_buf   <= 32'h0;
      rx_ready <= 1'b0;
    end else begin : rx_blk
      reg        do_read;
      reg [31:0] rx_val;
      do_read = cs && re && (addr == UART_RX);
      if (do_read)
        rx_ready <= 1'b0;
      if (do_read || !rx_ready) begin
        rx_val = $uart_rx_read();
        if (rx_val != 32'hFFFFFFFF) begin
          rx_buf   <= rx_val;
          rx_ready <= 1'b1;
          // $display("[uart] RX latched 0x%02x '%c'", rx_val[7:0], rx_val[7:0]);
        end
      end
    end
  end
  /* TX — clocked so $write fires once per store, not every cycle we is held. */
  always @(posedge clk) begin
    if (!rst && cs && we) begin
      case (addr)
	      UART_TX: begin
	      	$write("%c", wdata[7:0]);
	        $fflush;
	      end
        default: $display("[UART] WARNING: write to unknown addr 0x%08X", addr);
      endcase
    end
  end
  /* Register reads — combinational, so UART read latency matches the RAM
     path in data_mem (same-cycle). rdata is a reg only because it's driven
     from an always block; the logic is purely combinational. */
  always @(*) begin
    rdata = 32'h0;
    if (cs && re) begin
      case (addr)
        UART_RX:     rdata = rx_buf;
        UART_STATUS: rdata = {30'b0, rx_ready, 1'b1};  /* bit1=rx_ready, bit0=tx_ready */
        default:     rdata = 32'hDEADBEEF;
      endcase
    end
  end
endmodule

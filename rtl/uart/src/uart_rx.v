`timescale 1ns/1ps

module uart_rx #(
  parameter CLK_FREQ 	= 50_000_000,	// 50MHz
	parameter BAUD_MIN = 9600,
	parameter BAUD_RATE = 9600,				// Standard 9600 Baud
	parameter CW = $clog2(CLK_FREQ/BAUD_MIN + 1)
) (
  input  wire       clk,
  input  wire       rstb,
  input  wire       ser_rx,
  input [CW-1:0]    clks_per_bit,
  output reg  [7:0] data,
  output reg        data_valid,
  output reg        frame_error,
  output            busy
);

	// Reconfiguration params
	// localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;  	// 5208 at 50MHz / 9600 baud
  wire [CW-1:0] clks_mid_bit = clks_per_bit >> 1;       // 2604 ticks at 50MHz / 9600 baud
  // localparam integer CW = $clog2(CLKS_PER_BIT);

  // States
  localparam IDLE  = 2'b00;
  localparam START = 2'b01;
  localparam DATA  = 2'b10;
  localparam STOP  = 2'b11;

  // 2-FF synchronizer for async ser_rx input
  reg rx_ff0, rx_ff1;
  wire rx_s = rx_ff1;
  always @(posedge clk or negedge rstb) begin	// Synchronization logic
    if (!rstb) {rx_ff1, rx_ff0} <= 2'b11;
    else       {rx_ff1, rx_ff0} <= {rx_ff0, ser_rx};
  end

  // Tracking
  reg [1:0]  state;
  reg        start_bit_valid;
  reg [CW-1:0] tick_count;   // 16-bit covers down to 1200 baud at 50MHz
  reg [2:0]  bit_idx;
  reg [7:0]  shift_reg;

  always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
      state           <= IDLE;
      tick_count      <= 0;
      bit_idx         <= 0;
      shift_reg       <= 0;
      data            <= 0;
      data_valid      <= 0;
      frame_error     <= 0;
      start_bit_valid <= 0;
    end else begin
      data_valid  <= 0;  	// default 0, pulse for one cycle only
      frame_error <= 0;		// Only if stop bit faulty

      // State machine logic
      case (state)

        IDLE: begin
          tick_count      <= 0;
          bit_idx         <= 0;
          start_bit_valid <= 0;
          if (!rx_s)        // falling edge = start bit
            state <= START;
        end

        START: begin
          if (tick_count >= clks_per_bit - 1) begin
            tick_count      <= 0;
            start_bit_valid <= 0;
            state           <= start_bit_valid ? DATA : IDLE;
          end else begin
            tick_count <= tick_count + 1;
            if (tick_count == clks_mid_bit - 1)
              start_bit_valid <= !rx_s;  // still low at midpoint = valid start bit
          end
        end

        DATA: begin
          if (tick_count >= clks_per_bit - 1) begin
            tick_count <= 0;
            if (bit_idx == 7) begin
              bit_idx <= 0;
              state   <= STOP;
            end else begin
              bit_idx <= bit_idx + 1;
            end
          end else begin
            tick_count <= tick_count + 1;
            if (tick_count == clks_mid_bit - 1)
              shift_reg <= {rx_s, shift_reg[7:1]};  // LSB-first right shift
          end
        end

        STOP: begin
          if (tick_count >= clks_per_bit - 1) begin
            tick_count <= 0;
            state      <= IDLE;
          end else begin
            tick_count <= tick_count + 1;
            if (tick_count == clks_mid_bit - 1) begin
              if (rx_s) begin       // stop bit must be high, indicating frame completion
                data       <= shift_reg;
                data_valid <= 1;
              end else begin
                frame_error <= 1;  // framing error — line still low
              end
            end
          end
        end

      endcase
    end
  end

  assign busy = (state == IDLE) ? 1'b0 : 1'b1;

endmodule

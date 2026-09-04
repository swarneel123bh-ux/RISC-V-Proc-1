`timescale 1ns/1ps

module uart_tx #(
	parameter CLK_FREQ 	= 50_000_000,	// 50MHz
	parameter BAUD_MIN = 9600,
	parameter BAUD_RATE = 9600,				// Standard 9600 Baud
	parameter CW = $clog2(CLK_FREQ/BAUD_MIN + 1)
)(
	input wire clk,										// Master clk
	input wire rstb,									// Active low reset pin
	input wire [CW-1:0] clks_per_bit,
	input wire [7:0] data,						// Data input bus to uart tx module
	input wire tx_valid,							// Flag to signal data ready to send (must be high for 1 cycle to start)
	output reg tx_ready,							// Low=>module is transmitting, dont change data bus
	output reg ser_tx_out							// Serial output line
);
	// Number of clock ticks it takes to transmit 1 bit
	// localparam BAUD_MIN = 9600;
	// reg [CW-1:0] clks_per_bit;
	// parameter CLKS_PER_BIT_MAX = CLK_FREQ / BAUD_MIN;

	// States
	localparam IDLE		= 2'b00;
	localparam START	= 2'b01;
	localparam DATA		= 2'b10;
	localparam STOP		= 2'b11;
	//localparam integer CW = $clog2(CLKS_PER_BIT);

	reg [1:0] state;				// Track current state
	reg [CW-1:0] clk_count;		// Number of ticks passed for a bit
	// NOTE: 16 bit counter is too much because at 50MHz/9600 baud rates,
	// 13 bits are enough. But with a 16 bit counter we can bump up BAUD_RATE
	// to a min of 1200 (where each bit will last 41666 clkcycles) hence 16 bits will be required
	reg [2:0] bit_idx;			// Which bit of data is being sent (max = 7)
	reg [7:0] shift_reg;		// Shift register for sending bits

	always @(posedge clk or negedge rstb) begin
		if (!rstb) begin	// reset
			state 			  <= IDLE;
			// clks_per_bit  <= CLKS_PER_BIT_DEFAULT;
			clk_count 	  <= 0;
			bit_idx 		  <= 0;
			shift_reg 	  <= 0;
			tx_ready 		  <= 1;
			ser_tx_out 	  <= 1;	// UART idle is tx_out_high
		end
		else begin				// State machine
			case (state)

				IDLE: begin
					// Partial Reset
					ser_tx_out 	<= 1;
					tx_ready 		<= 1;
					clk_count 	<= 0;
					bit_idx 		<= 0;

					if (tx_valid) begin	// Data is valid, set up next state
						shift_reg <= data;
						tx_ready 	<= 0;
						state 		<= START;
					end
				end

				START: begin
					ser_tx_out 	<= 0;	// Start bit
					if (clk_count >= clks_per_bit - 1) begin	// Start bit fully sent
						// Set up next state
						clk_count <= 0;
						state 		<= DATA;
					end else begin
						clk_count <= clk_count + 1;				// Wait till start bit is sent
					end
				end

				DATA: begin
					ser_tx_out <= shift_reg[0];	// Get LSB
					if (clk_count >= clks_per_bit - 1) begin	// LSB fully sent
						clk_count <= 0;										// Reset count for next bit
						shift_reg <= shift_reg >> 1;			// Right shift to get next bit into LSB
						bit_idx <= bit_idx + 1;						// Increment bit index counter
						if (bit_idx == 3'b111) begin		// All bits send
							bit_idx <= 0;										// Reset bit index
							state <= STOP;									// Change state to next
						end
					end else begin
						clk_count <= clk_count + 1;				// Wait till bit sent
					end
				end

				STOP: begin
					ser_tx_out <= 1;	// UART Stop bit is 1
					if (clk_count >= clks_per_bit - 1) begin	// Bit fully sent
						// Transition to IDLE again
						clk_count <= 0;
						tx_ready <= 1;
						state <= IDLE;
					end else begin
						clk_count <= clk_count + 1;				// Wait till bit sent
					end
				end

			endcase
		end
	end

endmodule

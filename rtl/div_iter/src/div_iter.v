`timescale 1ns / 1ps

module div_iter #(
	parameter WIDTH = 32
)(
	input  wire                 clk,
  input  wire                 rstb,
  input  wire                 start,
  input  wire [WIDTH-1:0]     dividend,
  input  wire [WIDTH-1:0]     divisor,
  output reg  [WIDTH-1:0]     quotient,
  output reg  [WIDTH-1:0]     remainder,
  output reg                  ready,
  output reg                  dbz          // Divide by zero flag
);

	// States
	localparam STATE_IDLE 		= 2'b00;
	localparam STATE_START		= 2'b01;
	localparam STATE_WORKING	= 2'b10;
	localparam STATE_DONE 		= 2'b11;
	reg [1:0] state;

	reg [WIDTH:0] 	A;									// Accumulator, Extra bit for sign/carry
	reg [WIDTH-1:0] Q;									// Quotient
	reg [WIDTH-1:0] M;									// Remainder
	reg [$clog2(WIDTH):0] iterations;

	reg [WIDTH-1:0] A_lshifted;
	reg [WIDTH-1:0] Q_lshifted;
	reg [WIDTH:0] 	A_minus_M;

	always @(*) begin
		A_lshifted = {A[WIDTH-1:0], Q[WIDTH-1]};
		Q_lshifted = {Q[WIDTH-2:0], 1'b0};
		A_minus_M = A_lshifted - {1'b0, M};
	end

	always @(posedge clk or negedge rstb) begin
		if (!rstb) begin
			state     	<= STATE_IDLE;
      quotient  	<= 0;
      remainder 	<= 0;
      ready     	<= 1'b1;
      dbz       	<= 1'b0;
      A         	<= 0;
      Q         	<= 0;
      M         	<= 0;
      iterations  <= 0;
		end else begin

			case (state)

				STATE_IDLE: begin
					ready <= 1'b1;
					if (start) begin
						ready <= 1'b0;
						if (divisor == 0) begin
							dbz <= 0;
							Q <= {WIDTH{1'b1}};	// Overflow handling, set all bits of quotient to 1
							remainder <= dividend;
							state <= STATE_DONE;
						end else begin
							iterations <= WIDTH;
							state <= STATE_WORKING;
							A <= 0;
							Q <= dividend;
							M <= divisor;
						end
					end
				end

				STATE_WORKING: begin
					if (iterations == 0) state <= STATE_DONE;
					else begin
						iterations <= iterations - 1;
						if (A_minus_M[WIDTH]) begin	// If MSB is set, restore A, set Q_lsb=0
							A <= A_lshifted;
							Q <= {Q_lshifted[WIDTH-1:1], 1'b0};
						end else begin	// MSB not set, keep subtraction result and set Q_lsb=1
							A <= A_minus_M;
							Q <= {Q_lshifted[WIDTH-1:1], 1'b1};
						end
					end
				end

				STATE_DONE: begin
					quotient <= Q;
					remainder <= A[WIDTH-1:0];
					ready <= 1'b1;
					state <= STATE_IDLE;
				end

				default: state <= STATE_IDLE;

			endcase

		end
	end

endmodule

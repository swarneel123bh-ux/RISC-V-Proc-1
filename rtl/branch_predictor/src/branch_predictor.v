`timescale 1ns / 1ps

module branch_predictor #(
	parameter IDX_BITS = 6
)(
	input wire clk,
	input wire rstb,
	// Prediction port, connects to IF
	input wire [31:0] pc,
	output wire predict_taken,
	output wire [31:0] predict_target,
	// Updation port, connects to EX
	input wire update,
	input wire [31:0] new_pc,
	input wire update_taken,
	input wire [31:0] update_target
);

	// Prediction Table (Lee and A.Smith, 1984)
	// 00	-> Strongly Not Taken
	// 01	-> Weakly Not taken
	// 10	-> Weakly Taken
	// 11	-> Strongly Taken
	//
	// State Machine :-
	// Current State		Branch Result			Next State
	// 00								NT								00
	// 00								T									01
	//
	// 01								NT								00
	// 01								T									11
	//
	// 10								NT								00
	// 10								T									11
	//
	// 11								NT								10
	// 11								T									11

	wire [IDX_BITS-1:0] idx = pc[IDX_BITS+1:2];
	wire [29-IDX_BITS:0] tag = pc[31:IDX_BITS+2];

	reg [1:0] bht[0 : (1 << IDX_BITS) - 1];					// Branch History Table, 2 bits per entry
	reg btb_valid[0 : (1 << IDX_BITS) - 1];					// Valid Bit per entry
	reg [31:0] btb_pc[0 : (1 << IDX_BITS) - 1];			// Branch Target Buffer's PC column, 32 bits
	reg [29-IDX_BITS:0] btb_tag[0 : (1 << IDX_BITS) - 1];		// Branch Target Buffer's Tag Column, 24 bits per entry

	wire btb_hit = btb_valid[idx] && (btb_tag[idx] == tag);
	assign predict_taken = btb_hit & bht[idx][1];		// Prediction is the MSB of the 2-bit prediction
	assign predict_target = btb_pc[idx];

	wire [IDX_BITS-1:0] update_idx = 	new_pc[IDX_BITS+1:2];
	wire [29-IDX_BITS:0] update_tag = new_pc[31:IDX_BITS+2];

	// FSM
	integer i;
	always @(posedge clk or negedge rstb) begin
		if (!rstb) begin	// Reset, clear bht, btb_valid
			for (i = 0; i < (1 << IDX_BITS); i = i + 1) begin
				bht[i] <= 2'b00;
				btb_valid[i] <= 1'b0;
			end
		end else begin
			if (update) begin
				// Counter State Machine
				// Lee and A.Smith 1984
				// case (bht[update_idx])
				// 	2'b00: bht[update_idx] <= (update_taken) ? 2'b01 : 2'b00;	// SNT -> WNT : SNT -> STN
				// 	2'b01: bht[update_idx] <= (update_taken) ? 2'b11 : 2'b00;	// WNT -> ST  : WNT -> SNT
				// 	2'b10: bht[update_idx] <= (update_taken) ? 2'b11 : 2'b00;	// WT  -> ST 	: WT  -> SNT
				// 	2'b11: bht[update_idx] <= (update_taken) ? 2'b11 : 2'b10;	// ST  -> ST  : ST  -> WT
				// endcase

				// Counter State Machine
				// J.Smith Saturating Counter 1981
				case (bht[update_idx])
					2'b00: bht[update_idx] <= (update_taken) ? 2'b01 : 2'b00;
					2'b01: bht[update_idx] <= (update_taken) ? 2'b10 : 2'b00;
					2'b10: bht[update_idx] <= (update_taken) ? 2'b11 : 2'b01;
					2'b11: bht[update_idx] <= (update_taken) ? 2'b11 : 2'b10;
				endcase

				// BTB Modification If Taken
				if (update_taken) begin
					btb_valid[update_idx] <= 1'b1;
					btb_pc[update_idx] <= update_target;
					btb_tag[update_idx] <= update_tag;
				end
			end
		end
	end

endmodule

`timescale 1ns / 1ps
module immdataext (
	input [31:0] ifid_instr,
	output [31:0] immdata
);

	// I-type
	wire [31:0] imm_i = {{20{ifid_instr[31]}}, ifid_instr[31:20]};

	// S-type
	wire [31:0] imm_s = {{20{ifid_instr[31]}}, ifid_instr[31:25], ifid_instr[11:7]};

	// U-type
	wire [31:0] imm_u = {ifid_instr[31:12], 12'b0};

	// B-type (note the scramble + implicit 0)
	wire [31:0] imm_b = {
		{19{ifid_instr[31]}},
		ifid_instr[31],
		ifid_instr[7],
		ifid_instr[30:25],
		ifid_instr[11:8], 1'b0
	};

	// J-type
	wire [31:0] imm_j = {
		{11{ifid_instr[31]}},
		ifid_instr[31],
		ifid_instr[19:12],
		ifid_instr[20],
		ifid_instr[30:21],
		1'b0
	};


reg [31:0] id_imm;
always @(*) case (ifid_instr[6:0])
  7'b0010011, 7'b0000011, 7'b1100111: id_imm = imm_i; // OP-IMM, LOAD, JALR
  7'b0100011:                         id_imm = imm_s; // STORE
  7'b1100011:                         id_imm = imm_b; // BRANCH
  7'b0110111, 7'b0010111:             id_imm = imm_u; // LUI, AUIPC
  7'b1101111:                         id_imm = imm_j; // JAL
  default:                            id_imm = 32'b0;
endcase

assign immdata = id_imm;

endmodule

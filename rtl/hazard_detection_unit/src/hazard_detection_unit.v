`timescale 1ns / 1ps

module hazard_detection_unit (
  input      [4:0] id_rs1,        // sources of the instruction in ID
  input      [4:0] id_rs2,
  input      [4:0] idex_rd,       // dest of the instruction in EX
  input            idex_mem_read, // is that EX instruction a load?
  input						 uses_rs1,
  input						 uses_rs2,
  output reg       stall
);

	always @(*) begin
		stall =
		idex_mem_read && (idex_rd != 0) &&
		(((uses_rs1) && (idex_rd == id_rs1)) || ((uses_rs2) && (idex_rd == id_rs2)));
	end

endmodule

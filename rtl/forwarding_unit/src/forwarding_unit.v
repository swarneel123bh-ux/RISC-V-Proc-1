`timescale 1ns / 1ps

module forwarding_unit (
  input      [4:0] idex_rs1,
  input      [4:0] idex_rs2,
  input      [4:0] exmem_rd,
  input            exmem_reg_write,
  input      [4:0] memwb_rd,
  input            memwb_reg_write,
  output reg [1:0] forward_a,   // select for ALU operand A (rs1)
  output reg [1:0] forward_b    // select for ALU operand B (rs2)
);

	localparam FROM_MEMWB = 2'b01;
	localparam FROM_EXMEM = 2'b10;
	localparam FROM_REGFILE = 2'b00;

	always @(*) begin

		if ((exmem_reg_write) && (exmem_rd != 0) && (exmem_rd == idex_rs1)) begin
			forward_a = FROM_EXMEM;
		end else if ((memwb_reg_write) && (memwb_rd != 0) && (memwb_rd == idex_rs1)) begin
			forward_a = FROM_MEMWB;
		end else begin
			forward_a = FROM_REGFILE;
		end


		if ((exmem_reg_write) && (exmem_rd != 0) && (exmem_rd == idex_rs2)) begin
			forward_b = FROM_EXMEM;
		end else if ((memwb_reg_write) && (memwb_rd != 0) && (memwb_rd == idex_rs2)) begin
			forward_b = FROM_MEMWB;
		end else begin
			forward_b = FROM_REGFILE;
		end

	end

endmodule

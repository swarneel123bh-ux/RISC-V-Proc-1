`timescale 1ns / 1ps

module branch_unit (
  input      [2:0]  funct3,
  input      [31:0] rdata1,
  input      [31:0] rdata2,
  output reg        take        // 1 = branch condition met
);

	always @(*) begin
		take = 0;
		case (funct3)
			3'b000: take = (rdata1 == rdata2);										// BEQ
			3'b001: take = (rdata1 != rdata2);										// BNE
			3'b100: take = ($signed(rdata1) < $signed(rdata2));		// BLT
			3'b101: take = ($signed(rdata1) >= $signed(rdata2));  // BGE
			3'b110: take = (rdata1 < rdata2);											// BLTU
			3'b111:	take = (rdata1 >= rdata2);										// BGEU
			endcase
	end

endmodule

`timescale 1ns / 1ps
module mem_wrapper (
  input      [2:0]  funct3,      // size + signedness (from the instruction)
  input      [1:0]  addr_lo,     // addr[1:0] — byte offset within the word
  input      [31:0] store_data,  // rs2 value to store (right-justified)
  input      [31:0] load_word,   // raw 32-bit word from data_mem
  input             mem_write,   // is this a store?
  output reg [3:0]  wstrb,       // byte-write enables -> data_mem
  output reg [31:0] store_out,   // byte-shifted store data -> data_mem wdata
  output reg [31:0] load_out     // extracted + extended load result -> WB
);

	reg [7:0] tempbyte;
	reg [15:0] temphalf;

	always @(*) begin

		if (!mem_write) begin	// LOAD OPERATIONS
			store_out = 32'h0;
			wstrb = 4'b0000;

			case (funct3)
				3'b000: begin	// Load Byte
					tempbyte = load_word[8*addr_lo +: 8];
					load_out = {{24{tempbyte[7]}}, tempbyte};
				end
				3'b001: begin 	// Load Half
					temphalf = addr_lo[1] ? load_word[31:16] : load_word[15:0];
					load_out = {{16{temphalf[15]}}, temphalf};
				end
				3'b010: begin 	// Load word
					load_out = load_word;
				end
				3'b100: begin 	// Load Unsigned Byte
					tempbyte = load_word[8*addr_lo +: 8];
					load_out = {24'b0, tempbyte};
				end
				3'b101: begin 	// Load Unsigned halg
					temphalf = addr_lo[1] ? load_word[31:16] : load_word[15:0];
					load_out = {16'b0, temphalf};
				end
				default: begin 	// Other
					load_out = 32'h0;
				end
			endcase

		end else begin	// STORE OPERATIONS
			load_out = 32'h0;

			case (funct3)
				3'b000: begin	// Store Byte
					store_out = store_data[7:0] << 8*addr_lo;
					wstrb = 4'b0001 << addr_lo;
				end
				3'b001: begin 	// Store Half
					store_out = store_data[15:0] << (8*addr_lo);
					wstrb = (addr_lo[1]) ? 4'b1100 : 4'b0011;
				end
				3'b010: begin 	// Store word
					store_out = store_data;
					wstrb = 4'b1111;
				end
				default: begin 	// Other
					store_out = 32'h0;
					wstrb = 4'b0000;
				end
			endcase
		end
	end


endmodule

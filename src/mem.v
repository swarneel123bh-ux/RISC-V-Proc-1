`timescale 1ns / 1ps

module mem(
  input clk, 
  input rstb,
  input wen, 
  input ren,
  input [31:0] addr,
  input [31:0] wdata,
  output reg [31:0] rdata
);

  localparam MEMWORDS     = 16384;
  reg [31:0] mem [0:MEMWORDS-1];

  initial begin 
    $readmemh("rom/program.hex", mem);
  end

  always @(posedge clk or negedge rstb) begin
    if (!rstb) begin
      rdata <= 32'h0;
    end

    else begin
      if (addr[31:16] <= 14'h00003FFF) begin // Valid r/w RAM address
        case ({wen, ren})
          2'b00: rdata <= 32'h0;
          2'b01: rdata <= mem[addr[31:2]];
          2'b10: mem[addr[31:2]] <= wdata;
          2'b11: begin
            mem[addr[31:2]] <= wdata;
            rdata <= mem[addr[31:2]];
          end
        endcase
      end else begin
        $display("Unmapped region access at 0x%08hx", addr);
        case ({wen, ren})
          2'b00: rdata <= 32'hDEADBEEF;
          2'b01: rdata <= 32'hDEADBEEF;
          2'b10: rdata <= 32'hDEADBEEF;
          2'b11: rdata <= 32'hDEADBEEF;
        endcase
      end
    end
  end

endmodule

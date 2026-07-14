`timescale 1ns / 1ps

module proc(
	input wire rstb	// Active low reset
);

	// Master clock
	reg clk;
  always begin #5; clk = ~clk; end

  // Program Counter
  wire [31:0] pcIn;
  wire [31:0] pcOut;
  wire [31:0] pcAdd4Out;
  mux2x1_32 pcInMux(
  	.in1(pcAdd4Out),
   	.in2(pcAdd4Out), 				// Need to change to ID/EX register
    .sel(1'b0), 						// Need to change to CU signal
    .out(pcIn)
  );
  program_counter pc(
  	.rstb(rstb),
   	.clk(clk),
   	.in(pcIn),
   	.out(pcOut)
  );
  add4 pcAdd4(
  .in(pcOut),
  .out(pcAdd4Out)
  );

  // Instruction memory
  wire [31:0] instructionMemInstr;
  instruction_mem #(.SYNC(0)) instructionMem(
  	.clk(clk),
   	.addr(pcOut),
    .instr(instructionMemInstr)
  );

  // Reset
  always @(negedge rstb) begin
  	if (!rstb) begin
   		clk <= 0;
   	end
  end

endmodule

`timescale 1ns / 1ps

module proc(
	input wire rstb	// Active low reset
);

	// Master clock
	reg clk;
  always begin #5; clk = ~clk; end

  // instruction fetch stage stuff
  wire [31:0] pcin;
  wire [31:0] pcout;
  wire [31:0] pcadd4out;
  mux2x1_32 pcinmux(
  	.in1(pcadd4out),
   	.in2(pcadd4out), 				// need to change to id/ex register
    .sel(1'b0), 						// need to change to cu signal
    .out(pcin)
  );

  program_counter pc(
  	.rstb(rstb),
   	.clk(clk),
   	.in(pcin),
   	.out(pcout)
  );

  add4 pcadd4(
  .in(pcout),
  .out(pcadd4out)
  );

  wire [31:0] instructionmeminstr;
  instruction_mem #(.SYNC(0)) instructionmem(
  	.clk(clk),
   	.addr(pcout),
    .instr(instructionmeminstr)
  );

  // if/id pipeline register
  reg [31:0] ifid_pc;
  reg [31:0] ifid_instr;

  // instruction decode stage stuff
  // wiring out the signals to regsiter file so its easier to instantiate module
  // opcode (7 bit): partially specifies which of the 6 types of instruction formats
  // funct7 + funct3 (10 bit): combined with opcode, these two fields describe what operation to perform
  // rs1 (5 bit): specifies register containing first operand
  // rs2 (5 bit): specifies second register operand
  // rd (5 bit):: destination register specifies register which will receive result of computation
  // These fields are replaced as imediate values when the opcode requires it to be
  wire [6:0] id_opcode = ifid_instr[6:0];
  wire [4:0] id_rd = ifid_instr[11:7];
  wire [2:0] id_funct3 = ifid_instr[14:12];
  wire [4:0] id_rs1 = ifid_instr[19:15];
  wire [4:0] id_rs2 = ifid_instr[24:20];
  wire [6:0] id_funct7 = ifid_instr[31:25];

  // immediate + control decode also live here (combinational)
  wire [31:0] registerfilerdata1;
  wire [31:0] registerfilerdata2;
  regfile registerfile(
  	.clk(clk),
   	.rstb(rstb),
    .wen(1'b0),	// hardwiring to 0 for now, meaning no writes will happen, but this signal needs to be controlled
    .raddr1(id_rs1),
    .raddr2(id_rs2),
    .rdata1(registerfilerdata1),
    .rdata2(registerfilerdata2),
    .waddr(id_rd),
    .wdata(32'h0)	// Hardwiring to 0 now, need to change later
  );

  // ID/EX PIPELINE REGISTER
  wire [31:0] idex_rdata1 = registerfilerdata1;
  wire [31:0] idex_rdata2 = registerfilerdata2;
  wire [31:0]	idex_immdata;
  immdataext immdataextractor(
  	.ifid_instr(ifid_instr),
   	.immdata(idex_immdata)
  );
  // reset
  always @(posedge clk or negedge rstb) begin
  	if (!rstb) begin
   		clk <= 0;
     	ifid_instr 	<= 0;
     	ifid_pc 		<= 0;
   	end else begin
    	ifid_pc <= pcout;
     	ifid_instr <= instructionmeminstr;
    end
  end

endmodule

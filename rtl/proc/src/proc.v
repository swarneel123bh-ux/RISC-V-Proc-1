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
  wire [4:0] id_rs1 = ifid_instr[19:15];
  wire [4:0] id_rs2 = ifid_instr[24:20];
  wire [6:0] id_funct7 = ifid_instr[31:25];
  wire [2:0] id_funct3 = ifid_instr[14:12];
  wire [31:0]	id_immdata;
  immdataext immdataextractor(
  	.ifid_instr(ifid_instr),
   	.immdata(id_immdata)
  );

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

  // Control Unit stuff
 	wire cu_reg_write;
 	wire [1:0] cu_alu_src_a;
 	wire cu_alu_src_b;
 	wire [1:0] cu_alu_op;
 	wire cu_mem_read;
 	wire cu_mem_write;
 	wire [1:0] cu_wb_sel;
 	wire cu_branch;
 	wire cu_jump;
 	wire cu_jalr;
  cu controlUnit(
  	.opcode(id_opcode),
  	.reg_write(cu_reg_write),
  	.alu_src_a(cu_alu_src_a),
  	.alu_src_b(cu_alu_src_b),
  	.alu_op(cu_alu_op),
  	.mem_read(cu_mem_read),
  	.mem_write(cu_mem_write),
  	.wb_sel(cu_wb_sel),
  	.branch(cu_branch),
  	.jump(cu_jump),
  	.jalr(cu_jalr)
  );

  // ID/EX PIPELINE REGISTER
  reg [31:0] idex_pc;
  reg [31:0] idex_rdata1;
  reg [31:0] idex_rdata2;
  reg [31:0] idex_immdata;
  reg [4:0] idex_rs1;
  reg [4:0] idex_rs2;
  reg [4:0] idex_rd;
  reg [2:0] idex_funct3;
  reg [6:0] idex_funct7;
 	reg idex_cu_reg_write;
 	reg [1:0] idex_cu_alu_src_a;
 	reg idex_cu_alu_src_b;
 	reg [1:0] idex_cu_alu_op;
 	reg idex_cu_mem_read;
 	reg idex_cu_mem_write;
 	reg [1:0] idex_cu_wb_sel;
 	reg idex_cu_branch;
 	reg idex_cu_jump;
 	reg idex_cu_jalr;

  // reset
  always @(posedge clk or negedge rstb) begin
  	if (!rstb) begin
   		clk <= 0;
     	ifid_instr 	<= 0;
     	ifid_pc 		<= 0;

      idex_pc <= 0;
      idex_rdata1 <= 0;
      idex_rdata2 <= 0;
      idex_immdata <= 0;
      idex_rs1 <= 0;
      idex_rs2 <= 0;
      idex_rd <= 0;
      idex_funct3 <= 0;
      idex_funct7 <= 0;

     	idex_cu_reg_write <= 0;
     	idex_cu_alu_src_a <= 0;
     	idex_cu_alu_src_b <= 0;
     	idex_cu_alu_op <= 0;
     	idex_cu_mem_read <= 0;
     	idex_cu_mem_write <= 0;
     	idex_cu_wb_sel <= 0;
     	idex_cu_branch <= 0;
     	idex_cu_jump <= 0;
     	idex_cu_jalr <= 0;

   	end else begin
    	ifid_pc <= pcout;
     	ifid_instr <= instructionmeminstr;

      idex_pc <= ifid_pc;
      idex_rdata1 <= registerfilerdata1;
      idex_rdata2 <= registerfilerdata2;
      idex_immdata <= id_immdata;
      idex_rs1 <= id_rs1;
      idex_rs2 <= id_rs2;
      idex_rd <= id_rd;
      idex_funct3 <= id_funct3;
      idex_funct7 <= id_funct7;

     	idex_cu_reg_write <= cu_reg_write;
     	idex_cu_alu_src_a <= cu_alu_src_a;
     	idex_cu_alu_src_b <= cu_alu_src_b;
     	idex_cu_alu_op <= cu_alu_op;
     	idex_cu_mem_read <= cu_mem_read;
     	idex_cu_mem_write <= cu_mem_write;
     	idex_cu_wb_sel <= cu_wb_sel;
     	idex_cu_branch <= cu_branch;
     	idex_cu_jump <= cu_jump;
     	idex_cu_jalr <= cu_jalr;
    end
  end

endmodule

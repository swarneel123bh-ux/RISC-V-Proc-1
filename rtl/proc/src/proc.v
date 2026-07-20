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
  wire [31:0] pcBranchTarget;
  wire pcInMuxSel;
  mux2x1_32 pcinmux(
  	.in1(pcadd4out),
   	.in2(pcBranchTarget),
    .sel(pcInMuxSel),
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
  reg [31:0] ifid_pcPlus4;
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

  reg [31:0] wb_mux;			// Writing here since we need the loopback
  reg memwb_cu_reg_write;	// Same
  reg [4:0] memwb_rd;			// Same
  regfile registerfile(
  	.clk(clk),
   	.rstb(rstb),
    .wen(memwb_cu_reg_write),
    .raddr1(id_rs1),
    .raddr2(id_rs2),
    .rdata1(registerfilerdata1),
    .rdata2(registerfilerdata2),
    .waddr(memwb_rd),
    .wdata(wb_mux)
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
  reg [31:0] idex_pcPlus4;
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

  // EX Stage stuff
  wire [3:0] aluctrl_out;
  alu_control aluctrl(
  	.aluOp(idex_cu_alu_op),
  	.funct3(idex_funct3),
  	.funct7(idex_funct7),
  	.alu_control_out(aluctrl_out)
  );
  reg [31:0] alusrca;	// MUX to determine alu_src_a;
  always @(*) begin
  	alusrca = 32'h0;
 		case (idex_cu_alu_src_a)
   		2'b00: alusrca = idex_rdata1;
     	2'b01: alusrca = idex_pc;
      2'b10: alusrca = 32'h0;
   	endcase
  end
  wire [31:0] aluout;
  wire aluzero;
  alu alu_(
  	.aluop_ctrl(aluctrl_out),
  	.alu_a(alusrca),
  	.alu_b((idex_cu_alu_src_b) ? idex_immdata : idex_rdata2),
  	.alu_out(aluout),
  	.alu_zero(aluzero)
  );
  wire branchUnit_take;
  branch_unit branchUnit(
 		.funct3(idex_funct3),
  	.rdata1(idex_rdata1),
  	.rdata2(idex_rdata2),
  	.take(branchUnit_take)
  );
  wire [31:0] branchDestination = (idex_pc + idex_immdata);							// Branches and JAL
  wire [31:0] jalrDestination = (idex_rdata1 + idex_immdata) & ~32'b1;	// Only for JALR (last bit needs reset)
  assign pcInMuxSel = (idex_cu_branch & branchUnit_take) | idex_cu_jump | idex_cu_jalr;
  assign pcBranchTarget = idex_cu_jalr ? jalrDestination : branchDestination;

  // EX/MEM Pipeline register
  reg [31:0] exmem_pcPlus4;
 	reg exmem_cu_reg_write;
 	reg exmem_cu_mem_read;
 	reg exmem_cu_mem_write;
 	reg [1:0] exmem_cu_wb_sel;
 	reg exmem_cu_branch;
 	reg exmem_cu_jump;
 	reg exmem_cu_jalr;
  reg [31:0] exmem_alu_out;
  reg [4:0] exmem_rd;
  reg [31:0] exmem_rdata2;

  // MEM Stage Stuff
  wire [31:0] dataMem_rdata;
  wire [3:0] dataMem_wstrb = exmem_cu_mem_write ? 4'b1111 : 4'b0000;
  data_mem dataMem(
  	.clk(clk),
  	.rstb(rstb),
  	.addr(exmem_alu_out),        	// byte address
  	.wdata(exmem_rdata2),       	// write data (right-justified)
  	.wstrb(dataMem_wstrb),       	// byte-write enables: bit i set means wdata word's byte i written
  	.mem_read(exmem_cu_mem_read), // read enable
  	.rdata(dataMem_rdata)        	// raw 32-bit word at addr (aligned)
  );

  // MEM/WB Pipeline Register
  reg [31:0] memwb_pcPlus4;
  reg [1:0] memwb_cu_wb_sel;
  reg [31:0] memwb_alu_out;
  reg [31:0] memwb_dataMem_rdata;
  // reg [4:0] memwb_rd;
  // reg memwb_cu_reg_write;

  // WB Stage Stuff
  always @(*) begin
  	wb_mux = memwb_alu_out;
 		case (memwb_cu_wb_sel)
   		2'b00: wb_mux = memwb_alu_out;				// ALU Result
     	2'b01: wb_mux = memwb_dataMem_rdata;	// Data Memory Read Result
      2'b10: wb_mux = memwb_pcPlus4;				// PC+4 for JAL/JALR
  	endcase
  end


  // reset
  always @(posedge clk or negedge rstb) begin
  	if (!rstb) begin
   		clk <= 0;

     	ifid_instr 	<= 0;
     	ifid_pc 		<= 0;
     	ifid_pcPlus4 <= 0;

      idex_pc <= 0;
      idex_pcPlus4 <= 0;
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

      exmem_pcPlus4 <= 0;
      exmem_cu_reg_write <= 0;
      exmem_cu_mem_read <= 0;
      exmem_cu_mem_write <= 0;
      exmem_cu_wb_sel <= 0;
      exmem_cu_branch <= 0;
      exmem_cu_jump <= 0;
      exmem_cu_jalr <= 0;
      exmem_alu_out <= 0;
      exmem_rd <= 0;
      exmem_rdata2 <= 0;

      memwb_pcPlus4 <= 0;
      memwb_cu_reg_write <= 0;
      memwb_cu_wb_sel <= 0;
      memwb_alu_out <= 0;
      memwb_dataMem_rdata <= 0;
      memwb_rd <= 0;

   	end else begin
    	if (pcInMuxSel) begin	// PC will change to 1 now, need to flush last pipeline (two nops => need to flush IF and ID)
    		ifid_pc 			<= 0;
     		ifid_pcPlus4 	<= 0;
     		ifid_instr 		<= 32'h00000013;	// Decodes to NOP, better than just 0;

       	idex_pc 					<= 0;
       	idex_pcPlus4 			<= 0;
       	idex_rdata1 			<= 0;
       	idex_rdata2 			<= 0;
       	idex_immdata 			<= 0;
       	idex_rs1 					<= 0;
       	idex_rs2 					<= 0;
       	idex_rd 					<= 0;
       	idex_funct3 			<= 0;
       	idex_funct7 			<= 0;
      	idex_cu_reg_write <= 0;
      	idex_cu_alu_src_a <= 0;
      	idex_cu_alu_src_b <= 0;
      	idex_cu_alu_op 		<= 0;
      	idex_cu_mem_read 	<= 0;
      	idex_cu_mem_write <= 0;
      	idex_cu_wb_sel 		<= 0;
      	idex_cu_branch 		<= 0;
      	idex_cu_jump 			<= 0;
      	idex_cu_jalr 			<= 0;
    	end else begin
    		ifid_pc <= pcout;
     		ifid_pcPlus4 <= pcadd4out;
     		ifid_instr <= instructionmeminstr;

      	idex_pc <= ifid_pc;
       	idex_pcPlus4 <= ifid_pcPlus4;
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

      exmem_pcPlus4 <= idex_pcPlus4;
      exmem_cu_reg_write <= idex_cu_reg_write;
      exmem_cu_mem_read <= idex_cu_mem_read;
      exmem_cu_mem_write <= idex_cu_mem_write;
      exmem_cu_wb_sel <= idex_cu_wb_sel;
      exmem_cu_branch <= idex_cu_branch;
      exmem_cu_jump <= idex_cu_jump;
      exmem_cu_jalr <= idex_cu_jalr;
      exmem_alu_out <= aluout;
      exmem_rd <= idex_rd;
      exmem_rdata2 <= idex_rdata2;

      memwb_pcPlus4 <= exmem_pcPlus4;
      memwb_cu_reg_write <= exmem_cu_reg_write;
      memwb_cu_wb_sel <= exmem_cu_wb_sel;
      memwb_alu_out <= exmem_alu_out;
      memwb_dataMem_rdata <= dataMem_rdata;
      memwb_rd <= exmem_rd;
    end
  end

endmodule

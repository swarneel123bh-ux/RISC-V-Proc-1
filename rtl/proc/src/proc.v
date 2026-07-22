`timescale 1ns / 1ps

module proc(
	input wire rstb	// Active low reset
);

	// Master clock
	reg clk;
  always begin #5; clk = ~clk; end

  // IF Stage Stuff
  wire [31:0] pcin_, pcin;
  wire [31:0] pcout;
  wire [31:0] pcadd4out;
  wire [31:0] pcBranchTarget;
  wire pcInMuxSel;
  wire hdu_stall;
  mux2x1_32 pcinmux(
  	.in1(pcadd4out),
   	.in2(pcBranchTarget),
    .sel(pcInMuxSel),
    .out(pcin_)
  );
  assign pcin = hdu_stall ? pcout : pcin_;
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
  wire [31:0] imem_um_addr, imem_um_rdata;
  instruction_mem instructionmem(
  	.clk(clk),
   	.addr(pcout),
    .instr(instructionmeminstr),
    .umem_addr(imem_um_addr),
    .umem_rdata(imem_um_rdata)
  );

  // IF/ID pipeline register
  reg [31:0] ifid_pc;
  reg [31:0] ifid_pcPlus4;
  reg [31:0] ifid_instr;

  // ID Stage Stuff
  //
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

  // CU Stuff
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
  reg [4:0] exmem_rd;				// NEED TO DECLARE HERE FOR USE IN FORWARDING UNIT
 	reg exmem_cu_reg_write;		// SAME REASON
  wire [1:0] forwardingUnit_forwardA;
  wire [1:0] forwardingUnit_forwardB;
  forwarding_unit forwardingUnit(
  	.idex_rs1(idex_rs1),
  	.idex_rs2(idex_rs2),
  	.exmem_rd(exmem_rd),
  	.exmem_reg_write(exmem_cu_reg_write),
  	.memwb_rd(memwb_rd),
  	.memwb_reg_write(memwb_cu_reg_write),
  	.forward_a(forwardingUnit_forwardA),
  	.forward_b(forwardingUnit_forwardB)
  );
  reg [31:0] exmem_alu_out;	// NEED DECLARED HERE
  reg [31:0] alusrca, alusrcb;
  reg [31:0] fwd_rdata1, fwd_rdata2;
  always @(*) begin		// Choose forwarded rdata1
  	fwd_rdata1 = idex_rdata1;							// Default REGFILE
 		case (forwardingUnit_forwardA)
   		2'b00: fwd_rdata1 = idex_rdata1; 		// FROM REGFILE
     	2'b01: fwd_rdata1 = wb_mux; 				// FROM MEM STAGE
      2'b10: fwd_rdata1 = exmem_alu_out;	// FROM EX STAGE
   	endcase
  end
  always @(*) begin		// Choose forwarded rdata2
 		fwd_rdata2 = idex_rdata2;							// Default REGFILE
		case (forwardingUnit_forwardB)
  		2'b00: fwd_rdata2 = idex_rdata2; 		// FROM REGFILE
    	2'b01: fwd_rdata2 = wb_mux; 				// FROM MEM STAGE
     2'b10: fwd_rdata2 = exmem_alu_out;		// FROM EX STAGE
  	endcase
  end
  always @(*) begin		// ALUSrcA Mux
  	alusrca = 32'h0;
 		case (idex_cu_alu_src_a)
   		2'b00: alusrca = fwd_rdata1;
     	2'b01: alusrca = idex_pc;
      2'b10: alusrca = 32'h0;
   	endcase
  end
  always @(*) begin 	// ALUSrcB Mux
  	alusrcb = (idex_cu_alu_src_b) ? idex_immdata : fwd_rdata2;
  end
  wire [31:0] aluout;
  wire aluzero;
  alu alu_(
  	.aluop_ctrl(aluctrl_out),
  	.alu_a(alusrca),
  	//.alu_b((idex_cu_alu_src_b) ? idex_immdata : idex_rdata2),
   	.alu_b(alusrcb),
  	.alu_out(aluout),
  	.alu_zero(aluzero)
  );
  wire branchUnit_take;
  branch_unit branchUnit(
 		.funct3(idex_funct3),
  	.rdata1(fwd_rdata1),
  	.rdata2(fwd_rdata2),
  	.take(branchUnit_take)
  );
  wire [31:0] branchDestination = (idex_pc + idex_immdata);							// Branches and JAL
  wire [31:0] jalrDestination = (fwd_rdata1 + idex_immdata) & ~32'b1;	// Only for JALR (last bit needs reset)
  assign pcInMuxSel = (idex_cu_branch & branchUnit_take) | idex_cu_jump | idex_cu_jalr;
  assign pcBranchTarget = idex_cu_jalr ? jalrDestination : branchDestination;

  // EX/MEM Pipeline register
  reg [31:0] exmem_pcPlus4;
 	reg exmem_cu_mem_read;
 	reg exmem_cu_mem_write;
 	reg [1:0] exmem_cu_wb_sel;
 	reg exmem_cu_branch;
 	reg exmem_cu_jump;
 	reg exmem_cu_jalr;
  reg [31:0] exmem_rdata2;
  reg [2:0] exmem_funct3;

  // MEM Stage Stuff
  wire [3:0] memwrap_wstrb;
  wire [31:0] memwrap_store_out;
  wire [31:0] memwrap_load_out;
  wire [31:0] dataMem_rdata;
  mem_wrapper memWrapper(
  .funct3(exmem_funct3),      			// size + signedness (from the instruction)
  .addr_lo(exmem_alu_out[1:0]),     // addr[1:0] — byte offset within the word
  .store_data(exmem_rdata2),  			// rs2 value to store (right-justified)
  .load_word(dataMem_rdata),   			// raw 32-bit word from data_mem
  .mem_write(exmem_cu_mem_write),   // is this a store?
  .wstrb(memwrap_wstrb),       			// byte-write enables -> data_mem
  .store_out(memwrap_store_out),   	// byte-shifted store data -> data_mem wdata
  .load_out(memwrap_load_out)     	// extracted + extended load result -> WB
  );

  // wire [3:0] dataMem_wstrb = exmem_cu_mem_write ? 4'b1111 : 4'b0000;
  wire [31:0] dmem_um_addr, dmem_um_wdata, dmem_um_rdata;
  wire [3:0] dmem_um_wstrb;
  wire dmem_um_read;
  data_mem dataMem(
  	// Proc side ports
 		.clk(clk),
  	.rstb(rstb),
  	.addr(exmem_alu_out),        	// byte address
  	.wdata(memwrap_store_out),       	// write data (right-justified)
  	.wstrb(memwrap_wstrb),       	// byte-write enables: bit i set means wdata word's byte i written
  	.mem_read(exmem_cu_mem_read), // read enable
  	.rdata(dataMem_rdata),        	// raw 32-bit word at addr (aligned)
  	// Unified memory side ports
  	.umem_addr(dmem_um_addr),
  	.umem_wdata(dmem_um_wdata),
  	.umem_wstrb(dmem_um_wstrb),
  	.umem_read(dmem_um_read),
  	.umem_rdata(dmem_um_rdata)
   );

  // Unified Memory
  unified_memory unifiedMemory(
  	.clk(clk),

   	// Instruction side ports, read-only, async
   	.imem_addr(imem_um_addr),
   	.imem_rdata(imem_um_rdata),

    // Data side ports, async read + sync byte-strobed write
    .dmem_addr(dmem_um_addr),
    .dmem_wdata(dmem_um_wdata),
    .dmem_wstrb(dmem_um_wstrb),
    .dmem_read(dmem_um_read),
    .dmem_rdata(dmem_um_rdata)
  );

  // MEM/WB Pipeline Register
  reg [31:0] memwb_pcPlus4;
  reg [1:0] memwb_cu_wb_sel;
  reg [31:0] memwb_alu_out;
  reg [31:0] memwb_dataMem_rdata;

  // WB Stage Stuff
  always @(*) begin
  	wb_mux = memwb_alu_out;
 		case (memwb_cu_wb_sel)
   		2'b00: wb_mux = memwb_alu_out;				// ALU Result
     	2'b01: wb_mux = memwb_dataMem_rdata;	// Data Memory Read Result
      2'b10: wb_mux = memwb_pcPlus4;				// PC+4 for JAL/JALR
  	endcase
  end

  // HAZARD DETECTION UNIT
  hazard_detection_unit hazardDetectionUnit(
	 	.id_rs1(id_rs1),        // sources of the instruction in ID
  	.id_rs2(id_rs2),
   	.idex_rd(idex_rd),       // dest of the instruction in EX
   	.idex_mem_read(idex_cu_mem_read), // is that EX instruction a load?
   	.stall(hdu_stall)
  );


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
      exmem_funct3 <= 0;

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
    	end else if (hdu_stall) begin
     		// FREEZE IFID, BUBBLE IDEX
     		ifid_pc 			<= ifid_pc;
       	ifid_pcPlus4 	<= ifid_pcPlus4;
      	ifid_instr 		<= ifid_instr;

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
      exmem_rdata2 <= fwd_rdata2;
      exmem_funct3 <= idex_funct3;

      memwb_pcPlus4 <= exmem_pcPlus4;
      memwb_cu_reg_write <= exmem_cu_reg_write;
      memwb_cu_wb_sel <= exmem_cu_wb_sel;
      memwb_alu_out <= exmem_alu_out;
      memwb_dataMem_rdata <= memwrap_load_out;
      memwb_rd <= exmem_rd;
    end
  end

endmodule

`timescale 1ns / 1ps

module forwarding_unit_tb ();
  reg  [4:0] idex_rs1, idex_rs2, exmem_rd, memwb_rd;
  reg        exmem_reg_write, memwb_reg_write;
  wire [1:0] forward_a, forward_b;
  integer    errors = 0;

  forwarding_unit DUT (
    .idex_rs1(idex_rs1), .idex_rs2(idex_rs2),
    .exmem_rd(exmem_rd), .exmem_reg_write(exmem_reg_write),
    .memwb_rd(memwb_rd), .memwb_reg_write(memwb_reg_write),
    .forward_a(forward_a), .forward_b(forward_b));

  localparam REGF=2'b00, MEMWB=2'b01, EXMEM=2'b10;

  task chk(input [1:0] exp_a, input [1:0] exp_b, input [80*8:1] name);
  begin
    #1;
    if (forward_a !== exp_a || forward_b !== exp_b) begin
      errors = errors + 1;
      $display("FAIL %-34s fa=%b fb=%b  exp fa=%b fb=%b",
               name, forward_a, forward_b, exp_a, exp_b);
    end else
      $display("PASS %-34s fa=%b fb=%b", name, forward_a, forward_b);
  end endtask

  task setup(input [4:0] rs1, input [4:0] rs2,
             input [4:0] xmrd, input xmw, input [4:0] mwrd, input mww);
  begin
    idex_rs1=rs1; idex_rs2=rs2;
    exmem_rd=xmrd; exmem_reg_write=xmw;
    memwb_rd=mwrd; memwb_reg_write=mww;
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/forwarding_unit_tb.vcd");
      $dumpvars(0, forwarding_unit_tb);
    end

    // no hazard at all
    setup(5,6, 10,1, 11,1);          chk(REGF, REGF, "no match");

    // single EX/MEM forward, rs1 only
    setup(5,6, 5,1, 20,1);           chk(EXMEM, REGF, "EXMEM -> A only");
    // single EX/MEM forward, rs2 only
    setup(5,6, 6,1, 20,1);           chk(REGF, EXMEM, "EXMEM -> B only");
    // EX/MEM forward to both
    setup(7,7, 7,1, 20,1);           chk(EXMEM, EXMEM, "EXMEM -> A and B");

    // single MEM/WB forward
    setup(5,6, 20,1, 5,1);           chk(MEMWB, REGF, "MEMWB -> A only");
    setup(5,6, 20,1, 6,1);           chk(REGF, MEMWB, "MEMWB -> B only");

    // ---- priority: BOTH stages match -> EX/MEM must win ----
    setup(8,9, 8,1, 8,1);            chk(EXMEM, REGF, "A: EXMEM beats MEMWB");
    setup(8,9, 9,1, 9,1);            chk(REGF, EXMEM, "B: EXMEM beats MEMWB");
    setup(8,8, 8,1, 8,1);            chk(EXMEM, EXMEM, "both: EXMEM beats MEMWB");

    // mixed: A from EX/MEM, B from MEM/WB
    setup(3,4, 3,1, 4,1);            chk(EXMEM, MEMWB, "A=EXMEM, B=MEMWB");

    // ---- reg_write=0 must suppress forwarding ----
    setup(5,6, 5,0, 20,1);           chk(REGF, REGF, "EXMEM rd match but regwrite=0");
    setup(5,6, 20,1, 5,0);           chk(REGF, REGF, "MEMWB rd match but regwrite=0");

    // ---- x0 must never forward ----
    setup(0,0, 0,1, 0,1);            chk(REGF, REGF, "x0: no forward even if match");
    setup(0,6, 6,1, 0,1);            chk(REGF, EXMEM, "rs1=x0 no fwd, rs2 fwd ok");

    // EX/MEM regwrite=0 but MEM/WB matches -> MEM/WB should forward
    setup(5,6, 5,0, 5,1);            chk(MEMWB, REGF, "EXMEM suppressed, MEMWB A");

    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

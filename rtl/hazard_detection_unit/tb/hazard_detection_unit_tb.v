`timescale 1ns / 1ps

module hazard_detection_unit_tb ();
  reg  [4:0] id_rs1, id_rs2, idex_rd;
  reg        idex_mem_read;
  wire       stall;
  integer    errors = 0;

  hazard_detection_unit DUT (
    .id_rs1(id_rs1), .id_rs2(id_rs2),
    .idex_rd(idex_rd), .idex_mem_read(idex_mem_read),
    .stall(stall));

  task chk(input exp, input [80*8:1] name);
  begin
    #1;
    if (stall !== exp) begin
      errors = errors + 1;
      $display("FAIL %-36s stall=%b exp %b", name, stall, exp);
    end else
      $display("PASS %-36s stall=%b", name, stall);
  end endtask

  task setup(input [4:0] rs1, input [4:0] rs2, input [4:0] rd, input ld);
  begin id_rs1=rs1; id_rs2=rs2; idex_rd=rd; idex_mem_read=ld; end
  endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/hazard_detection_unit_tb.vcd");
      $dumpvars(0, hazard_detection_unit_tb);
    end

    // load in EX, dependent instruction in ID -> STALL
    setup(5, 9, 5, 1);   chk(1, "load feeds rs1");
    setup(9, 5, 5, 1);   chk(1, "load feeds rs2");
    setup(5, 5, 5, 1);   chk(1, "load feeds both");

    // load in EX, but ID uses neither -> no stall
    setup(9, 8, 5, 1);   chk(0, "load, no dependency");

    // NOT a load in EX (ALU op), dest matches -> no stall (forwarding handles it)
    setup(5, 9, 5, 0);   chk(0, "ALU producer match -> no stall");
    setup(5, 5, 5, 0);   chk(0, "ALU producer both -> no stall");

    // load into x0 -> discarded, no stall even if index matches
    setup(0, 0, 0, 1);   chk(0, "load to x0, rs=x0 -> no stall");

    // subtle: load rd=0 but ID reads x0 -> no stall (x0 guard)
    setup(0, 9, 0, 1);   chk(0, "load x0, rs1=x0 -> no stall");

    // load rd != source -> no stall
    setup(1, 2, 3, 1);   chk(0, "load rd=3, sources 1,2 -> no stall");

    // realistic: lw x1,..; add x3,x1,x4  (rs1=1 matches load rd=1)
    setup(1, 4, 1, 1);   chk(1, "lw x1; add x3,x1,x4 -> stall");
    // realistic: lw x1,..; add x3,x4,x1  (rs2=1 matches)
    setup(4, 1, 1, 1);   chk(1, "lw x1; add x3,x4,x1 -> stall");
    // lw x1,..; addi x3,x4,5  (no dep) -> no stall
    setup(4, 0, 1, 1);   chk(0, "lw x1; addi x3,x4,5 -> no stall");

    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

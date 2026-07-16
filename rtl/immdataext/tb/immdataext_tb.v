`timescale 1ns / 1ps

module immdataext_tb ();
  reg  [31:0] instr;
  wire [31:0] immdata;
  integer     errors = 0;

  immdataext DUT (.ifid_instr(instr), .immdata(immdata));

  task chk(input [31:0] i, input [31:0] e, input [80*8:1] name);
  begin
    instr = i; #1;
    if (immdata !== e) begin
      errors = errors + 1;
      $display("FAIL %0s instr=%08h got=%08h exp=%08h", name, i, immdata, e);
    end else begin
      $display("PASS %0s instr=%08h imm=%08h", name, i, immdata);
    end
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/immdataext_tb.vcd");
      $dumpvars(0, immdataext_tb);
    end

    // I-type: addi x1,x0,imm  (0,+/-1, +/-max)
    chk(32'h00500093, 32'h00000005, "I addi 5");
    chk(32'hfff00093, 32'hffffffff, "I addi -1");
    chk(32'h7ff00093, 32'h000007ff, "I addi 2047");
    chk(32'h80000093, 32'hfffff800, "I addi -2048");
    chk(32'hffc0a283, 32'hfffffffc, "I lw -4(x1)");
    chk(32'h010100e7, 32'h00000010, "I jalr 16");

    // U-type
    chk(32'h123450b7, 32'h12345000, "U lui 0x12345");
    chk(32'hfffff117, 32'hfffff000, "U auipc 0xfffff");

    // S-type: sw x2,imm(x1)
    chk(32'h0020a423, 32'h00000008, "S sw 8");
    chk(32'hfe20ac23, 32'hfffffff8, "S sw -8");
    chk(32'h7e20afa3, 32'h000007ff, "S sw 2047");
    chk(32'h8020a023, 32'hfffff800, "S sw -2048");

    // B-type: beq x1,x2,offset  (scrambled fields)
    chk(32'h00208463, 32'h00000008, "B beq +8");
    chk(32'hfe208ce3, 32'hfffffff8, "B beq -8");
    chk(32'h7e208fe3, 32'h00000ffe, "B beq +4094");
    chk(32'h80208063, 32'hfffff000, "B beq -4096");
    chk(32'h002080e3, 32'h00000800, "B beq +2048");
    chk(32'h802080e3, 32'hfffff800, "B beq -2048");

    // J-type: jal x1,offset  (scrambled fields)
    chk(32'h008000ef, 32'h00000008, "J jal +8");
    chk(32'hff9ff0ef, 32'hfffffff8, "J jal -8");
    chk(32'h7ffff0ef, 32'h000ffffe, "J jal +1048574");
    chk(32'h800000ef, 32'hfff00000, "J jal -1048576");
    chk(32'h001000ef, 32'h00000800, "J jal +2048");
    chk(32'h801ff0ef, 32'hfffff800, "J jal -2048");

    // unknown opcode -> 0
    chk(32'h00000073, 32'h00000000, "default (ecall)");

    if (errors == 0) $display("RESULT: PASS (25 vectors)");
    else             $display("RESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

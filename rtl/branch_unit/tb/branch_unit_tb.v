`timescale 1ns / 1ps

module branch_unit_tb ();
  reg  [2:0]  funct3;
  reg  [31:0] rdata1, rdata2;
  wire        take;
  integer     errors = 0;

  branch_unit DUT (.funct3(funct3), .rdata1(rdata1), .rdata2(rdata2), .take(take));

  localparam BEQ=3'b000, BNE=3'b001, BLT=3'b100, BGE=3'b101, BLTU=3'b110, BGEU=3'b111;

  task chk(input [2:0] f3, input [31:0] a, input [31:0] b,
           input exp, input [80*8:1] name);
  begin
    funct3=f3; rdata1=a; rdata2=b; #1;
    if (take !== exp) begin
      errors=errors+1;
      $display("FAIL %-22s f3=%b a=%08h b=%08h -> %b exp %b", name, f3, a, b, take, exp);
    end else
      $display("PASS %-22s f3=%b a=%08h b=%08h -> %b", name, f3, a, b, take);
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/branch_unit_tb.vcd");
      $dumpvars(0, branch_unit_tb);
    end

    // BEQ / BNE
    chk(BEQ, 32'd5, 32'd5, 1'b1, "BEQ equal");
    chk(BEQ, 32'd5, 32'd6, 1'b0, "BEQ unequal");
    chk(BNE, 32'd5, 32'd6, 1'b1, "BNE unequal");
    chk(BNE, 32'd5, 32'd5, 1'b0, "BNE equal");
    chk(BEQ, 32'hFFFFFFFF, 32'hFFFFFFFF, 1'b1, "BEQ -1==-1");

    // BLT / BGE  (signed)
    chk(BLT, 32'd3, 32'd5, 1'b1, "BLT 3<5");
    chk(BLT, 32'd5, 32'd3, 1'b0, "BLT 5<3");
    chk(BLT, 32'd5, 32'd5, 1'b0, "BLT 5<5");
    chk(BLT, 32'hFFFFFFFF, 32'd1, 1'b1, "BLT -1<1 (signed!)");
    chk(BLT, 32'd1, 32'hFFFFFFFF, 1'b0, "BLT 1<-1");
    chk(BLT, 32'h80000000, 32'h7FFFFFFF, 1'b1, "BLT INT_MIN<INT_MAX");
    chk(BGE, 32'd5, 32'd3, 1'b1, "BGE 5>=3");
    chk(BGE, 32'd5, 32'd5, 1'b1, "BGE 5>=5 (equal)");
    chk(BGE, 32'd3, 32'd5, 1'b0, "BGE 3>=5");
    chk(BGE, 32'd1, 32'hFFFFFFFF, 1'b1, "BGE 1>=-1 (signed!)");
    chk(BGE, 32'h7FFFFFFF, 32'h80000000, 1'b1, "BGE INT_MAX>=INT_MIN");

    // BLTU / BGEU  (unsigned) — same bit patterns, opposite answers
    chk(BLTU, 32'd3, 32'd5, 1'b1, "BLTU 3<5");
    chk(BLTU, 32'hFFFFFFFF, 32'd1, 1'b0, "BLTU big<1 (unsigned!)");
    chk(BLTU, 32'd1, 32'hFFFFFFFF, 1'b1, "BLTU 1<big");
    chk(BLTU, 32'd5, 32'd5, 1'b0, "BLTU 5<5");
    chk(BGEU, 32'hFFFFFFFF, 32'd1, 1'b1, "BGEU big>=1 (unsigned!)");
    chk(BGEU, 32'd1, 32'hFFFFFFFF, 1'b0, "BGEU 1>=big");
    chk(BGEU, 32'd5, 32'd5, 1'b1, "BGEU 5>=5 (equal)");

    // the tell-tale pair: same operands, signed vs unsigned DISAGREE
    chk(BLT,  32'hFFFFFFFF, 32'd1, 1'b1, "signed:   -1 < 1  = taken");
    chk(BLTU, 32'hFFFFFFFF, 32'd1, 1'b0, "unsigned: big<1  = not");

    // unused funct3 -> never take
    chk(3'b010, 32'd5, 32'd5, 1'b0, "unused f3=010");
    chk(3'b011, 32'd0, 32'd9, 1'b0, "unused f3=011");

    if (errors==0) $display("\nRESULT: PASS");
    else           $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

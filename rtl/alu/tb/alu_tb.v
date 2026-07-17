`timescale 1ns / 1ps

module alu_tb ();
  reg  [3:0]  aluop_ctrl;
  reg  [31:0] alu_a, alu_b;
  wire [31:0] alu_out;
  wire        alu_zero;
  integer     errors = 0;

  alu DUT (.aluop_ctrl(aluop_ctrl), .alu_a(alu_a), .alu_b(alu_b),
           .alu_out(alu_out), .alu_zero(alu_zero));

  localparam ALUOP_ADD=4'b0000, ALUOP_SUB=4'b0001, ALUOP_SLL=4'b0010,
             ALUOP_SLT=4'b0011, ALUOP_SLTU=4'b0100, ALUOP_XOR=4'b0101,
             ALUOP_SRL=4'b0110, ALUOP_SRA=4'b0111, ALUOP_OR=4'b1000,
             ALUOP_AND=4'b1001;

  task chk(input [3:0] op, input [31:0] a, input [31:0] b,
           input [31:0] exp, input [80*8:1] name);
  begin
    aluop_ctrl = op; alu_a = a; alu_b = b; #1;
    if (alu_out !== exp) begin
      errors = errors + 1;
      $display("FAIL %-20s a=%08h b=%08h -> %08h  exp %08h", name, a, b, alu_out, exp);
    end else
      $display("PASS %-20s a=%08h b=%08h -> %08h", name, a, b, alu_out);
  end endtask

  task chkz(input [3:0] op, input [31:0] a, input [31:0] b,
            input exp_z, input [80*8:1] name);
  begin
    aluop_ctrl = op; alu_a = a; alu_b = b; #1;
    if (alu_zero !== exp_z) begin
      errors = errors + 1;
      $display("FAIL %-20s zero=%b exp %b", name, alu_zero, exp_z);
    end else
      $display("PASS %-20s zero=%b", name, alu_zero);
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/alu_tb.vcd");
      $dumpvars(0, alu_tb);
    end

    chk(ALUOP_ADD, 32'd5, 32'd3, 32'd8, "ADD 5+3");
    chk(ALUOP_ADD, 32'hFFFFFFFF, 32'd1, 32'h00000000, "ADD -1+1 wrap");
    chk(ALUOP_ADD, 32'h7FFFFFFF, 32'd1, 32'h80000000, "ADD overflow");

    chk(ALUOP_SUB, 32'd8, 32'd3, 32'd5, "SUB 8-3");
    chk(ALUOP_SUB, 32'd0, 32'd1, 32'hFFFFFFFF, "SUB 0-1");

    chk(ALUOP_SLL, 32'd1, 32'd4,  32'h00000010, "SLL 1<<4");
    chk(ALUOP_SLL, 32'd1, 32'd31, 32'h80000000, "SLL 1<<31");
    chk(ALUOP_SLL, 32'd1, 32'd33, 32'h00000002, "SLL shamt mask");

    chk(ALUOP_SLT, 32'd3, 32'd5, 32'd1, "SLT 3<5");
    chk(ALUOP_SLT, 32'd5, 32'd3, 32'd0, "SLT 5<3");
    chk(ALUOP_SLT, 32'd5, 32'd5, 32'd0, "SLT 5<5");
    chk(ALUOP_SLT, 32'hFFFFFFFF, 32'd1, 32'd1, "SLT -1<1");
    chk(ALUOP_SLT, 32'd1, 32'hFFFFFFFF, 32'd0, "SLT 1<-1");
    chk(ALUOP_SLT, 32'hFFFFFFFB, 32'hFFFFFFFD, 32'd1, "SLT -5<-3");

    chk(ALUOP_SLTU, 32'd3, 32'd5, 32'd1, "SLTU 3<5");
    chk(ALUOP_SLTU, 32'd5, 32'd3, 32'd0, "SLTU 5<3");
    chk(ALUOP_SLTU, 32'hFFFFFFFF, 32'd1, 32'd0, "SLTU big<1");
    chk(ALUOP_SLTU, 32'd1, 32'hFFFFFFFF, 32'd1, "SLTU 1<big");

    chk(ALUOP_XOR, 32'hF0F0F0F0, 32'h0F0F0F0F, 32'hFFFFFFFF, "XOR");
    chk(ALUOP_XOR, 32'hAAAA5555, 32'hFFFFFFFF, 32'h5555AAAA, "XOR invert");

    chk(ALUOP_SRL, 32'hFFFFFFF8, 32'd2,  32'h3FFFFFFE, "SRL -8>>2");
    chk(ALUOP_SRL, 32'h80000000, 32'd31, 32'h00000001, "SRL msb");

    chk(ALUOP_SRA, 32'hFFFFFFF8, 32'd2,  32'hFFFFFFFE, "SRA -8>>>2");
    chk(ALUOP_SRA, 32'h80000000, 32'd31, 32'hFFFFFFFF, "SRA min>>>31");
    chk(ALUOP_SRA, 32'h7FFFFFFF, 32'd1,  32'h3FFFFFFF, "SRA pos>>>1");
    chk(ALUOP_SRA, 32'hFFFFFFFF, 32'd4,  32'hFFFFFFFF, "SRA -1>>>4");

    chk(ALUOP_OR,  32'hF0F0F0F0, 32'h0F0F0F0F, 32'hFFFFFFFF, "OR");
    chk(ALUOP_AND, 32'hF0F0F0F0, 32'h0F0F0F0F, 32'h00000000, "AND");
    chk(ALUOP_AND, 32'hFFFF0000, 32'hAAAAAAAA, 32'hAAAA0000, "AND mask");

    chkz(ALUOP_SUB, 32'd5, 32'd5, 1'b1, "zero: SUB 5-5");
    chkz(ALUOP_SUB, 32'd5, 32'd3, 1'b0, "zero: SUB 5-3");
    chkz(ALUOP_ADD, 32'd0, 32'd0, 1'b1, "zero: ADD 0+0");

    // latch check: illegal op must not retain the previous result
    chk(ALUOP_AND, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, "AND prime latch");
    chk(4'b1111,   32'd0, 32'd0, 32'd0, "illegal op -> 0");

    if (errors == 0) $display("\nRESULT: PASS");
    else             $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

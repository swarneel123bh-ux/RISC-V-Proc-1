`timescale 1ns / 1ps

module mem_wrapper_tb ();
  reg  [2:0]  funct3;
  reg  [1:0]  addr_lo;
  reg  [31:0] store_data, load_word;
  reg         mem_write;
  wire [3:0]  wstrb;
  wire [31:0] store_out, load_out;
  integer     errors = 0;

  mem_wrapper DUT (
    .funct3(funct3), .addr_lo(addr_lo),
    .store_data(store_data), .load_word(load_word), .mem_write(mem_write),
    .wstrb(wstrb), .store_out(store_out), .load_out(load_out));

  localparam LB=3'b000, LH=3'b001, LW=3'b010, LBU=3'b100, LHU=3'b101;
  localparam SB=3'b000, SH=3'b001, SW=3'b010;

  // ---- load check ----
  task ld(input [2:0] f3, input [1:0] a, input [31:0] word, input [31:0] exp,
          input [80*8:1] name);
  begin
    mem_write=0; funct3=f3; addr_lo=a; load_word=word; store_data=32'h0; #1;
    if (load_out !== exp) begin
      errors=errors+1;
      $display("FAIL %-24s f3=%b a=%0d word=%08h -> %08h exp %08h",
               name, f3, a, word, load_out, exp);
    end else
      $display("PASS %-24s -> %08h", name, load_out);
  end endtask

  // ---- store check ----
  task st(input [2:0] f3, input [1:0] a, input [31:0] data,
          input [3:0] exp_strb, input [31:0] exp_out, input [80*8:1] name);
  begin
    mem_write=1; funct3=f3; addr_lo=a; store_data=data; load_word=32'h0; #1;
    if (wstrb !== exp_strb || store_out !== exp_out) begin
      errors=errors+1;
      $display("FAIL %-24s f3=%b a=%0d data=%08h -> strb=%b out=%08h exp strb=%b out=%08h",
               name, f3, a, data, wstrb, store_out, exp_strb, exp_out);
    end else
      $display("PASS %-24s strb=%b out=%08h", name, wstrb, store_out);
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/mem_wrapper_tb.vcd");
      $dumpvars(0, mem_wrapper_tb);
    end

    // ================= LOADS =================
    // word: byte3=0x80 byte2=0x7F byte1=0xFF byte0=0x01
    // 0x807FFF01
    $display("--- LB (sign-extend) ---");
    ld(LB, 0, 32'h807FFF01, 32'h00000001, "LB byte0=01 (+)");
    ld(LB, 1, 32'h807FFF01, 32'hFFFFFFFF, "LB byte1=FF (-)");
    ld(LB, 2, 32'h807FFF01, 32'h0000007F, "LB byte2=7F (+)");
    ld(LB, 3, 32'h807FFF01, 32'hFFFFFF80, "LB byte3=80 (-)");

    $display("--- LBU (zero-extend) ---");
    ld(LBU, 1, 32'h807FFF01, 32'h000000FF, "LBU byte1=FF");
    ld(LBU, 3, 32'h807FFF01, 32'h00000080, "LBU byte3=80");

    $display("--- LH (sign-extend, offset 0/2) ---");
    ld(LH, 0, 32'h807FFF01, 32'hFFFFFF01, "LH low=FF01 (-)");
    ld(LH, 2, 32'h807FFF01, 32'hFFFF807F, "LH high=807F (-)");
    ld(LH, 0, 32'h00001234, 32'h00001234, "LH low=1234 (+)");
    ld(LH, 2, 32'h1234ABCD, 32'h00001234, "LH high=1234 (+)");

    $display("--- LHU (zero-extend) ---");
    ld(LHU, 0, 32'h807FFF01, 32'h0000FF01, "LHU low=FF01");
    ld(LHU, 2, 32'h807FFF01, 32'h0000807F, "LHU high=807F");

    $display("--- LW ---");
    ld(LW, 0, 32'hDEADBEEF, 32'hDEADBEEF, "LW");

    // ================= STORES =================
    $display("--- SB (strobe + lane shift) ---");
    st(SB, 0, 32'h000000AB, 4'b0001, 32'h000000AB, "SB lane0");
    st(SB, 1, 32'h000000AB, 4'b0010, 32'h0000AB00, "SB lane1");
    st(SB, 2, 32'h000000AB, 4'b0100, 32'h00AB0000, "SB lane2");
    st(SB, 3, 32'h000000AB, 4'b1000, 32'hAB000000, "SB lane3");
    // only low byte of store_data matters
    st(SB, 2, 32'hFFFFFF99, 4'b0100, 32'h00990000, "SB uses low byte only");

    $display("--- SH (strobe + lane shift) ---");
    st(SH, 0, 32'h0000ABCD, 4'b0011, 32'h0000ABCD, "SH low half");
    st(SH, 2, 32'h0000ABCD, 4'b1100, 32'hABCD0000, "SH high half");
    st(SH, 0, 32'hFFFF1234, 4'b0011, 32'h00001234, "SH uses low half only");

    $display("--- SW ---");
    st(SW, 0, 32'hCAFEBABE, 4'b1111, 32'hCAFEBABE, "SW");

    if (errors==0) $display("\nRESULT: PASS");
    else           $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

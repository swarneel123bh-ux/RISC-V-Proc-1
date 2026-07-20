`timescale 1ns / 1ps

module data_mem_tb ();
  reg         clk = 0;
  reg         rstb;
  reg  [31:0] addr, wdata;
  reg  [3:0]  wstrb;
  reg         mem_read;
  wire [31:0] rdata;
  integer     errors = 0;

  data_mem #(.DEPTH_BYTES(4096)) DUT (
    .clk(clk), .rstb(rstb), .addr(addr), .wdata(wdata),
    .wstrb(wstrb), .mem_read(mem_read), .rdata(rdata));

  always #5 clk = ~clk;

  task wr(input [31:0] a, input [31:0] d, input [3:0] s);
  begin
    @(negedge clk); addr=a; wdata=d; wstrb=s; mem_read=0;
    @(posedge clk); #1; wstrb=4'b0000;
  end endtask

  task rdchk(input [31:0] a, input [31:0] exp, input [80*8:1] name);
  begin
    addr=a; mem_read=1; #1;
    if (rdata !== exp) begin
      errors=errors+1;
      $display("FAIL %-26s @%08h -> %08h  exp %08h", name, a, rdata, exp);
    end else
      $display("PASS %-26s @%08h -> %08h", name, a, rdata);
    mem_read=0;
  end endtask

  task rd_disabled_chk(input [31:0] a);
  begin
    addr=a; mem_read=0; #1;
    if (rdata !== 32'h0) begin
      errors=errors+1;
      $display("FAIL read-disabled @%08h -> %08h  exp 00000000", a, rdata);
    end else
      $display("PASS read-disabled @%08h -> 00000000", a);
  end endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/data_mem_tb.vcd");
      $dumpvars(0, data_mem_tb);
    end
    rstb=0; addr=0; wdata=0; wstrb=0; mem_read=0;
    @(negedge clk); rstb=1;

    wr(32'h0000_0000, 32'hDEADBEEF, 4'b1111);
    rdchk(32'h0000_0000, 32'hDEADBEEF, "SW word0");
    wr(32'h0000_0004, 32'hCAFEBABE, 4'b1111);
    rdchk(32'h0000_0004, 32'hCAFEBABE, "SW word1");
    rdchk(32'h0000_0000, 32'hDEADBEEF, "word0 intact after word1");

    rdchk(32'h0000_0001, 32'hDEADBEEF, "addr+1 -> same word0");
    rdchk(32'h0000_0003, 32'hDEADBEEF, "addr+3 -> same word0");

    wr(32'h0000_0000, 32'h00000011, 4'b0001);
    rdchk(32'h0000_0000, 32'hDEADBE11, "SB lane0 (rest intact)");
    wr(32'h0000_0000, 32'h00220000, 4'b0100);
    rdchk(32'h0000_0000, 32'hDE22BE11, "SB lane2 (others intact)");

    wr(32'h0000_0000, 32'h0000ABCD, 4'b0011);
    rdchk(32'h0000_0000, 32'hDE22ABCD, "SH low half");
    wr(32'h0000_0000, 32'h98760000, 4'b1100);
    rdchk(32'h0000_0000, 32'h9876ABCD, "SH high half");

    wr(32'h0000_0004, 32'hFFFFFFFF, 4'b0000);
    rdchk(32'h0000_0004, 32'hCAFEBABE, "wstrb=0 -> no write");

    wr(32'h0000_0100, 32'h11112222, 4'b1111);
    wr(32'h0000_0104, 32'h33334444, 4'b1111);
    rdchk(32'h0000_0100, 32'h11112222, "distinct word A");
    rdchk(32'h0000_0104, 32'h33334444, "distinct word B");

    wr(32'h0000_0008, 32'h5A5A5A5A, 4'b1111);
    rd_disabled_chk(32'h0000_0008);
    rdchk(32'h0000_0008, 32'h5A5A5A5A, "re-enabled read");

    if (errors==0) $display("\nRESULT: PASS");
    else           $display("\nRESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

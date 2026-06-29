`timescale 1ns / 1ps

module mem_tb ();
  reg         clk;
  reg         rstb;
  reg         we;
  reg         re;
  reg  [31:0] addr;
  reg  [31:0] wdata;
  wire [31:0] rdata;

  mem MEM (
      .clk(clk),
      .rstb(rstb),
      .wen(we),
      .ren(re),
      .addr(addr),
      .wdata(wdata),
      .rdata(rdata)
  );

  always #5 clk = ~clk;

  task write_word;
    input [31:0] address;
    input [31:0] data;
    begin
      @(negedge clk);
      addr  = address;
      wdata = data;
      we    = 1;
      re    = 0;
      @(posedge clk);
      #1;
      we = 0;
    end
  endtask

  task read_word;
    input [31:0] address;
    begin
      @(negedge clk);
      addr  = address;
      wdata = 32'h0;
      we    = 0;
      re    = 1;
      @(posedge clk);
      #1;
      re = 0;
    end
  endtask

  task check;
    input [31:0] expected;
    input [63:0] test_name;
    begin
      if (rdata == expected) $display("PASS [%s]: got 0x%08X", test_name, rdata);
      else $display("FAIL [%s]: expected 0x%08X got 0x%08X", test_name, expected, rdata);
    end
  endtask

  initial begin
    $dumpfile("build/mem_tb.vcd");
    $dumpvars(0, mem_tb);

    clk   = 0;
    rstb  = 0;
    we    = 0;
    re    = 0;
    addr  = 0;
    wdata = 0;

    // hold reset
    repeat (2) @(posedge clk);
    rstb = 1;
    repeat (2) @(posedge clk);

    // test 1: readmemh load — word 0
    read_word(32'h00000000);
    check(32'hAABBCCDD, "readmemh[0]");

    // test 2: readmemh load — word 1
    read_word(32'h00000004);
    check(32'h11223344, "readmemh[1]");

    // test 3: readmemh load — word 2
    read_word(32'h00000008);
    check(32'hDEADBEEF, "readmemh[2]");

    // test 4: write then read back
    write_word(32'h00000010, 32'h12345678);
    read_word(32'h00000010);
    check(32'h12345678, "write/read ");

    // test 5: overwrite and read back
    write_word(32'h00000010, 32'hCAFEBABE);
    read_word(32'h00000010);
    check(32'hCAFEBABE, "overwrite  ");

    // test 6: simultaneous we+re — should return old data
    write_word(32'h00000020, 32'hAAAAAAAA);
    @(negedge clk);
    addr  = 32'h00000020;
    wdata = 32'hBBBBBBBB;
    we    = 1;
    re    = 1;
    @(posedge clk);
    #1;
    we = 0;
    re = 0;
    check(32'hAAAAAAAA, "old data   ");

    // test 7: unmapped access — should warn and return 0xDEADBEEF
    read_word(32'hDEAD0000);
    check(32'hDEADBEEF, "unmapped   ");

    repeat (2) @(posedge clk);
    $finish;
  end

endmodule

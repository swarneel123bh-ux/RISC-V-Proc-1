`timescale 1ns / 1ps
module regfile_tb ();
	reg clk;
	reg wen;
	reg rstb;
	reg [4:0] raddr1;
	reg [4:0] raddr2;
	wire [31:0] rdata1;
	wire [31:0] rdata2;
	reg [4:0] waddr;
	reg [31:0] wdata;
	regfile uut(
		.clk(clk),
		.rstb(rstb),
		.wen(wen),
		.raddr1(raddr1),
		.raddr2(raddr2),
		.rdata1(rdata1),
		.rdata2(rdata2),
		.waddr(waddr),
		.wdata(wdata)
	);

	always begin #10; clk = ~clk; end

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/regfile_tb.vcd");
      $dumpvars(0, regfile_tb);
    end

    clk = 0;
    rstb = 0; #30; rstb = 1;
    wen = 0;

    raddr1 = 0; raddr2 = 10; waddr = 0; wdata = 32'hFEEDBEEF; #30 wen = 1; #10; wen = 0; #30;
    raddr1 = 0; raddr2 = 10; waddr = 7;	wdata = 32'hFEEDBEEF; #30 wen = 1; #10; wen = 0; #30;
    raddr1 = 7; raddr2 = 10; waddr = 2;	wdata = 32'hFEEDBEEF; #30 wen = 1; #10; wen = 0; #30;
    raddr1 = 0; raddr2 = 10; waddr = 10; wdata = 32'hFEEDBEEF; #30 wen = 1; #10; wen = 0; #30;


    #100;
    $finish;
  end
endmodule

`timescale 1ns / 1ps
module div_iter_tb ();

	localparam WIDTH = 32;
	localparam CLK_PERIOD_HALF = 5;
	reg                 clk; 					always begin #CLK_PERIOD_HALF; clk = ~clk; end
 	reg                 rstb;
 	reg                 start;
 	reg  [WIDTH-1:0]    dividend;
 	reg  [WIDTH-1:0]    divisor;
 	wire [WIDTH-1:0]    quotient;
 	wire [WIDTH-1:0]    remainder;
 	wire                ready;
 	wire                dbz;
  div_iter #( .WIDTH(WIDTH /* default 32 */) ) div_iter (
  	.clk      (clk),
  	.rstb     (rstb),
  	.start    (start),
  	.dividend (dividend),
  	.divisor  (divisor),
  	.quotient (quotient),
  	.remainder(remainder),
  	.ready    (ready),
  	.dbz      (dbz)
  );

  integer total, passed, failed;

  task assert_rstb;
  	begin
   		@(posedge clk); #1; rstb = 0;
     	@(negedge clk);
      @(posedge clk); #1; rstb = 1;
   	end
  endtask

  task assert_job_and_check;
  	input [WIDTH-1:0] DIVIDEND;
  	input [WIDTH-1:0] DIVISOR;
   	reg [WIDTH-1:0] EXP_QUOTIENT;
   	reg [WIDTH-1:0] EXP_REMAINDER;
  	begin
   		total = total + 1;
   		EXP_QUOTIENT 	= (DIVISOR == 0) ? -1 : DIVIDEND / DIVISOR;
     	EXP_REMAINDER = (DIVISOR == 0) ? DIVIDEND : DIVIDEND % DIVISOR;
      @(posedge clk);
      dividend 	= DIVIDEND;
      divisor 	= DIVISOR;
      // Assert start for exactly 1 clock cycle
      @(negedge clk); #(CLK_PERIOD_HALF - 1);
      start = 1; @(posedge clk); #1; start = 0;
      @(posedge ready);
      if ((EXP_QUOTIENT == quotient) && (EXP_REMAINDER == remainder)) passed = passed + 1;
      else begin
      	$display("[FAILED] dividend=0x%h divisor=0x%h EXP_QUOTIENT=0x%h quotient=0x%h EXP_REMAINDER=0x%h remainder=0x%h",
       		dividend, divisor,
       		EXP_QUOTIENT, quotient,
       		EXP_REMAINDER, remainder
       );
       failed = failed + 1;
      end
   	end
  endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/div_iter_tb.vcd");
      $dumpvars(0, div_iter_tb);
    end

    clk = 0;
    rstb = 1;
    dividend = 0;
    divisor = 0;
    total = 0; passed = 0; failed = 0;
    assert_rstb();

    assert_job_and_check(0, 0);

    repeat (2) @(posedge clk); assert_job_and_check(36, 3);
    repeat (2) @(posedge clk); assert_job_and_check(-36, 3);
    repeat (2) @(posedge clk); assert_job_and_check(36, -3);
    repeat (2) @(posedge clk); assert_job_and_check(-36, -3);

    repeat (2) @(posedge clk); assert_job_and_check(12, 2);
    repeat (2) @(posedge clk); assert_job_and_check(100, 20);
    repeat (2) @(posedge clk); assert_job_and_check(10000, 3);

    $finish;
  end
endmodule

`timescale 1ns / 1ps

module program_counter_tb ();

	reg rstb;
	reg clk;
	reg [31:0] in;
	wire [31:0] out;
	program_counter uut(
		.rstb(rstb),
		.clk(clk),
		.in(in),
		.out(out)
	);

	always begin #10; clk = ~clk; end

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/program_counter_tb.vcd");
      $dumpvars(0, program_counter_tb);
    end

    clk = 0;
    rstb = 0;
    in = 0;
    #10;
    rstb = 1;

    #100;
    $finish;
  end

  always @(posedge clk) begin
  	in <= out + 4;
  end


endmodule

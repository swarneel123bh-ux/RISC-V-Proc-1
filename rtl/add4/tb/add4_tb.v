`timescale 1ns / 1ps

module add4_tb ();

	reg [31:0] in;
	wire [31:0] out;
	add4 uut(
		.in(in),
		.out(out)
	);

	initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/add4_tb.vcd");
      $dumpvars(0, add4_tb);
    end
    in = 0; #10;
    in = 10; #10;
    #100;
    $finish;
  end
endmodule

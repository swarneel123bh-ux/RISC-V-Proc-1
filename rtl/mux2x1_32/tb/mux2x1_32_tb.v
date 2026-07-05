`timescale 1ns / 1ps
module mux2x1_32_tb ();

	reg sel;
	reg [31:0] in1, in2;
	wire [31:0] out;
	mux2x1_32 uut(
		.in1(in1), .in2(in2), .sel(sel), .out(out)
	);

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/mux2x1_32_tb.vcd");
      $dumpvars(0, mux2x1_32_tb);
    end

    in1 = 10;
    in2 = 11;
    sel = 0;

    #10;

    sel = 1;

    #10;

    #100;
    $finish;
  end
endmodule

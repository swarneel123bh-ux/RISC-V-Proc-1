`timescale 1ns / 1ps

module proc();

  reg clk;

  reg pc;

  reg [31:0] instrs[100];

  inital begin
    clk = 0;
    pc = 0;
  end

  always begin  
    #1;
    clk = ~clk;
    pc += 4;
  end



endmodule

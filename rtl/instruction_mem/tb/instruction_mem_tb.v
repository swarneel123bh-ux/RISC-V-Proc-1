`timescale 1ns / 1ps

module instruction_mem_tb ();
  reg  [31:0] addr;
  wire [31:0] instr;
  integer     k;
  integer     errors = 0;

  // Golden reference: the same image the DUT loads.
  // (Sizing to 1024 to match the module's default array; bump if DEPTH grows past it.)
  reg [31:0] refmem [0:1023];

  instruction_mem #(.SYNC(0)) DUT (.clk(1'b0), .addr(addr), .instr(instr));

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/instruction_mem_tb.vcd");
      $dumpvars(0, instruction_mem_tb);
    end

    $readmemh("../../software/rom/program.hex", refmem);
    $display("DEPTH=%0d AW=%0d", DUT.DEPTH, DUT.AW);

    // Fetch every in-range word and compare against the reference.
    for (k = 0; k < DUT.DEPTH; k = k + 1) begin
      addr = k << 2;              // byte address of word k
      #1;                         // async read: let it settle
      if (instr !== refmem[k]) begin
        errors = errors + 1;
        $display("FAIL word[%0d] @%08h: got %08h  exp %08h", k, addr, instr, refmem[k]);
      end else begin
        $display("PASS word[%0d] @%08h = %08h", k, addr, instr);
      end
    end

    // Byte-offset bits must be ignored: addr+0 and addr+3 hit the same word.
    addr = 32'h0; #1; begin : chk
      reg [31:0] w0;
      w0 = instr;
      addr = 32'h3; #1;
      if (instr !== w0) begin
        errors = errors + 1;
        $display("FAIL byte-offset: addr+3=%08h != addr+0=%08h", instr, w0);
      end else
        $display("PASS byte-offset ignored (%08h)", w0);
    end

    if (errors == 0) $display("RESULT: PASS (%0d words)", DUT.DEPTH);
    else             $display("RESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule

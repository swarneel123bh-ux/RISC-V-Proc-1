`timescale 1ns / 1ps

// Testbench for vram.v -- dual-port framebuffer RAM.
// Checks: byte (SB) writes land in the correct pixel lane; word (SW) writes;
// CPU async read; scanout read sees the same array; scanout is independent
// of the CPU port in the same cycle; pixel (x,y) maps to the right word/lane.
// Self-checking: prints [PASS]/[FAIL] per check and a final verdict line.

module vram_tb;
  localparam PIX_W = 160;
  localparam PIX_H = 120;

  reg         clk;
  reg  [31:0] cpu_addr;
  reg  [31:0] cpu_wdata;
  reg  [3:0]  cpu_wstrb;
  reg         cpu_read;
  wire [31:0] cpu_rdata;
  reg  [31:0] scan_widx;
  wire [31:0] scan_rdata;

  integer pass = 0, fail = 0;

  initial clk = 0;
  always #5 clk = ~clk;

  vram #(.PIX_W(PIX_W), .PIX_H(PIX_H)) dut (
    .clk(clk),
    .cpu_addr(cpu_addr),
    .cpu_wdata(cpu_wdata),
    .cpu_wstrb(cpu_wstrb),
    .cpu_read(cpu_read),
    .cpu_rdata(cpu_rdata),
    .scan_widx(scan_widx),
    .scan_rdata(scan_rdata)
  );

  task check32;
    input [255:0] name;
    input [31:0]  got;
    input [31:0]  exp;
    begin
      if (got === exp) begin
        pass = pass + 1;
        $display("[PASS] %0s: 0x%08h", name, got);
      end else begin
        fail = fail + 1;
        $display("[FAIL] %0s: got 0x%08h exp 0x%08h", name, got, exp);
      end
    end
  endtask

  // one-clock strobed write, strobes cleared afterward
  task wr;
    input [31:0] addr;
    input [31:0] data;
    input [3:0]  strb;
    begin
      @(negedge clk);
      cpu_addr = addr; cpu_wdata = data; cpu_wstrb = strb;
      @(posedge clk);
      @(negedge clk);
      cpu_wstrb = 4'b0000;
    end
  endtask

  task rd;
    input  [31:0] addr;
    output [31:0] data;
    begin
      cpu_addr = addr; cpu_read = 1'b1; #1; data = cpu_rdata;
    end
  endtask

  reg [31:0] v;

  // helper: pixel (x,y) -> byte offset and the SB that writes it white
  task set_pixel;                     // writes 0xFF at pixel (x,y)
    input [31:0] x;
    input [31:0] y;
    reg [31:0] off;
    reg [1:0]  lane;
    begin
      off  = y*PIX_W + x;             // byte offset
      lane = off[1:0];
      // emulate what mem_wrapper does for an SB: byte in its lane, 1-hot strobe
      case (lane)
        2'd0: wr({off[31:2],2'b00}, 32'h000000FF, 4'b0001);
        2'd1: wr({off[31:2],2'b00}, 32'h0000FF00, 4'b0010);
        2'd2: wr({off[31:2],2'b00}, 32'h00FF0000, 4'b0100);
        2'd3: wr({off[31:2],2'b00}, 32'hFF000000, 4'b1000);
      endcase
    end
  endtask

  initial begin
    cpu_addr=0; cpu_wdata=0; cpu_wstrb=0; cpu_read=0; scan_widx=0;
    #2;

    // 1. full-word write + read
    wr(32'h00000000, 32'hAABBCCDD, 4'b1111);
    rd(32'h00000000, v);
    check32("SW word0", v, 32'hAABBCCDD);

    // 2. byte write isolates its lane (clear word, set lane 2)
    wr(32'h00000010, 32'h00000000, 4'b1111);
    wr(32'h00000010, 32'h00FF0000, 4'b0100);
    rd(32'h00000010, v);
    check32("SB lane2 only", v, 32'h00FF0000);

    // 3. pixel mapping: pixel (0,0) is lane0 of word0
    wr(32'h00000000, 32'h00000000, 4'b1111);
    set_pixel(0, 0);
    rd(32'h00000000, v);
    check32("pixel(0,0)->lane0", v, 32'h000000FF);

    // 4. pixel (3,0) is lane3 of word0 (4 px/word)
    set_pixel(3, 0);
    rd(32'h00000000, v);
    check32("pixel(3,0)->lane3 (with 0,0)", v, 32'hFF0000FF);

    // 5. pixel (1,1): offset = 1*160+1 = 161 = word40 lane1
    wr(32'h000000A0, 32'h00000000, 4'b1111);   // word40 = byte 160
    set_pixel(1, 1);
    rd(32'h000000A0, v);
    check32("pixel(1,1)->word40 lane1", v, 32'h0000FF00);

    // 6. scanout sees the same array (word0 from step 4)
    scan_widx = 32'd0; #1;
    check32("scan word0 == cpu word0", scan_rdata, 32'hFF0000FF);

    // 7. scanout independent of a concurrent CPU write to a different word
    @(negedge clk);
    cpu_addr=32'h00000200; cpu_wdata=32'h12345678; cpu_wstrb=4'b1111; // write word128
    scan_widx=32'd0;                                                   // scan word0
    #1;
    check32("scan word0 during cpu write elsewhere", scan_rdata, 32'hFF0000FF);
    @(posedge clk); @(negedge clk); cpu_wstrb=4'b0000;
    scan_widx=32'd128; #1;
    check32("scan sees the just-written word128", scan_rdata, 32'h12345678);

    $display("");
    $display("==== vram_tb: %0d passed, %0d failed ====", pass, fail);
    if (fail==0) $display("ALL TESTS PASSED");
    else         $display("SOME TESTS FAILED");
    $finish;
  end

  initial begin #100000; $display("[FAIL] timeout"); $finish; end
endmodule

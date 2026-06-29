`timescale 1ns / 1ps

module uart_tb();
  reg         clk;
  reg         rst;
  reg  [31:0] addr;
  reg  [31:0] wdata;
  reg         we;
  reg         re;
  reg         cs;
  wire [31:0] rdata;
  wire        rx_ready;

  uart UART(
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .wdata(wdata),
    .we(we),
    .re(re),
    .cs(cs),
    .rdata(rdata),
    .rx_ready(rx_ready)
  );

  always #5 clk = ~clk;

  task uart_write;
    input [31:0] address;
    input [7:0]  byte_val;
    begin
      @(negedge clk);
      addr  = address;
      wdata = {24'h0, byte_val};
      we    = 1;
      re    = 0;
      cs    = 1;
      @(posedge clk);
      #1;
      we = 0;
      cs = 0;
    end
  endtask

  task uart_read;
    input [31:0] address;
    begin
      @(negedge clk);
      addr  = address;
      wdata = 32'h0;
      we    = 0;
      re    = 1;
      cs    = 1;
      @(posedge clk);
      #1;
      re = 0;
      cs = 0;
    end
  endtask

  /* poll UART_STATUS and read RX when ready */
  task wait_and_read_rx;
    begin : poll
      reg timeout;
      integer i;
      timeout = 0;
      for (i = 0; i < 5000000 && !timeout; i = i + 1) begin
        uart_read(32'hFFFF0008);
        if (rdata[1]) begin
          uart_read(32'hFFFF0004);
          $display("[TB] RX got: '%c' (0x%02X)", rdata[7:0], rdata[7:0]);
          timeout = 1;
        end else begin
          @(posedge clk);
        end
      end
      if (!timeout)
        $display("[TB] RX timeout — no key pressed");
    end
  endtask

  initial begin
    $dumpfile("build/uart_tb.vcd");
    $dumpvars(0, uart_tb);
    $uart_init();

    clk   = 0;
    rst   = 1;
    addr  = 0;
    wdata = 0;
    we    = 0;
    re    = 0;
    cs    = 0;

    repeat(2) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    /* TX test — print a message */
    uart_write(32'hFFFF0000, "H");
    uart_write(32'hFFFF0000, "e");
    uart_write(32'hFFFF0000, "l");
    uart_write(32'hFFFF0000, "l");
    uart_write(32'hFFFF0000, "o");
    uart_write(32'hFFFF0000, " ");
    uart_write(32'hFFFF0000, "W");
    uart_write(32'hFFFF0000, "o");
    uart_write(32'hFFFF0000, "r");
    uart_write(32'hFFFF0000, "l");
    uart_write(32'hFFFF0000, "d");
    uart_write(32'hFFFF0000, "\n");

    /* RX test — wait for keypress, echo it back */
    $display("[TB] Press a key...");
    wait_and_read_rx();

    repeat(100) @(posedge clk);
    $finish;
  end

endmodule

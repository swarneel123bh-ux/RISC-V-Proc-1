module addr_decode_tb ();

  reg [31:0] addr;
  reg [31:0] ram_rdata;
  reg [31:0] uart_rdata;
  wire cs_ram;
  wire cs_uart;
  wire [31:0] rdata;
  addr_decode uut (
      addr,
      ram_rdata,
      uart_rdata,
      cs_ram,
      cs_uart,
      rdata
  );

  initial begin
    $dumpfile("build/addr_decode_tb.vcd");
    $dumpvars(0, addr_decode_tb);
    addr = 32'h00000010;  // valid
    ram_rdata = 32'hFEEDBEEF;
    uart_rdata = 32'h00001111;
    #10;
    addr = 32'h000F0000;  // Invalid
    ram_rdata = 32'hBEEDBEEB;
    uart_rdata = 32'h00001111;
    #10;
    addr = 32'hFFFF0004;  // UART
    ram_rdata = 32'hBEEDBEEB;
    uart_rdata = 32'h00001111;
    #10;
    $finish;
  end



endmodule

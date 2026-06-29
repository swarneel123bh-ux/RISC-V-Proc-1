module addr_decode (
    input  wire [31:0] addr,
    input  wire [31:0] ram_rdata,
    input  wire [31:0] uart_rdata,
    output wire        cs_ram,
    output wire        cs_uart,
    output reg  [31:0] rdata
);

  // Address Decoding
  // RAM: 0x00000000 to 0x0000FFFF (Upper 16 bits are 0)
  assign cs_ram  = (addr[31:16] == 16'h0000);

  // UART: 0xFFFF0000 to 0xFFFF000F (Upper 16 bits are 0xFFFF)
  // Note: Specific UART register decoding (0x00, 0x04, 0x08) is assumed 
  // to be handled internally by the uart.v module.
  assign cs_uart = (addr[31:16] == 16'hFFFF);

  // Read Data Multiplexer
  always @(*) begin
    if (cs_ram) begin
      rdata = ram_rdata;
    end else if (cs_uart) begin
      rdata = uart_rdata;
    end else begin
      $display("Unmapped memory address 0x%08hx\n", addr);
      rdata = 32'hDEADBEEF;
    end
  end

endmodule

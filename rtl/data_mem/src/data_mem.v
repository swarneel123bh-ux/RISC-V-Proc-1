`timescale 1ns / 1ps

module data_mem #(
  parameter DEPTH_BYTES = 4096,                       // real allocation (bump as needed)
  parameter INIT_FILE   = ""                          // "" = no preload
) (
  input  wire        clk,
  input  wire        rstb,
  input  wire [31:0] addr,        // byte address
  input  wire [31:0] wdata,       // write data (right-justified)
  input  wire [3:0]  wstrb,       // byte-write enables: bit i set means wdata word written from (addr + i) to (addr + i + 3)
  input  wire        mem_read,    // read enable
  output wire [31:0] rdata        // raw 32-bit word at addr (aligned)
);

	// Cannot allocate all 4Gigs of memory, use byte-depth to get number of words in the array
	localparam WORDS = DEPTH_BYTES/4;
  localparam ARRAYWORDS = $clog2(WORDS);
	reg [31:0] int_mem [0 : WORDS - 1];
	wire [ARRAYWORDS-1:0] widx = addr[ARRAYWORDS+1 : 2];	// Word index
	integer i;

	// If initial memory file given
	initial begin
		if (INIT_FILE != "") begin
			$readmemh(INIT_FILE, int_mem);
		end
	end

	// MMIO decode
	wire is_uart = (addr >= 32'hFFFF0000);
	wire is_ram = ~is_uart;

	// RAM Array
	always @(posedge clk) begin
		if (wstrb[0]) int_mem[widx][7:0] <= wdata[7:0];
		if (wstrb[1]) int_mem[widx][15:8] <= wdata[15:8];
		if (wstrb[2]) int_mem[widx][23:16] <= wdata[23:16];
		if (wstrb[3]) int_mem[widx][31:24] <= wdata[31:24];
	end
	wire [31:0] ram_data = (mem_read & is_ram) ? int_mem[widx] : 32'h0;

	// UART instance
	wire uart_we = is_uart & (|wstrb);
	wire uart_re = is_uart & mem_read;
	wire [31:0] uart_rdata;
	wire uart_rx_ready;		// Unused in the uart module but available to expose later
	uart uartInst(
 		.clk(clk),
  	.rst(~rstb),				// UART module was active high
  	.addr(addr),
  	.wdata(wdata),
  	.we(uart_we),
  	.re(uart_re),
  	.cs(is_uart),
  	.rdata(uart_rdata),
  	.rx_ready(uart_rx_ready)
	);

	// Final output
	assign rdata = is_uart ? uart_rdata : ram_data;

endmodule

`timescale 1ns / 1ps

module data_mem //#(
  //parameter DEPTH_BYTES = 4096,                       // real allocation (bump as needed)
  //parameter INIT_FILE   = ""                          // "" = no preload )
(
	// Proc side ports
	input  wire        clk,
  input  wire        rstb,
  input  wire [31:0] addr,        // byte address
  input  wire [31:0] wdata,       // write data (right-justified)
  input  wire [3:0]  wstrb,       // byte-write enables: bit i set means wdata word written from (addr + i) to (addr + i + 3)
  input  wire        mem_read,    // read enable
  output wire [31:0] rdata,        // raw 32-bit word at addr (aligned)

  // Unified memory side ports
  output wire [31:0] umem_addr,
  output wire [31:0] umem_wdata,
  output wire [3:0]  umem_wstrb,
  output wire        umem_read,
  input  wire [31:0] umem_rdata
);

	// Cannot allocate all 4Gigs of memory, use byte-depth to get number of words in the array
	// localparam WORDS = DEPTH_BYTES/4;
  // localparam ARRAYWORDS = $clog2(WORDS);
	// reg [31:0] int_mem [0 : WORDS - 1];
	// wire [ARRAYWORDS-1:0] widx = addr[ARRAYWORDS+1 : 2];	// Word index
	// integer i;

	// // If initial memory file given
	// initial begin
	// 	if (INIT_FILE != "") begin
	// 		$readmemh(INIT_FILE, int_mem);
	// 	end
	// end
	//
	// Base Addresses of the devices
	localparam VRAMBASE = 32'hFFFE0000;
	localparam UARTBASE = 32'hFFFF0000;

	// MMIO decode
	wire is_uart = (addr >= UARTBASE);
	wire is_vram = ((addr >= VRAMBASE) && (addr < UARTBASE));
	wire is_ram = ~(is_uart | is_vram);

	// RAM Path (Umem)
	assign umem_addr = addr;
	assign umem_wdata = wdata;
	assign umem_wstrb = is_ram ? wstrb : 4'b0000;
	assign umem_read = is_ram & mem_read;

	// VRAM Instance
	wire [31:0] vram_addr = addr - VRAMBASE;
	wire [3:0] vram_wstrb = is_vram ? wstrb : 4'b0000;
	wire vram_read = is_vram & mem_read;
	wire [31:0] vram_rdata;
	vram vram_inst(
		.clk(clk),
		// CPU side ports
		.cpu_addr(vram_addr),
		.cpu_wdata(wdata),
		.cpu_wstrb(vram_wstrb),
		.cpu_read(vram_read),
		.cpu_rdata(vram_rdata),
		// Scanout side ports (for SDL)
		.scan_widx(32'h0),		// <- Need to expose to proc.v so that we can wire it to display.v
		.scan_rdata()					// <- Need to expose to proc.v so that we can wire it to display.v
	);


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
	assign rdata = 	is_uart ? uart_rdata :
									is_vram ? vram_rdata :
									umem_rdata;

endmodule

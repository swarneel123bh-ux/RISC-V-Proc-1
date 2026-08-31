`timescale 1ns / 1ps

module data_mem #(
  parameter DEPTH_BYTES = 4096,                       // real allocation (bump as needed)
  parameter INIT_FILE   = ""                          // "" = no preload )
)(
	// Proc side ports
	input  wire        clk,
  input  wire        rstb,
  input  wire [31:0] addr,          // byte address
  input  wire [31:0] wdata,         // write data (right-justified)
  input  wire [3:0]  wstrb,         // byte-write enables: bit i set means wdata word written from (addr + i) to (addr + i + 3)
  input  wire        mem_read,      // read enable
  output wire  [31:0] rdata,         // raw 32-bit word at addr (aligned)

  // Unified memory side ports
  output wire [31:0] umem_addr,
  output wire [31:0] umem_wdata,
  output wire [3:0]  umem_wstrb,
  output wire        umem_read,
  input  wire [31:0] umem_rdata
);

	// Base Addresses of the devices
	localparam VRAMBASE = 32'hFFFE0000;
	localparam UARTBASE = 32'hFFFF0000;

	// MMIO decode
	wire is_uart  = (addr >= UARTBASE);
	wire is_vram  = ((addr >= VRAMBASE) && (addr < UARTBASE));
	wire is_ram   = ~(is_uart | is_vram);

	reg sel_uart;
	reg sel_vram;
	reg sel_ram;


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
		// .rstb(rstb),
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

	always @(posedge clk or negedge rstb) begin
	  if (!rstb) begin
				sel_ram   <= 0;
				sel_uart  <= 0;
				sel_vram  <= 0;
		end else begin
	    sel_uart  <= is_uart; // <= (addr >= UARTBASE);
	    sel_vram  <= is_vram; // <= ((addr >= VRAMBASE) && (addr < UARTBASE));
	    sel_ram   <= is_ram;  // <=  ~(is_uart | is_vram);
		end
	end

	// Final output
	assign rdata =
	sel_uart  ? uart_rdata :
	sel_vram  ? vram_rdata :
	sel_ram   ? umem_rdata :
	32'h0;

	// Swapped version to confirm failure when not registerd
	// assign rdata =
	// is_uart  ? uart_rdata :
	// is_vram  ? vram_rdata :
	// is_ram   ? umem_rdata :
	// 32'h0;

	// Swapped version to confirm failure when wrongly registered
	// assign rdata =
	// sel_uart  ? vram_rdata :
	// sel_vram  ? uart_rdata :
	// sel_ram   ? umem_rdata :
	// 32'h0;

endmodule

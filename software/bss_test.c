#define UART_TX     (*(volatile unsigned int *)0xFFFF0000)
#define UART_RX     (*(volatile unsigned int *)0xFFFF0004)
#define UART_STATUS (*(volatile unsigned int *)0xFFFF0008)
#define UART_CTL 		(*(volatile unsigned int *)0xFFFF000C)

#define UART_ST_RX_BUF_EMPTY  0x00000001  // status_reg[0]
#define UART_ST_RX_BUF_FULL   0x00000002  // status_reg[1]
#define UART_ST_TX_BUF_EMPTY  0x00000004  // status_reg[2]
#define UART_ST_TX_BUF_FULL   0x00000008  // status_reg[3]
#define UART_ST_RX_FRM_ERROR  0x00000010  // status_reg[4]
#define UART_ST_IRQ_ENABLE    0x00000020  // status_reg[5]
#define UART_ST_RX_RESERVED   0x00000040  // status_reg[6]
#define UART_ST_RX_OVERRUN    0x00000080  // status_reg[7]

void putchar(char c) {
	while (UART_STATUS & UART_ST_TX_BUF_FULL) {}
	UART_TX = (unsigned int)c;
}

void putstr(const char *s) {
	while (*s)  {
		putchar(*s++);
	}
}

void puthex(unsigned int v){
	putchar('0');
	putchar('x');
	for (int i = 28; i >= 0; i -= 4) {
		putchar("0123456789ABCDEF"[(v >> i) & 0xF]);
	}
}

// Uninitialized globals
// bss should be zerod. So we can have these
int counter;
char buf[16];
int zero_init = 0;


int main(void) {
	putstr("counter="); puthex((unsigned int) counter); putchar('\n');
	putstr("zero_init="); puthex((unsigned int) zero_init); putchar('\n');

	int sum = 0;
	for (int i = 0; i < 16; i ++) {
		sum += buf[i];
	}

	putstr("sum(buf)="); puthex((unsigned int)sum); putchar('\n');
	while (1);
}

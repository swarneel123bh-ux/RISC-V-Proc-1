#define UART_TX (*(volatile unsigned int *)0xFFFF0000)

void putchar(char c) {
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

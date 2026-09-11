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
	while (UART_STATUS & UART_ST_TX_BUF_FULL) ;;	// Spin wait till buffer is not full
	UART_TX = (unsigned int)c;
}

char getchar(void) {
  while (UART_STATUS & UART_ST_RX_BUF_EMPTY) { }
  return (char)(UART_RX & 0xFF);
}

void print_str(const char *s) {
  while (*s) putchar(*s++);
}

void print_int(unsigned int n) {
  char buf[12];
  int i = 0;
  if (n == 0) { putchar('0'); return; }
  while (n > 0) {
    unsigned int q = 0, rem = n;
    while (rem >= 10) { rem -= 10; q++; }   // rem = n%10, q = n/10 by subtraction
    buf[i++] = '0' + rem;
    n = q;
  }
  while (i > 0) putchar(buf[--i]);
}

void bubblesort(int* arr, int size) {
	int temp = 0;
	for (int i = 0; i < size; i ++){
		for (int j = 0; j < size; j ++) {
			if (arr[j] > arr[i]) {
				temp = arr[i];
				arr[i] = arr[j];
				arr[j] = temp;
			}
		}
	}
}

int main() {
	int arr[] = {1, 4, 2, 6, 8, 3, 5, 7, 9, 10};
	int size = 10;
	print_str("Before: ");
	for (int i = 0; i < size; i ++) {
		print_int(arr[i]);
		print_str(" ");
		putchar(' ');
	}
	print_str("\nAfter: ");
	bubblesort(arr, size);
	for (int i = 0; i < size; i ++) {
		print_int(arr[i]);
		print_str(" ");
		putchar(' ');
	}
	putchar(0x04);
	while (1);
	return 0;
}

/*int main() {
  putchar('A');
  print_int(42);
  putchar('B');
  while (1);
  }*/

// int main() {
//   int arr[10];
//   arr[0]=1; arr[1]=4; arr[2]=2; arr[3]=6; arr[4]=8;
//   arr[5]=3; arr[6]=5; arr[7]=7; arr[8]=9; arr[9]=10;
//   int size = 10;
//   for (int i = 0; i < size; i++) { print_int(arr[i]); putchar(' '); }
//   bubblesort(arr, size);
//   for (int i = 0; i < size; i++) { print_int(arr[i]); putchar(' '); }
//   while (1);
// }

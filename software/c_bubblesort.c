#define UART_TX     (*(volatile unsigned int *)0xFFFF0000)
#define UART_RX     (*(volatile unsigned int *)0xFFFF0004)
#define UART_STATUS (*(volatile unsigned int *)0xFFFF0008)

void putchar(char c) {
  UART_TX = (unsigned char)c;      // tx_ready (bit0) is always 1 in your UART
}

char getchar(void) {
  while (!(UART_STATUS & 0x2)) { }  // spin until rx_ready (bit1)
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

/*int main() {
	int arr[] = {1, 4, 2, 6, 8, 3, 5, 7, 9, 10};
	int size = 10;
	//print_str("Before: ");
	for (int i = 0; i < size; i ++) {
		print_int(arr[i]);
		// print_str(" ");
		putchar(' ');
	}
	//print_str("\nAfter: ");
	bubblesort(arr, size);
	for (int i = 0; i < size; i ++) {
		print_int(arr[i]);
		//print_str(" ");
		putchar(' ');
	}
	while (1);
	return 0;
	}*/

/*int main() {
  putchar('A');
  print_int(42);
  putchar('B');
  while (1);
  }*/

int main() {
  int arr[10];
  arr[0]=1; arr[1]=4; arr[2]=2; arr[3]=6; arr[4]=8;
  arr[5]=3; arr[6]=5; arr[7]=7; arr[8]=9; arr[9]=10;
  int size = 10;
  for (int i = 0; i < size; i++) { print_int(arr[i]); putchar(' '); }
  bubblesort(arr, size);
  for (int i = 0; i < size; i++) { print_int(arr[i]); putchar(' '); }
  while (1);
}

#define UART_TX     (*(volatile unsigned int *)0xFFFF0000)
#define UART_RX     (*(volatile unsigned int *)0xFFFF0004)
#define UART_STATUS (*(volatile unsigned int *)0xFFFF0008)

#define RX_READY  0x2          // STATUS bit1 = rx_ready
#define TX_READY  0x1          // STATUS bit0 = tx_ready (always 1 here)

void putchar(char c) {
  UART_TX = (unsigned int)c;
}

char getchar(void) {
  while ((UART_STATUS & RX_READY) == 0) {
    // spin until a byte is latched
  }
  return (char)(UART_RX & 0xFF);   // reading UART_RX clears rx_ready in hw
}

int main(void) {
  for (;;) {
    char c = getchar();
    putchar(c);
    if (c == '\r') putchar('\n');
  }
  return 0;
}

#define UART_TX     (*(volatile unsigned int *)0xFFFF0000)
#define VRAM        ((volatile unsigned char *)0xFFFE0000)

void putchar(char c) { UART_TX = (unsigned int)c; }

void puthex(unsigned int v) {
  putchar('0'); putchar('x');
  for (int i = 28; i >= 0; i -= 4)
    putchar("0123456789ABCDEF"[(v >> i) & 0xF]);
}

int main(void) {
  // 1. byte write/read at a few offsets, incl. non-aligned lanes
  VRAM[0]   = 0xAA;
  VRAM[1]   = 0xBB;
  VRAM[2]   = 0xCC;
  VRAM[3]   = 0xDD;
  VRAM[7]   = 0x42;                 // word1, lane3
  VRAM[160] = 0xFF;                 // pixel (0,1): offset 160, word40 lane0

  // 2. read them back, print as hex over UART
  putchar('[');
  puthex(VRAM[0]);   putchar(' ');
  puthex(VRAM[1]);   putchar(' ');
  puthex(VRAM[2]);   putchar(' ');
  puthex(VRAM[3]);   putchar(' ');
  puthex(VRAM[7]);   putchar(' ');
  puthex(VRAM[160]); putchar(']'); putchar('\n');

  // 3. word-granularity readback (proves 4 pixels/word packing)
  volatile unsigned int *vw = (volatile unsigned int *)0xFFFE0000;
  puthex(vw[0]);   putchar('\n');   // expect 0xDDCCBBAA (LE: byte0=AA..byte3=DD)

  for (;;) {}
}

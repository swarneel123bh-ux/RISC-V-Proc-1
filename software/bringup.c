// software/bringup.c
// Interactive hardware bring-up monitor. HARNESS - not my code.
// Single-character commands over UART. No MUL/DIV (no M ext), no CSR,
// so: hex output only, and no cycle measurement is possible.

#define UART_BASE 0xFFFF0000u   // <-- FILL IN from data_mem.v
#define UART ((volatile unsigned int *)UART_BASE)
#define U_TX  0
#define U_RX  1
#define U_ST  2
#define U_CTL 3

#define ST_RX_EMPTY  (1u << 0)
#define ST_RX_FULL   (1u << 1)
#define ST_TX_EMPTY  (1u << 2)
#define ST_TX_FULL   (1u << 3)
#define ST_FRAME_ERR (1u << 4)
#define ST_OVERRUN   (1u << 7)

#define CTL_CLR_FE   (1u << 0)
#define CTL_CLR_OV   (1u << 1)

#define VRAM ((volatile unsigned int *)0xFFFE0000u)

static void putch(char c) {
  while (UART[U_ST] & ST_TX_FULL) { }
  UART[U_TX] = (unsigned int)(unsigned char)c;
}

static void puts_(const char *s) {
  while (*s) putch(*s++);
}

static void nl(void) {
  putch(0x0D);
  putch(0x0A);
}

static void put_nib(unsigned int n) {
  n &= 0xF;
  putch(n < 10 ? (char)('0' + n) : (char)('A' + n - 10));
}

static void put_hex32(unsigned int v) {
  int i;
  for (i = 28; i >= 0; i -= 4) put_nib(v >> i);
}

static void put_hex8(unsigned int v) {
  put_nib(v >> 4);
  put_nib(v);
}

static int rx_ready(void) {
  return !(UART[U_ST] & ST_RX_EMPTY);
}

static char getch(void) {
  while (!rx_ready()) { }
  return (char)(UART[U_RX] & 0xFF);
}

static void field(const char *label, unsigned int v) {
  puts_(label);
  put_hex32(v);
  nl();
}

// ---- self-modify distance sweep -------------------------------------
// Writes 'addi a0,zero,0x5A' (0x05A00513) over a slot that originally
// holds 'addi a0,zero,0' (0x00000513), D instructions ahead of the sw,
// then falls straight through it. Restores the slot afterwards so the
// command is re-runnable.
#define SMTEST(D, out)                        \
  __asm__ volatile (                          \
    "  la   t0, 1f\n"                         \
    "  li   t1, 0x05A00513\n"                 \
    "  li   t2, 0x00000513\n"                 \
    "  sw   t1, 0(t0)\n"                      \
    "  .rept " #D "\n"                        \
    "  nop\n"                                 \
    "  .endr\n"                               \
    "1:\n"                                    \
    "  addi a0, zero, 0\n"                    \
    "  sw   t2, 0(t0)\n"                      \
    "  mv   %0, a0\n"                         \
    : "=r"(out) : : "t0", "t1", "t2", "a0", "memory")

static void cmd_selfmod(void) {
  unsigned int r;
  puts_("selfmod distance sweep (5A=new, 00=stale)"); nl();
  SMTEST(0, r); puts_("  d0 "); put_hex8(r); nl();
  SMTEST(1, r); puts_("  d1 "); put_hex8(r); nl();
  SMTEST(2, r); puts_("  d2 "); put_hex8(r); nl();
  SMTEST(3, r); puts_("  d3 "); put_hex8(r); nl();
  SMTEST(4, r); puts_("  d4 "); put_hex8(r); nl();
  SMTEST(5, r); puts_("  d5 "); put_hex8(r); nl();
  SMTEST(6, r); puts_("  d6 "); put_hex8(r); nl();
  puts_("  compare this table against iverilog"); nl();
}

// ---- subword / data array -------------------------------------------
static volatile unsigned char  buf8[8];
static volatile unsigned short buf16[4];
static volatile unsigned int   buf32[4];

static void chk(const char *tag, unsigned int got, unsigned int want) {
  puts_(tag);
  puts_(" got ");
  put_hex32(got);
  puts_(" want ");
  put_hex32(want);
  puts_(got == want ? "  ok" : "  FAIL");
  nl();
}

static void cmd_mem(void) {
  buf32[0] = 0x8899AABBu;
  chk("lw    ", buf32[0], 0x8899AABBu);
  buf8[0] = 0x81; buf8[1] = 0x7E; buf8[2] = 0xFF; buf8[3] = 0x01;
  chk("lbu b0", buf8[0], 0x81u);
  chk("lbu b2", buf8[2], 0xFFu);
  chk("lb  b0", (unsigned int)(int)(signed char)buf8[0], 0xFFFFFF81u);
  chk("lb  b1", (unsigned int)(int)(signed char)buf8[1], 0x0000007Eu);
  buf16[0] = 0x8123; buf16[1] = 0x7EDC;
  chk("lhu h0", buf16[0], 0x8123u);
  chk("lh  h0", (unsigned int)(int)(short)buf16[0], 0xFFFF8123u);
  chk("lh  h1", (unsigned int)(int)(short)buf16[1], 0x00007EDCu);
}

// ---- vram (write/read-back only: no HDMI until Phase 6) -------------
static void cmd_vram(void) {
  VRAM[0]    = 0x11223344u;
  VRAM[1]    = 0xAABBCCDDu;
  VRAM[4799] = 0x0F1E2D3Cu;
  chk("vram0 ", VRAM[0],    0x11223344u);
  chk("vram1 ", VRAM[1],    0xAABBCCDDu);
  chk("vramN ", VRAM[4799], 0x0F1E2D3Cu);
}

static void cmd_status(void) {
  unsigned int s = UART[U_ST];
  field("STATUS ", s);
  puts_("  E="); put_nib(s & 1u);
  puts_(" F=");  put_nib((s >> 1) & 1u);
  puts_(" TE="); put_nib((s >> 2) & 1u);
  puts_(" TF="); put_nib((s >> 3) & 1u);
  puts_(" FE="); put_nib((s >> 4) & 1u);
  puts_(" OV="); put_nib((s >> 7) & 1u);
  nl();
  field("CTL    ", UART[U_CTL]);
}

static void cmd_ack(void) {
  unsigned int c = UART[U_CTL];          // read-modify-write; W1C reads 0
  field("pre    ", UART[U_ST]);
  UART[U_CTL] = c | CTL_CLR_FE | CTL_CLR_OV;
  field("post   ", UART[U_ST]);
}

static void cmd_echo(void) {
  puts_("echo until ESC"); nl();
  for (;;) {
    char c = getch();
    if (c == 0x1B) { nl(); return; }
    putch(c);
  }
}

static void cmd_stress(void) {
  int i, j;
  for (i = 0; i < 64; i++) {
    for (j = 0; j < 26; j++) putch((char)('A' + j));
    nl();
  }
}

static void cmd_ceiling(void) {
  puts_("jumping to 0x4000 - expect apparent restart"); nl();
  __asm__ volatile ("li t0, 0x4000\n jalr zero, 0(t0)\n" ::: "t0");
}

static void banner(void) {
  nl();
  puts_("RV32 bringup rev1 - h for help"); nl();
}

static void help(void) {
  puts_("h help  s status  a ack-sticky  e echo  m mem"); nl();
  puts_("v vram  f selfmod  z tx-stress  k fetch-ceiling(DESTRUCTIVE)"); nl();
}

int main(void) {
  banner();
  for (;;) {
    char c;
    putch('>');
    c = getch();
    putch(c);
    nl();
    switch (c) {
      case 'h': help();         break;
      case 's': cmd_status();   break;
      case 'a': cmd_ack();      break;
      case 'e': cmd_echo();     break;
      case 'm': cmd_mem();      break;
      case 'v': cmd_vram();     break;
      case 'f': cmd_selfmod();  break;
      case 'z': cmd_stress();   break;
      case 'k': cmd_ceiling();  break;
      default:  puts_("?"); nl(); break;
    }
  }
}

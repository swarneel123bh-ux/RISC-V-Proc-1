// branch_bench.c -- branch-heavy benchmark to compare predictor schemes.
//
// Mixes three branch behaviours so state-skipping vs saturating counters
// actually diverge (clean loops alone make them tie):
//   1. tight predictable loops        (both schemes nail these)
//   2. data-dependent if/else inside   (irregular; the discriminator)
//   3. an alternating pattern          (worst case for 1-step predictors)
//
// Ends by emitting EOT (0x04) to UART TX so the testbench can print the
// hardware cycle/branch/mispredict counters and $finish.
//
// No divide/modulo (RV32I has none; -nostdlib won't link __divsi3).

#define UART_TX (*(volatile unsigned int *)0xFFFF0000)

static void putchar(char c) { UART_TX = (unsigned int)c; }

static void puthex(unsigned int v) {
  putchar('0'); putchar('x');
  for (int i = 28; i >= 0; i -= 4)
    putchar("0123456789ABCDEF"[(v >> i) & 0xF]);
}

// simple deterministic PRNG (xorshift) -> data-dependent branches
static unsigned int rng_state = 0x1234567u;
static unsigned int rng(void) {
  unsigned int x = rng_state;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  rng_state = x;
  return x;
}

int main(void) {
  unsigned int acc = 0;
  int i, j;

  // ---- phase 1: predictable nested loops (both schemes ~perfect) ----
  for (i = 0; i < 200; i++) {
    for (j = 0; j < 20; j++) {
      acc += (unsigned)(i ^ j);            // just work; the loop branches matter
    }
  }

  // ---- phase 2: data-dependent branch (the discriminator) ----
  // ~50/50 taken based on RNG bit -> hard for any 2-bit scheme, and the
  // state-skip vs saturating difference shows up here.
  for (i = 0; i < 4000; i++) {
    unsigned int r = rng();
    if (r & 1) acc += r;                   // taken/not-taken pseudo-randomly
    else       acc ^= r;
    if ((r & 6) == 6) acc += 3;            // rarer taken pattern
  }

  // ---- phase 3: alternating branch (T,NT,T,NT,...) ----
  // Pathological for single-step predictors: they flip every time.
  for (i = 0; i < 4000; i++) {
    if (i & 1) acc += 7;                   // strictly alternating
    else       acc -= 3;
  }

  // ---- phase 4: nested loop with early-exit (mix) ----
  for (i = 0; i < 500; i++) {
    for (j = 0; j < 40; j++) {
      acc += (unsigned)j;
      if ((acc & 0x3F) == 0) break;        // data-dependent early exit
    }
  }

  putchar('A'); putchar('C'); putchar('C'); putchar('=');
  puthex(acc);
  putchar('\n');

  putchar(0x04);                           // EOT: signal testbench to report
  for (;;) { }
}

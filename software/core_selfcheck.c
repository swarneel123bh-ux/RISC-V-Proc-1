/* core_selfcheck.c — RV32 core state checker
 *
 * Claude-authored. Requirement is Swarneel's; design and code are not.
 * See HANDOFF s1.authorship.
 *
 * WHY THIS EXISTS
 *   There is no instruction-set simulator and no saved register dump, so
 *   after an RTL change there is nothing to diff against. This program
 *   checks the core against compile-time constants instead.
 *
 * WHAT IT CANNOT DO
 *   It runs on the machine it is testing. It reports THAT something broke
 *   and roughly where; it never names the first divergent instruction. If
 *   the pipeline is broken badly enough, the reporting path breaks too and
 *   the run looks clean. Always do a -DFORCE_FAIL=<id> run first and
 *   confirm that id is reported. This is not a substitute for the ISS.
 *
 * TEST ID RANGES — stable interface, append only, never renumber.
 *   100-199  Tier 1: memory subsystem (the WRITE_MODE0 blast radius)
 *   200-299  Tier 2: pipeline control (historically broken, s8)
 *   300-399  Tier 3: runtime and linker sections
 *
 * NOT COVERED ON PURPOSE
 *   funct3 x offset load/store combinations. subword_test.s owns that at
 *   13/13; duplicating it creates two places to maintain one truth.
 *
 * BUILD   make prog PROG=core_selfcheck
 * OUTPUT  one line per failure, then a summary. Silence before the
 *         summary means all passed.
 */

/* ------------------------------------------------------------------ */
/* UART                                                                */
/* ------------------------------------------------------------------ */

// # temporarily, in core_selfcheck.c, replace the #ifndef block with:
// #define FORCE_FAIL 204

/* FILL THIS IN. Not recorded in the handoff — read it off data_mem.v's
   region decode. Registers are WORD ACCESS ONLY (uart.mmio): a byte
   access to BASE+5 decodes as nothing and silently does nothing. */
#define UART_BASE  0xFFFF0000u

#define UART_TX    (*(volatile unsigned int *)(UART_BASE +  0))
#define UART_ST    (*(volatile unsigned int *)(UART_BASE +  8))

/* Frozen STATUS layout, uart.status. Bits 0-7 are hardcodable by design. */
#define ST_TX_FULL (1u << 3)

/* Every byte goes through here. ledger.firmware: a '\n' store that
   bypassed the tx_buf_full check dropped every newline and read as a
   cosmetic formatting oddity. */
static void putch(char c) {
  while (UART_ST & ST_TX_FULL) { }
  UART_TX = (unsigned int)(unsigned char)c;
}

static void puts_(const char *s) {
  while (*s) putch(*s++);
}

/* Hex only. No decimal anywhere in this file: RV32I has no MUL/DIV and
   __divsi3/__modsi3 are not linked under -nostdlib. */
static void puthex(unsigned int v) {
  int i;
  for (i = 7; i >= 0; i--) {
    unsigned int n = (v >> (i * 4)) & 0xFu;
    putch(n < 10u ? (char)('0' + n) : (char)('A' + n - 10u));
  }
}

/* ------------------------------------------------------------------ */
/* Results block                                                       */
/* ------------------------------------------------------------------ */

static unsigned int tests_run  = 0;
static unsigned int fails      = 0;
static unsigned int first_fail = 0;

/* Harness mutation. -DFORCE_FAIL=204 breaks exactly check 204 and
   nothing else. Id 0 is never used, so 0 means disabled. */
#ifndef FORCE_FAIL
#define FORCE_FAIL 0
#endif

static void report(unsigned int id, unsigned int got, unsigned int exp) {
  puts_("F ");
  puthex(id);
  puts_(" G ");
  puthex(got);
  puts_(" E ");
  puthex(exp);
  putch('\r');
  putch('\n');
}

/* Deliberately not a halting assert: one run is expensive, so a first
   failure must not cost you every later result. Kept small — compare,
   count, branch — so the harness does not itself lean on the hazard
   logic it is testing. */
#define CHECK(id, got, exp)                             \
  do {                                                  \
    unsigned int _g = (unsigned int)(got);              \
    unsigned int _e = (unsigned int)(exp);              \
    if ((id) == FORCE_FAIL) _g = ~_g;                   \
    tests_run++;                                        \
    if (_g != _e) {                                     \
      fails++;                                          \
      if (first_fail == 0) first_fail = (id);           \
      report((id), _g, _e);                             \
    }                                                   \
  } while (0)

/* ------------------------------------------------------------------ */
/* Tier 1 — memory subsystem                                           */
/*                                                                     */
/* This is the tier that justifies the program. The data port's         */
/* behaviour on a write cycle moved with the WRITE_MODE0 fix, and a     */
/* RAW-through-memory at short instruction distance is where that       */
/* shows. Distances are asm because they are the point; everything      */
/* else here is volatile C, because the memory does not care which      */
/* instruction issued the store and asm would only obscure it.          */
/* ------------------------------------------------------------------ */

static volatile unsigned int m_a;          /* .bss */
static volatile unsigned int m_b;
static volatile unsigned int m_lane;
static volatile unsigned int m_arr[64];

static unsigned int st_ld_d0(unsigned int v) {
  unsigned int out;
  asm volatile(
    "sw %1, 0(%2)\n\t"
    "lw %0, 0(%2)\n\t"
    : "=&r"(out)
    : "r"(v), "r"(&m_a)
    : "memory");
  return out;
}

static unsigned int st_ld_d1(unsigned int v) {
  unsigned int out;
  asm volatile(
    "sw %1, 0(%2)\n\t"
    "nop\n\t"
    "lw %0, 0(%2)\n\t"
    : "=&r"(out)
    : "r"(v), "r"(&m_a)
    : "memory");
  return out;
}

static unsigned int st_ld_d2(unsigned int v) {
  unsigned int out;
  asm volatile(
    "sw %1, 0(%2)\n\t"
    "nop\n\t"
    "nop\n\t"
    "lw %0, 0(%2)\n\t"
    : "=&r"(out)
    : "r"(v), "r"(&m_a)
    : "memory");
  return out;
}

static unsigned int st_ld_d3(unsigned int v) {
  unsigned int out;
  asm volatile(
    "sw %1, 0(%2)\n\t"
    "nop\n\t"
    "nop\n\t"
    "nop\n\t"
    "lw %0, 0(%2)\n\t"
    : "=&r"(out)
    : "r"(v), "r"(&m_a)
    : "memory");
  return out;
}

/* Store to one word, load from a different one, adjacent. Separates a
   genuine same-word forwarding fault from a broken port. */
static unsigned int st_ld_other(unsigned int v, unsigned int seed) {
  unsigned int out;
  m_b = seed;
  asm volatile(
    "sw %1, 0(%2)\n\t"
    "lw %0, 0(%3)\n\t"
    : "=&r"(out)
    : "r"(v), "r"(&m_a), "r"(&m_b)
    : "memory");
  return out;
}

static void tier1(void) {
  unsigned int i;
  volatile unsigned char *bp;
  volatile unsigned short *hp;

  /* 100-103: store -> load, same word, instruction distance 0..3 */
  CHECK(100, st_ld_d0(0x11223344u), 0x11223344u);
  CHECK(101, st_ld_d1(0x55667788u), 0x55667788u);
  CHECK(102, st_ld_d2(0x99AABBCCu), 0x99AABBCCu);
  CHECK(103, st_ld_d3(0xDDEEFF00u), 0xDDEEFF00u);

  /* 104: store -> load, different words, adjacent */
  CHECK(104, st_ld_other(0xDEADBEEFu, 0xFEEDFACEu), 0xFEEDFACEu);
  CHECK(105, m_a, 0xDEADBEEFu);

  /* 110-113: byte-lane isolation. Directly targets the chained-else-if
     bug, where SW with wstrb=4'b1111 wrote byte 0 only. Each case is
     reset first so a leaked lane cannot be masked by the previous one. */
  bp = (volatile unsigned char *)&m_lane;
  m_lane = 0xAABBCCDDu; bp[0] = 0x11; CHECK(110, m_lane, 0xAABBCC11u);
  m_lane = 0xAABBCCDDu; bp[1] = 0x22; CHECK(111, m_lane, 0xAABB22DDu);
  m_lane = 0xAABBCCDDu; bp[2] = 0x33; CHECK(112, m_lane, 0xAA33CCDDu);
  m_lane = 0xAABBCCDDu; bp[3] = 0x44; CHECK(113, m_lane, 0x44BBCCDDu);

  /* 114-115: halfword lanes */
  hp = (volatile unsigned short *)&m_lane;
  m_lane = 0xAABBCCDDu; hp[0] = 0x1234u; CHECK(114, m_lane, 0xAABB1234u);
  m_lane = 0xAABBCCDDu; hp[1] = 0x5678u; CHECK(115, m_lane, 0x5678CCDDu);

  /* 116: full word actually writes all four lanes */
  m_lane = 0x00000000u;
  m_lane = 0xFFFFFFFFu;
  CHECK(116, m_lane, 0xFFFFFFFFu);

  /* 120: write-after-write to the same word, back to back. The write
     port changed; last-write-wins is the property being checked. */
  m_a = 0x0000FFFFu;
  m_a = 0xFFFF0000u;
  CHECK(120, m_a, 0xFFFF0000u);

  /* 130-131: bulk retention. Not an isolation test — every store here
     is concurrent with an instruction fetch, which is unavoidable and
     not separable from software. It exercises the cross-port path
     without proving anything about it. */
  for (i = 0; i < 64u; i++) m_arr[i] = 0xA5A50000u + i;
  for (i = 0; i < 64u; i++) {
    if (m_arr[i] != (0xA5A50000u + i)) break;
  }
  CHECK(130, i, 64u);

  for (i = 0; i < 64u; i += 2u) m_arr[i] = 0x5A5A0000u + i;
  for (i = 0; i < 64u; i++) {
    unsigned int want = (i & 1u) ? (0xA5A50000u + i) : (0x5A5A0000u + i);
    if (m_arr[i] != want) break;
  }
  CHECK(131, i, 64u);
}

/* ------------------------------------------------------------------ */
/* Tier 2 — pipeline control                                           */
/*                                                                     */
/* All asm. Adjacency is the whole test; the compiler would reschedule  */
/* or delete C equivalents. Every case checks rs1 and rs2 SEPARATELY —  */
/* the uses_rs2 bug passed structural review and only a data check      */
/* caught it, and a swapped predicate pair partly cancels in a cycle    */
/* count (ledger.pipeline).                                             */
/* ------------------------------------------------------------------ */

static void tier2(void) {
  unsigned int a, b, r0, r1, r2, r3;

  /* 200: EX -> EX forwarding, consumer reads rs1 */
  asm volatile(
    "addi %0, zero, 5\n\t"
    "addi %1, %0, 3\n\t"
    : "=&r"(a), "=&r"(b));
  CHECK(200, b, 8u);

  /* 201: EX -> EX forwarding, consumer reads rs2 */
  asm volatile(
    "addi t0, zero, 100\n\t"
    "addi %0, zero, 5\n\t"
    "sub  %1, t0, %0\n\t"
    : "=&r"(a), "=&r"(b)
    :
    : "t0");
  CHECK(201, b, 95u);

  /* 202-203: MEM -> EX forwarding (one instruction gap), rs1 then rs2 */
  asm volatile(
    "addi %0, zero, 7\n\t"
    "nop\n\t"
    "addi %1, %0, 3\n\t"
    : "=&r"(a), "=&r"(b));
  CHECK(202, b, 10u);

  asm volatile(
    "addi t0, zero, 100\n\t"
    "addi %0, zero, 7\n\t"
    "nop\n\t"
    "sub  %1, t0, %0\n\t"
    : "=&r"(a), "=&r"(b)
    :
    : "t0");
  CHECK(203, b, 93u);

  /* 204-205: WB -> EX forwarding (two instruction gap), rs1 then rs2 */
  asm volatile(
    "addi %0, zero, 9\n\t"
    "nop\n\t"
    "nop\n\t"
    "addi %1, %0, 3\n\t"
    : "=&r"(a), "=&r"(b));
  CHECK(204, b, 12u);

  asm volatile(
    "addi t0, zero, 100\n\t"
    "addi %0, zero, 9\n\t"
    "nop\n\t"
    "nop\n\t"
    "sub  %1, t0, %0\n\t"
    : "=&r"(a), "=&r"(b)
    :
    : "t0");
  CHECK(205, b, 91u);

  /* 210: load-use hazard, consumer reads rs1 */
  m_a = 0x00000041u;
  asm volatile(
    "lw   %0, 0(%2)\n\t"
    "addi %1, %0, 1\n\t"
    : "=&r"(a), "=&r"(b)
    : "r"(&m_a)
    : "memory");
  CHECK(210, b, 0x42u);

  /* 211: load-use hazard, consumer reads rs2. This is the one the
     uses_rs2 fix exists for. A missed stall here gives a stale
     register, not a lost cycle. */
  m_a = 0x00000041u;
  asm volatile(
    "addi t0, zero, 0x7F\n\t"
    "lw   %0, 0(%2)\n\t"
    "sub  %1, t0, %0\n\t"
    : "=&r"(a), "=&r"(b)
    : "r"(&m_a)
    : "t0", "memory");
  CHECK(211, b, 0x3Eu);

  /* 212: load-use where the consumer reads the loaded value in BOTH
     operand positions */
  m_a = 0x00000010u;
  asm volatile(
    "lw  %0, 0(%2)\n\t"
    "add %1, %0, %0\n\t"
    : "=&r"(a), "=&r"(b)
    : "r"(&m_a)
    : "memory");
  CHECK(212, b, 0x20u);

  /* 220: a taken forward branch must kill TWO instructions. The result
     names which: 0 correct, 2 means only the first was killed, 3 means
     neither was. */
  asm volatile(
    "addi %0, zero, 0\n\t"
    "beq  zero, zero, 1f\n\t"
    "addi %0, %0, 1\n\t"
    "addi %0, %0, 2\n\t"
    "1:\n\t"
    : "=&r"(r0));
  CHECK(220, r0, 0u);

  /* 221: same, backward branch (predictor takes a different path) */
  asm volatile(
    "addi %0, zero, 0\n\t"
    "addi t0, zero, 1\n\t"
    "j    2f\n\t"
    "1:\n\t"
    "addi %0, %0, 4\n\t"
    "addi %0, %0, 8\n\t"
    "j    3f\n\t"
    "2:\n\t"
    "beq  t0, t0, 1b\n\t"
    "addi %0, %0, 1\n\t"
    "addi %0, %0, 2\n\t"
    "3:\n\t"
    : "=&r"(r0)
    :
    : "t0");
  CHECK(221, r0, 12u);

  /* 222: a NOT-taken branch must kill nothing */
  asm volatile(
    "addi %0, zero, 0\n\t"
    "addi t0, zero, 1\n\t"
    "beq  t0, zero, 1f\n\t"
    "addi %0, %0, 1\n\t"
    "addi %0, %0, 2\n\t"
    "1:\n\t"
    : "=&r"(r0)
    :
    : "t0");
  CHECK(222, r0, 3u);

  /* 230-231: jal link register survives the flush. Computed against
     auipc rather than by returning through the link, so a wrong link
     reports a value instead of jumping somewhere undefined. */
  r2 = 0;
  asm volatile(
    "auipc %0, 0\n\t"          /* A      */
    "jal   %1, 1f\n\t"         /* A+4 : link = A+8 */
    "addi  %2, %2, 1\n\t"      /* A+8 : must be flushed */
    "1:\n\t"
    "sub   %1, %1, %0\n\t"
    : "=&r"(r0), "=&r"(r1), "+r"(r2));
  CHECK(230, r1, 8u);          /* link correct */
  CHECK(231, r2, 0u);          /* delay slot killed */

  /* 232-233: same for jalr */
  r3 = 0;
  asm volatile(
    "auipc %0, 0\n\t"          /* A      */
    "addi  %3, %0, 16\n\t"     /* A+4  : target = A+16 */
    "jalr  %1, 0(%3)\n\t"      /* A+8  : link = A+12   */
    "addi  %2, %2, 1\n\t"      /* A+12 : must be flushed */
    "nop\n\t"                  /* A+16 : target */
    "sub   %1, %1, %0\n\t"
    : "=&r"(r0), "=&r"(r1), "+r"(r3), "=&r"(b));
  CHECK(232, r1, 12u);
  CHECK(233, r3, 0u);

  /* 240: x0 is immutable */
  asm volatile(
    "addi x0, x0, 5\n\t"
    "mv   %0, x0\n\t"
    : "=r"(a));
  CHECK(240, a, 0u);

  /* 241: a write to x0 at distance 1, in case forwarding resurrects it */
  asm volatile(
    "addi x0, zero, -1\n\t"
    "nop\n\t"
    "addi %0, x0, 0\n\t"
    : "=r"(a));
  CHECK(241, a, 0u);
}

/* ------------------------------------------------------------------ */
/* Tier 3 — runtime and linker sections                                */
/* ------------------------------------------------------------------ */

/* .data — initialised, must survive into RAM */
static volatile unsigned int d_arr[4] = {
  0xC0DE0001u, 0xC0DE0002u, 0xC0DE0003u, 0xC0DE0004u
};
static volatile unsigned int d_one = 0x5EED1234u;

/* .bss — crt0 must zero these */
static volatile unsigned int z_arr[8];
static volatile unsigned int z_one;

static const unsigned int r_arr[4] = {
  0x0BADC0DEu, 0x0BADC0DFu, 0x0BADC0E0u, 0x0BADC0E1u
};

static void tier3(void) {
  unsigned int i;

  /* 300-301: .data initialisers.
     s9: when a structure reads back as its own initial value, suspect
     control flow, not the data path. Here the initial value IS the
     expected value, so 300 passing while 301 fails would mean the
     array was never written rather than never read. */
  for (i = 0; i < 4u; i++) {
    if (d_arr[i] != (0xC0DE0001u + i)) break;
  }
  CHECK(300, i, 4u);
  CHECK(301, d_one, 0x5EED1234u);

  /* 302-303: .bss zeroed by crt0 */
  for (i = 0; i < 8u; i++) {
    if (z_arr[i] != 0u) break;
  }
  CHECK(302, i, 8u);
  CHECK(303, z_one, 0u);

  /* 304: .data is writable and distinct from its initialiser */
  d_one = 0xA5A5A5A5u;
  CHECK(304, d_one, 0xA5A5A5A5u);

  /* 305: .rodata readable */
  for (i = 0; i < 4u; i++) {
    if (r_arr[i] != (0x0BADC0DEu + i)) break;
  }
  CHECK(305, i, 4u);

  /* 310: stack works. A local array lives at sp-relative addresses set
     by crt0 from __stack_top; if that is wrong this is where it shows.
     Deliberately NOT the medium for any other test — s9: a stack local
     dumped at a fixed address reads as x and looks like a bug. */
  {
    volatile unsigned int s_arr[8];
    for (i = 0; i < 8u; i++) s_arr[i] = 0x3C3C0000u + i;
    for (i = 0; i < 8u; i++) {
      if (s_arr[i] != (0x3C3C0000u + i)) break;
    }
    CHECK(310, i, 8u);
  }
}

/* ------------------------------------------------------------------ */

int main(void) {
  tier1();
  tier2();
  tier3();

  puts_("RUN ");
  puthex(tests_run);
  puts_(" FAIL ");
  puthex(fails);
  puts_(" FIRST ");
  puthex(first_fail);
  putch('\r');
  putch('\n');
  puts_(fails ? "RESULT FAIL\r\n" : "RESULT PASS\r\n");

  /* Terminates by spinning AFTER the summary. The cycle count of this
     program is meaningless either way — it is dominated by UART, and
     s9 records why a trailing while(1) makes a cycle figure worthless.
     Use a print-free variant for any baseline measurement. */
  for (;;) { }
  return 0;
}

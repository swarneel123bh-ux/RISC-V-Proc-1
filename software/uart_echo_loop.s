.section .text
.globl _start
_start:
  lui   x1, 0xFFFF0
poll:
  lw    x2, 8(x1)
  andi  x2, x2, 0x2
  beq   x2, x0, poll
  lw    x3, 4(x1)
  sw    x3, 0(x1)
  jal   x0, poll

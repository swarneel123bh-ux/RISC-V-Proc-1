.section .text
.globl _start
_start:
    addi x1,  x0, 5          # x1 = 5
    nop
    nop
    nop
    addi x2,  x0, -1         # x2 = 0xffffffff  (sign extension)
    nop
    nop
    nop
    addi x3,  x0, 2047       # x3 = 0x000007ff  (max positive imm)
    nop
    nop
    nop
    addi x4,  x0, -2048      # x4 = 0xfffff800  (max negative imm)
    nop
    nop
    nop
    addi x5,  x1, 10         # x5 = 15          (depends on x1)
    nop
    nop
    nop
    addi x6,  x5, -20        # x6 = -5 = 0xfffffffb (depends on x5, neg result)
    nop
    nop
    nop
    addi x7,  x0, 0          # x7 = 0
    nop
    nop
    nop
    addi x0,  x0, 100        # x0 stays 0  (write to x0 must be discarded)
    nop
    nop
    nop
    add  x8,  x1, x3         # x8 = 5 + 2047 = 2052 = 0x00000804
    nop
    nop
    nop
    addi x9,  x8, 1          # x9 = 2053        (chains off x8)
    nop
    nop
    nop

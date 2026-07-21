.section .text
.globl _start
_start:
    addi x2, x0, 0x40        # x2 = base address 0x40
    nop
    nop
    nop
    addi x1, x0, 0x123       # x1 = 0x123  (positive; avoids sign-extension)
    nop
    nop
    nop
    sw   x1, 0(x2)           # mem[0x40] = 0x123
    nop
    nop
    nop
    nop
    addi x5, x0, 0x555       # x5 = 0x555
    nop
    nop
    nop
    sw   x5, 8(x2)           # mem[0x48] = 0x555
    nop
    nop
    nop
    nop
    lw   x3, 0(x2)           # x3 = mem[0x40] -> 0x123
    nop
    nop
    nop
    nop
    lw   x6, 8(x2)           # x6 = mem[0x48] -> 0x555
    nop
    nop
    nop
    nop

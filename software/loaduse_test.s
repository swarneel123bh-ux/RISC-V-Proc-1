.section .text
.globl _start
_start:
    addi x2, x0, 0x40        # x2 = base address
    nop
    nop
    nop
    addi x1, x0, 0x123       # x1 = 0x123
    nop
    nop
    nop
    sw   x1, 0(x2)           # mem[0x40] = 0x123
    nop
    nop
    nop
    nop
    # ---- the load-use hazard: lw then immediate dependent use, NO nops ----
    lw   x3, 0(x2)           # x3 = mem[0x40] = 0x123   (load in EX)
    addi x4, x3, 1           # x4 = x3 + 1 = 0x124      (needs x3 NEXT cycle -> STALL)
    nop
    nop
    nop
    nop
    # ---- second case: load feeding rs2, no nops ----
    lw   x5, 0(x2)           # x5 = 0x123
    add  x6, x2, x5          # x6 = x2 + x5 = 0x40 + 0x123 = 0x163  (rs2 dep -> STALL)
    nop
    nop
    nop
    nop
    # ---- control: load then INDEPENDENT instr (no stall needed) ----
    lw   x7, 0(x2)           # x7 = 0x123
    addi x8, x2, 5           # x8 = x2 + 5 = 0x45  (no dep on x7 -> NO stall)
    nop
    nop
    nop
    nop

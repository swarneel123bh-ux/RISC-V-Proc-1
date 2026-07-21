.section .text
.globl _start
_start:
    addi x2, x0, 0x40          # x2 = base 0x40
    addi x1, x0, 0x123         # x1 = 0x00000123
    sw   x1, 0(x2)             # mem[0x40] = 00 00 01 23  (bytes: 23 01 00 00 LE)

    # ---- byte / half loads from 0x00000123 ----
    # nop
    lbu  x3, 0(x2)             # x3 = 0x23   (byte0, zero-ext)
    lb   x4, 1(x2)             # x4 = 0x01   (byte1, sign-ext, positive)
    lhu  x5, 0(x2)             # x5 = 0x0123 (low half, zero-ext)
    lh   x6, 2(x2)             # x6 = 0x0000 (high half = 0)

    # ---- store 0xFFFFFFFF, test sign vs zero extension on load ----
    addi x7, x0, -1            # x7 = 0xFFFFFFFF
    sw   x7, 8(x2)             # mem[0x48] = FF FF FF FF
    lb   x8, 8(x2)             # x8  = 0xFFFFFFFF (sign-ext of 0xFF)
    lbu  x9, 8(x2)             # x9  = 0x000000FF (zero-ext)
    lh   x10, 8(x2)            # x10 = 0xFFFFFFFF (sign-ext of 0xFFFF)
    lhu  x11, 8(x2)            # x11 = 0x0000FFFF (zero-ext)

    # ---- SB byte-enable: store one byte into a clean word, verify only that lane changes ----
    sw   x0, 16(x2)            # mem[0x50] = 00000000
    sb   x1, 18(x2)           # store low byte of x1 (0x23) into lane 2 of 0x50
    lw   x12, 16(x2)          # x12 = 0x00230000  (only lane 2 set, others intact)

    # ---- SH half-enable: store a halfword into the high half, verify ----
    sw   x0, 20(x2)           # mem[0x54] = 00000000
    sh   x1, 22(x2)           # store low half of x1 (0x0123) into high half of 0x54
    lw   x13, 20(x2)          # x13 = 0x01230000

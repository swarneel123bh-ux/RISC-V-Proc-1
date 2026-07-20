.section .text
.globl _start
_start:
    # --- set up source registers ---
    addi  x1,  x0, 6           # x1 = 6
    nop
    nop
    nop
    addi  x2,  x0, -3          # x2 = 0xfffffffd
    nop
    nop
    nop
    addi  x3,  x0, 0xF0        # x3 = 240
    nop
    nop
    nop
    addi  x4,  x0, 0x0F        # x4 = 15
    nop
    nop
    nop
    addi  x5,  x0, 1           # x5 = 1
    nop
    nop
    nop
    # --- U-type ---
    lui   x7,  0x12345         # x7 = 0x12345000
    nop
    nop
    nop
    auipc x8,  0x10            # x8 = (pc of this instr) + 0x10000
    nop
    nop
    nop
    # --- R-type ---
    add   x10, x1, x2          # 3
    nop
    nop
    nop
    sub   x11, x1, x2          # 9
    nop
    nop
    nop
    sll   x12, x1, x5          # 12
    nop
    nop
    nop
    slt   x13, x2, x1          # 1  (signed -3 < 6)
    nop
    nop
    nop
    sltu  x14, x1, x2          # 1  (unsigned 6 < huge)
    nop
    nop
    nop
    xor   x15, x3, x4          # 0xFF
    nop
    nop
    nop
    srl   x16, x3, x5          # 0x78
    nop
    nop
    nop
    sra   x17, x2, x5          # 0xfffffffe  (arithmetic)
    nop
    nop
    nop
    or    x18, x3, x4          # 0xFF
    nop
    nop
    nop
    and   x19, x3, x3          # 0xF0
    nop
    nop
    nop
    # --- I-type ALU ---
    addi  x20, x1, 10          # 16
    nop
    nop
    nop
    slti  x21, x2, 6           # 1  (signed)
    nop
    nop
    nop
    sltiu x22, x1, 6           # 0  (6 < 6 false)
    nop
    nop
    nop
    xori  x23, x3, 0x0F        # 0xFF
    nop
    nop
    nop
    ori   x24, x3, 0x0F        # 0xFF
    nop
    nop
    nop
    andi  x25, x3, 0xFF        # 0xF0
    nop
    nop
    nop
    slli  x26, x1, 2           # 24
    nop
    nop
    nop
    srli  x27, x3, 1           # 0x78
    nop
    nop
    nop
    srai  x28, x2, 1           # 0xfffffffe  (arithmetic imm shift)
    nop
    nop
    nop

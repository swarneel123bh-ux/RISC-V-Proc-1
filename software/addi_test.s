.section .text
.globl _start
_start:
  addi x1, x0, 5      # -> rs1=0  rd=1
  addi x2, x0, -1     # -> rs1=0  rd=2
  addi x3, x1, 10     # -> rs1=1  rd=3
  addi x4, x0, 2047   # -> rs1=0  rd=4
  addi x5, x0, -2048  # -> rs1=0  rd=5

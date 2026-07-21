# crt0.s — startup: set stack, call main, halt. Linked first (address 0x0).
.section .text.init
.globl _start
_start:
  li    sp, 0x1000        # top of 4KB RAM; grows down. Adjust if RAM size changes.
  call  main
halt:
  j     halt

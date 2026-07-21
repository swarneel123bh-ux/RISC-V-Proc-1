# uart_tx_test.s — write "Hi\n" over UART, then halt.
# UART_TX = 0xFFFF0000 (low byte of the store is transmitted).
.section .text
.globl _start
_start:
  lui   x1, 0xFFFF0        # x1 = 0xFFFF0000  (UART_TX base)

  addi  x2, x0, 0x48       # 'H'
  sw    x2, 0(x1)
  addi  x2, x0, 0x69       # 'i'
  sw    x2, 0(x1)
  addi  x2, x0, 0x0A       # '\n'
  sw    x2, 0(x1)

done:
  jal   x0, done           # spin so we don't run into garbage

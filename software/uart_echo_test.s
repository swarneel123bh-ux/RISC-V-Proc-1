# uart_echo_test.s — RX echo with double-read to probe UART read latency.
# STATUS=0xFFFF0008 (bit1=rx_ready), RX=0xFFFF0004, TX=0xFFFF0000
.section .text
.globl _start
_start:
  lui   x1, 0xFFFF0        # x1 = 0xFFFF0000  (UART base)

poll:
  lw    x2, 8(x1)          # read STATUS
  andi  x2, x2, 0x2        # isolate bit1 (rx_ready)
  beq   x2, x0, poll       # not ready -> keep polling

  lw    x3, 4(x1)          # first RX read — latches addr, result lags
  lw    x3, 4(x1)          # second read — returns the settled value
  sw    x3, 0(x1)          # echo to TX

done:
  jal   x0, done           # spin

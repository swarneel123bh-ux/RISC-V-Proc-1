#include <vpi_user.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>

static struct termios orig_termios;

static void restore_terminal(void) {
  tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}

static PLI_INT32 uart_init_calltf(PLI_BYTE8 *user_data) {
  (void)user_data;
  struct termios raw;

  tcgetattr(STDIN_FILENO, &orig_termios);
  atexit(restore_terminal);

  raw = orig_termios;
  raw.c_lflag &= ~(ICANON | ECHO);
  raw.c_cc[VMIN]  = 0;
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw);

  int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
  fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

  return 0;
}

static PLI_INT32 uart_rx_calltf(PLI_BYTE8 *user_data) {
  (void)user_data;

  vpiHandle sys = vpi_handle(vpiSysTfCall, NULL);

  s_vpi_value val;
  val.format = vpiIntVal;

  unsigned char c;
  int n = read(STDIN_FILENO, &c, 1);

  val.value.integer = (n == 1) ? (PLI_INT32)c : (PLI_INT32)0xFFFFFFFF;
  vpi_put_value(sys, &val, NULL, vpiNoDelay);

  return 0;
}

static void uart_vpi_register(void) {
  s_vpi_systf_data tf;

  tf.compiletf = NULL;
  tf.sizetf    = NULL;
  tf.user_data = NULL;

  tf.type    = vpiSysTask;
  tf.tfname  = "$uart_init";
  tf.calltf  = uart_init_calltf;
  vpi_register_systf(&tf);

  tf.type        = vpiSysFunc;
  tf.sysfunctype = vpiIntFunc;
  tf.tfname      = "$uart_rx_read";
  tf.calltf      = uart_rx_calltf;
  vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {
  uart_vpi_register,
  NULL
};

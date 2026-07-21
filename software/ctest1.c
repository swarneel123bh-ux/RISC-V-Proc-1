int main() {
  volatile char *TX = (volatile char *)0xFFFF0000;
  *TX = 'K';
  return 0;
}

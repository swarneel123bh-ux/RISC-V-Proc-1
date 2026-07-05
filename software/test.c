int main() {
  volatile int a = 5, b = 7;
  int c = a + b;
  for (int i = 0; i < 4; i++) c += i;
  return c;
}

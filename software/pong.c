// pong.c -- Pong for the RV32I core.
//
// Output: writes pixels straight into VRAM at 0xFFFE0000 (160x120, 1 byte per
//         pixel, 0x00 = black, 0xFF = white). gpu_vpi.c ships VRAM to
//         sdl_screen.c, which renders it.
// Input:  keys arrive over the existing UART RX path (sdl_screen pipes them
//         into vvp's stdin). Polled NON-BLOCKING so the game never stalls.
//
//   left paddle : 'w' up, 's' down
//   right paddle: arrow up / arrow down  (sdl_screen sends 'U' / 'D')
//   'q' quits back to a spin loop
//
// Speed note: the screen is NOT cleared every frame -- that would be 4800
// word stores per frame and crawl under simulation. Instead each moving
// object is erased at its old position and redrawn at the new one, so a
// frame costs a few hundred stores.

#define UART_TX     (*(volatile unsigned int *)0xFFFF0000)
#define UART_RX     (*(volatile unsigned int *)0xFFFF0004)
#define UART_STATUS (*(volatile unsigned int *)0xFFFF0008)
#define RX_READY    0x2

#define VRAM_B ((volatile unsigned char *)0xFFFE0000)
#define VRAM_W ((volatile unsigned int  *)0xFFFE0000)

#define SCR_W 160
#define SCR_H 120

#define BLACK 0x00
#define WHITE 0xFF

// geometry
#define PAD_W      3
#define PAD_H      22
#define PAD_LX     4                    // left paddle x
#define PAD_RX     (SCR_W - 4 - PAD_W)  // right paddle x
#define PAD_STEP   2                    // pixels per keypress
#define BALL_SZ    3

// how long to idle between frames (tune for playable wall-clock speed)
#define FRAME_DELAY 200

// ---------------------------------------------------------------- UART -----
void putchar(char c) { UART_TX = (unsigned int)c; }

void putstr(const char *s) { while (*s) putchar(*s++); }

// non-blocking: returns 0 when no key is waiting
char getkey(void) {
  if (UART_STATUS & RX_READY) return (char)(UART_RX & 0xFF);
  return 0;
}

void putdec(int v) {
  char buf[12];
  int i = 0;
  if (v < 0) { putchar('-'); v = -v; }
  if (v == 0) { putchar('0'); return; }
  while (v > 0) {
    int q = 0;
    while (v >= 10) { v -= 10; q++; }   // v becomes v%10, q becomes v/10
    buf[i++] = (char)('0' + v);
    v = q;
  }
  while (i > 0) putchar(buf[--i]);
}

// -------------------------------------------------------------- drawing ----
void fill_rect(int x, int y, int w, int h, unsigned char c) {
  int x0 = (x < 0) ? 0 : x;
  int y0 = (y < 0) ? 0 : y;
  int x1 = x + w;  if (x1 > SCR_W) x1 = SCR_W;
  int y1 = y + h;  if (y1 > SCR_H) y1 = SCR_H;
  int yy, xx;
  for (yy = y0; yy < y1; yy++) {
    volatile unsigned char *row = VRAM_B + yy * SCR_W;
    for (xx = x0; xx < x1; xx++) row[xx] = c;
  }
}

// fast full clear using word stores (4 pixels at a time)
void clear_screen(void) {
  int i;
  for (i = 0; i < (SCR_W * SCR_H) / 4; i++) VRAM_W[i] = 0x00000000;
}

// dashed centre line, drawn once
void draw_net(void) {
  int y;
  for (y = 0; y < SCR_H; y += 8) fill_rect(SCR_W / 2, y, 1, 4, WHITE);
}

void move_paddle(int x, int oldy, int newy) {
  int d;
  if (newy == oldy) return;
  d = (newy > oldy) ? (newy - oldy) : (oldy - newy);
  if (d >= PAD_H) {                       // big jump: just repaint both
    fill_rect(x, oldy, PAD_W, PAD_H, BLACK);
    fill_rect(x, newy, PAD_W, PAD_H, WHITE);
    return;
  }
  if (newy < oldy) {                      // moved up
    fill_rect(x, newy,          PAD_W, d, WHITE);   // new strip on top
    fill_rect(x, newy + PAD_H,  PAD_W, d, BLACK);   // erase strip at bottom
  } else {                                // moved down
    fill_rect(x, oldy,          PAD_W, d, BLACK);   // erase strip at top
    fill_rect(x, oldy + PAD_H,  PAD_W, d, WHITE);   // new strip at bottom
  }
}

// ----------------------------------------------------------------- game ----
int main(void) {
  int pad_l = (SCR_H - PAD_H) / 2;
  int pad_r = (SCR_H - PAD_H) / 2;
  int old_l = pad_l, old_r = pad_r;

  int bx = SCR_W / 2, by = SCR_H / 2;
  int old_bx = bx, old_by = by;
  int dx = 1, dy = 1;

  int score_l = 0, score_r = 0;
  int running = 1;

  clear_screen();
  draw_net();
  fill_rect(PAD_LX, pad_l, PAD_W, PAD_H, WHITE);
  fill_rect(PAD_RX, pad_r, PAD_W, PAD_H, WHITE);
  fill_rect(bx, by, BALL_SZ, BALL_SZ, WHITE);

  putstr("pong: w/s = left, arrows = right, q = quit\n");

  while (running) {
	  // ---- input: track held state, don't move per event ----
	  static int hold_lu = 0, hold_ld = 0, hold_ru = 0, hold_rd = 0;
	  char k;
	  while ((k = getkey()) != 0) {
	    switch (k) {
	      case 0x11: hold_lu = 1; break;
	      case 0x21: hold_lu = 0; break;
	      case 0x12: hold_ld = 1; break;
	      case 0x22: hold_ld = 0; break;
	      case 0x13: hold_ru = 1; break;
	      case 0x23: hold_ru = 0; break;
	      case 0x14: hold_rd = 1; break;
	      case 0x24: hold_rd = 0; break;
	      case 'q':  running  = 0; break;
	      default: break;
	    }
	  }
	  if (hold_lu) pad_l -= PAD_STEP;
	  if (hold_ld) pad_l += PAD_STEP;
	  if (hold_ru) pad_r -= PAD_STEP;
	  if (hold_rd) pad_r += PAD_STEP;

    // ---- ball physics ----
    bx += dx;
    by += dy;

    if (by <= 0)               { by = 0;               dy = -dy; }
    if (by >= SCR_H - BALL_SZ) { by = SCR_H - BALL_SZ; dy = -dy; }

    // left paddle
    if (dx < 0 && bx <= PAD_LX + PAD_W && bx + BALL_SZ >= PAD_LX) {
      if (by + BALL_SZ >= pad_l && by <= pad_l + PAD_H) {
        bx = PAD_LX + PAD_W;
        dx = -dx;
      }
    }
    // right paddle
    if (dx > 0 && bx + BALL_SZ >= PAD_RX && bx <= PAD_RX + PAD_W) {
      if (by + BALL_SZ >= pad_r && by <= pad_r + PAD_H) {
        bx = PAD_RX - BALL_SZ;
        dx = -dx;
      }
    }

    // scoring
    if (bx < 0) {
      score_r++;
      putstr("right scores: "); putdec(score_l); putchar('-');
      putdec(score_r); putchar('\n');
      fill_rect(old_bx, old_by, BALL_SZ, BALL_SZ, BLACK);
      bx = SCR_W / 2; by = SCR_H / 2; dx = 1;
      old_bx = bx; old_by = by;
    } else if (bx > SCR_W - BALL_SZ) {
      score_l++;
      putstr("left scores: "); putdec(score_l); putchar('-');
      putdec(score_r); putchar('\n');
      fill_rect(old_bx, old_by, BALL_SZ, BALL_SZ, BLACK);
      bx = SCR_W / 2; by = SCR_H / 2; dx = -1;
      old_bx = bx; old_by = by;
    }

    // ---- redraw only what moved ----
    // Paddle redraws
    if (pad_l != old_l) { move_paddle(PAD_LX, old_l, pad_l); old_l = pad_l; }
    if (pad_r != old_r) { move_paddle(PAD_RX, old_r, pad_r); old_r = pad_r; }
    // Ball redraws
    if (bx != old_bx || by != old_by) {
      fill_rect(old_bx, old_by, BALL_SZ, BALL_SZ, BLACK);
      fill_rect(bx, by, BALL_SZ, BALL_SZ, WHITE);
      old_bx = bx;
      old_by = by;
    }

    // the net gets nibbled when the ball crosses it -- repaint it cheaply
    if (bx + BALL_SZ >= SCR_W / 2 - 1 && bx <= SCR_W / 2 + 1) draw_net();

    // ---- pace the game ----
    {
      volatile int d;
      for (d = 0; d < FRAME_DELAY; d++) { }
    }
  }

  putstr("bye\n");
  for (;;) { }
}

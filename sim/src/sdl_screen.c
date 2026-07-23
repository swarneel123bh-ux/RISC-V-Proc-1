// sdl_screen.c -- standalone display process for the RV32I framebuffer.
//
// Runs in its OWN process so SDL video gets a real main thread (required on
// macOS). Reads the shared framebuffer written by gpu_vpi.c, renders it, and
// forwards keystrokes to stdout -- pipe stdout into vvp's stdin so the
// existing uart_vpi delivers them to the CPU as UART RX.
//
//   ./sdl_screen | vvp -M build -m uart_vpi -m gpu_vpi build/vvp/sim_tb.vvp
//
// Framebuffer format (raw, from gpu_vpi.c): PIX_W*PIX_H bytes, one per pixel,
// row-major. 0x00 = black, anything else = white.
//
// Build:
//   cc -O2 -o sdl_screen sdl_screen.c $(sdl2-config --cflags --libs)
//
// Keys: ESC quits. Everything else is forwarded as ASCII to the CPU.

#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
static int fwd_keys = 1;

#ifndef FB_PATH
#define FB_PATH "/tmp/rv32_fb"
#endif

#ifndef PIX_W
#define PIX_W 160
#endif

#ifndef PIX_H
#define PIX_H 120
#endif

#ifndef SCALE
#define SCALE 5                      // window = 800 x 600
#endif

#define NPIX (PIX_W * PIX_H)

// 1. defines
#define CTRL_BYTES 16
#define FB_SIZE    (NPIX + CTRL_BYTES)

static unsigned char *fb = NULL;      			// shared framebuffer (read-only)
static uint32_t pixels[NPIX];               // ARGB8888 scratch for the texture

// Send one byte to the CPU (via stdout -> pipe -> vvp stdin -> uart_vpi).
static void send_key(unsigned char c) {
  if (!fwd_keys) return;
  fputc(c, stdout);
  fflush(stdout);
}

// Map the shared framebuffer. Waits for gpu_vpi.c to create it if needed.
static int open_fb(void) {
  int fd = -1;
  int tries;

  for (tries = 0; tries < 100; tries++) {          // ~5 s
    fd = open(FB_PATH, O_RDWR);
    if (fd >= 0) {
      struct stat st;
      if (fstat(fd, &st) == 0 && st.st_size >= FB_SIZE) break;
      close(fd);
      fd = -1;
    }
    SDL_Delay(50);
  }

  if (fd < 0) {
    fprintf(stderr, "[sdl_screen] ERROR: %s not available "
                    "(is the simulation running?)\n", FB_PATH);
    return 0;
  }

  fb = (const unsigned char *)mmap(NULL, FB_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  close(fd);
  if (fb == MAP_FAILED) {
    fprintf(stderr, "[sdl_screen] ERROR: mmap %s failed\n", FB_PATH);
    return 0;
  }
  return 1;
}

int main(int argc, char **argv) {
  (void)argc; (void)argv;

  fwd_keys = !isatty(STDOUT_FILENO);
  fprintf(stderr, "[sdl_screen] key forwarding %s\n",
          fwd_keys ? "ON (piped to sim)" : "OFF (stdout is a terminal)");

  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    fprintf(stderr, "[sdl_screen] SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }

  if (!open_fb()) { SDL_Quit(); return 1; }

  SDL_Window *win = SDL_CreateWindow(
      "RV32I Framebuffer",
      SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
      PIX_W * SCALE, PIX_H * SCALE,
      SDL_WINDOW_SHOWN | SDL_WINDOW_ALLOW_HIGHDPI);
  if (!win) {
    fprintf(stderr, "[sdl_screen] SDL_CreateWindow failed: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  SDL_Renderer *ren = SDL_CreateRenderer(
      win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!ren) ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
  if (!ren) {
    fprintf(stderr, "[sdl_screen] SDL_CreateRenderer failed: %s\n", SDL_GetError());
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 1;
  }

  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");   // nearest-neighbour

  SDL_Texture *tex = SDL_CreateTexture(
      ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
      PIX_W, PIX_H);
  if (!tex) {
    fprintf(stderr, "[sdl_screen] SDL_CreateTexture failed: %s\n", SDL_GetError());
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 1;
  }

  fprintf(stderr, "[sdl_screen] %dx%d @ %dx  (ESC to quit)\n",
          PIX_W, PIX_H, SCALE);

  int running = 1;
  SDL_Event ev;

  while (running) {
    // ---- input: forward keys to the CPU over stdout ----
    while (SDL_PollEvent(&ev)) {
      switch (ev.type) {

      case SDL_QUIT:
        running = 0;
        break;

      case SDL_KEYDOWN: {
        SDL_Keycode k = ev.key.keysym.sym;
        switch (k) {
        case SDLK_ESCAPE:    running = 0;      break;
        case SDLK_RETURN:
        case SDLK_KP_ENTER:  send_key(0x0D);   break;
        case SDLK_BACKSPACE: send_key(0x08);   break;
        case SDLK_SPACE:     send_key(' ');    break;
        // arrows -> single letters, easier for bare-metal C than escapes
        case SDLK_UP:        send_key('U');    break;
        case SDLK_DOWN:      send_key('D');    break;
        case SDLK_LEFT:      send_key('L');    break;
        case SDLK_RIGHT:     send_key('R');    break;
        default:
          // printable ASCII: send lowercase letters/digits directly.
          if (k >= 32 && k < 127) send_key((unsigned char)k);
          break;
        }
        break;
      }

      default:
        break;
      }
    }

    // ---- render: expand mono bytes to ARGB ----
    int i;
    for (i = 0; i < NPIX; i++) {
      pixels[i] = fb[i] ? 0xFFFFFFFFu : 0xFF000000u;
    }

    SDL_UpdateTexture(tex, NULL, pixels, PIX_W * (int)sizeof(uint32_t));
    SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
    SDL_RenderClear(ren);
    SDL_RenderCopy(ren, tex, NULL, NULL);
    SDL_RenderPresent(ren);

    SDL_Delay(16);        // ~60 fps if vsync is unavailable
  }

  // 4. after the main loop, before SDL_DestroyTexture:
  if (fb) { fb[NPIX] = 1; msync(fb, FB_SIZE, MS_SYNC); }   // tell sim to quit  SDL_DestroyTexture(tex);

  SDL_DestroyRenderer(ren);
  SDL_DestroyWindow(win);
  SDL_Quit();
  return 0;
}

// gpu_vpi.c -- minimal Verilog -> C framebuffer bridge.
//
// Reads the VRAM array inside the running simulation (by hierarchical VPI
// name) and copies it verbatim into a shared mmap'd file. Nothing else:
// no unpacking, no colour, no SDL. sdl_screen.c owns all interpretation.
//
// Self-scheduling: registers a cbAfterDelay callback that re-arms itself,
// so NO Verilog changes are needed anywhere (no $task, no tick in sim_tb.v).
//
// Shared file layout: GPU_NPIX raw bytes, one byte per pixel, in pixel
// order (row-major). Byte value is whatever the CPU stored -- typically
// 0x00 = black, non-zero = white. Mapping is sdl_screen.c's job.
//
// Build:  iverilog-vpi --name=gpu_vpi gpu_vpi.c
// Load:   vvp -M build -m uart_vpi -m gpu_vpi build/vvp/sim_tb.vvp

#include <vpi_user.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

// ---- configuration (override at compile time with -D) ----------------------
#ifndef GPU_VRAM_PATH
#define GPU_VRAM_PATH "sim_tb.uut.dataMem.vram_inst.mem"
#endif

#ifndef GPU_FB_PATH
#define GPU_FB_PATH "/tmp/rv32_fb"
#endif

#ifndef GPU_PIX_W
#define GPU_PIX_W 160
#endif

#ifndef GPU_PIX_H
#define GPU_PIX_H 120
#endif


// How much simulation time between frame copies. Timescale is 1ns/1ps, so
// these units are ps: 1000000 ps = 1 us = 100 clock cycles at #5 half-period.
// Lower = smoother display, higher = faster simulation. Tune to taste.
#ifndef GPU_FRAME_INTERVAL
#define GPU_FRAME_INTERVAL 1000000
#endif

#define GPU_NPIX   (GPU_PIX_W * GPU_PIX_H)
#define GPU_NWORDS (GPU_NPIX / 4)

// 1. near the other defines
#define GPU_CTRL_BYTES 16
#define GPU_FB_SIZE    (GPU_NPIX + GPU_CTRL_BYTES)

// ---- state -----------------------------------------------------------------
static unsigned char *fb      = NULL;   // mmap'd framebuffer
static vpiHandle     *wordh   = NULL;   // cached per-word handles
static int            bound   = 0;      // 1 once VRAM + fb are ready

static void gpu_schedule(void);

// ---- open / create the shared framebuffer file -----------------------------
static int gpu_open_fb(void) {
  int fd = open(GPU_FB_PATH, O_RDWR | O_CREAT, 0666);
  if (fd < 0) {
    vpi_printf("[gpu_vpi] ERROR: cannot open %s\n", GPU_FB_PATH);
    return 0;
  }
  if (ftruncate(fd, GPU_FB_SIZE) != 0) {
    vpi_printf("[gpu_vpi] ERROR: ftruncate %s failed\n", GPU_FB_PATH);
    close(fd);
    return 0;
  }
  fb = (unsigned char *)mmap(NULL, GPU_FB_SIZE, PROT_READ | PROT_WRITE,
                             MAP_SHARED, fd, 0);
  close(fd);                       // mapping stays valid after close
  if (fb == MAP_FAILED) {
    vpi_printf("[gpu_vpi] ERROR: mmap %s failed\n", GPU_FB_PATH);
    fb = NULL;
    return 0;
  }
  memset(fb, 0, GPU_FB_SIZE);         // start black
  return 1;
}

// ---- bind to the VRAM array inside the simulation --------------------------
static int gpu_bind_vram(void) {
  vpiHandle memh = vpi_handle_by_name(GPU_VRAM_PATH, NULL);
  if (!memh) {
    vpi_printf("[gpu_vpi] ERROR: cannot find VRAM at '%s'\n", GPU_VRAM_PATH);
    vpi_printf("[gpu_vpi]        rebuild with -DGPU_VRAM_PATH='\"<path>\"'\n");
    return 0;
  }

  wordh = (vpiHandle *)malloc(sizeof(vpiHandle) * GPU_NWORDS);
  if (!wordh) {
    vpi_printf("[gpu_vpi] ERROR: out of memory\n");
    return 0;
  }

  int i;
  for (i = 0; i < GPU_NWORDS; i++) {
    wordh[i] = vpi_handle_by_index(memh, i);
    if (!wordh[i]) {
      vpi_printf("[gpu_vpi] ERROR: no VRAM word at index %d "
                 "(array smaller than %d words?)\n", i, GPU_NWORDS);
      return 0;
    }
  }

  vpi_printf("[gpu_vpi] bound %d words (%dx%d) -> %s\n",
             GPU_NWORDS, GPU_PIX_W, GPU_PIX_H, GPU_FB_PATH);
  return 1;
}

// ---- one frame: copy VRAM words out as raw little-endian bytes -------------
static PLI_INT32 gpu_frame_cb(struct t_cb_data *cb) {
  (void)cb;

  if (bound) {
    s_vpi_value val;
    val.format = vpiIntVal;

    int i;
    for (i = 0; i < GPU_NWORDS; i++) {
      vpi_get_value(wordh[i], &val);
      unsigned int w = (unsigned int)val.value.integer;
      unsigned char *p = fb + (i * 4);
      p[0] = (unsigned char)( w        & 0xFF);   // pixel 4i+0
      p[1] = (unsigned char)((w >>  8) & 0xFF);   // pixel 4i+1
      p[2] = (unsigned char)((w >> 16) & 0xFF);   // pixel 4i+2
      p[3] = (unsigned char)((w >> 24) & 0xFF);   // pixel 4i+3
    }
  }

  // 3. in gpu_frame_cb(), right after the copy loop, before gpu_schedule():
    if (bound && fb[GPU_NPIX]) {
      vpi_printf("[gpu_vpi] display closed -> finishing simulation\n");
      vpi_control(vpiFinish, 0);
      return 0;
    }

  gpu_schedule();      // re-arm: this is what makes it free-running
  return 0;
}

// ---- re-arm the periodic callback ------------------------------------------
static void gpu_schedule(void) {
  s_vpi_time t;
  s_cb_data  cb;

  t.type = vpiSimTime;
  t.high = 0;
  t.low  = GPU_FRAME_INTERVAL;

  cb.reason    = cbAfterDelay;
  cb.cb_rtn    = gpu_frame_cb;
  cb.obj       = NULL;
  cb.time      = &t;
  cb.value     = NULL;
  cb.user_data = NULL;

  vpi_register_cb(&cb);
}

// ---- start of simulation: bind everything, kick off the loop ---------------
static PLI_INT32 gpu_start_cb(struct t_cb_data *cb) {
  (void)cb;

  if (gpu_open_fb() && gpu_bind_vram()) {
    bound = 1;
  } else {
    vpi_printf("[gpu_vpi] disabled (simulation continues without display)\n");
  }

  gpu_schedule();     // schedule regardless; harmless if !bound
  return 0;
}

static void gpu_register(void) {
  s_cb_data cb;
  cb.reason    = cbStartOfSimulation;
  cb.cb_rtn    = gpu_start_cb;
  cb.obj       = NULL;
  cb.time      = NULL;
  cb.value     = NULL;
  cb.user_data = NULL;
  vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {
  gpu_register,
  0
};

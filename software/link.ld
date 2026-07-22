ENTRY(_start)

/* Single 64 KB unified image: text, rodata, data, bss; stack sits on top. */
SECTIONS {
  . = 0x00000000;

  .text : {
    *(.text.init)      /* crt0 — must be first; entry at 0x0 */
    *(.text*)
  }

  .rodata : {
    *(.rodata*)
    *(.srodata*)
  }

  .data : {
    *(.data*)
    *(.sdata*)         /* small-data (gp-relative); place with .data */
  }

  . = ALIGN(4);
  __bss_start = .;
  .bss : {
    *(.bss*)
    *(.sbss*)
    *(COMMON)
  }
  . = ALIGN(4);
  __bss_end = .;

  /* Stack top = top of the 64 KB region. MUST equal unified_memory
     DEPTH_WORDS * 4. Direct constant so no bytes are emitted here. */
  __stack_top = 0x00010000;
}

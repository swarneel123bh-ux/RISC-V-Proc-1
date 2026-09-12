ENTRY(_start)

/* Single 32 KB unified image: text, rodata, data, bss; stack sits on top. */
SECTIONS {
  . = 0x00000000;

  .text : {
    *(.text.init)      /* crt0 — must be first; entry at 0x0 */
    *(.text*)
    /* Decision 17: only the low 8 KB is fetchable. Above it a fetch
       aliases into the mirror and the program appears to restart
       rather than crash, so this must fail at link time. */
    ASSERT(. <= 0x2000, "text section exceeds 8KB fetch ceiling");
  }

  .rodata : {
    *(.rodata*)
    *(.srodata*)
  }

  .data : {
    *(.data*)
    *(.sdata*)         /* small-data (gp-relative); place with .data */
  }

  .bss : {
    . = ALIGN(4);
    __bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  }

  /* Stack top = top of the 32 KB region. MUST equal unified_memory
     DEPTH_WORDS * 4. Direct constant so no bytes are emitted here. */
  __stack_top = 0x00008000;

  ASSERT(__stack_top <= 0x8000, "stack top exceeds main memory")
}

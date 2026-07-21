ENTRY(_start)
SECTIONS {
  . = 0x0;
  .text : {
    *(.text.init)     /* crt0 at 0x0 — runs first */
    *(.text*)         /* main and everything else after */
  }
  .rodata : { *(.rodata*) }
  .data   : { *(.data*)   }
  .bss    : { *(.bss*)    }
}

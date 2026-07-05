# RISC-V-Proc-Proj

RV32I-inspired processor, **simulation only** (iverilog + vvp, waveforms in Surfer).
Restructured to match the Modbus RTU project layout.

## Layout

```
.
├── Makefile                 root; auto-discovers rtl/<m>/<m>.mk
├── rtl/
│   ├── addr_decode/         address decoder + RAM/UART read mux
│   ├── mem/                 16K-word RAM, $readmemh-loaded
│   ├── pc/                  program counter
│   ├── uart/                memory-mapped UART (+ VPI for stdin/stdout)
│   │   └── vpi/uart_vpi.c   $uart_init / $uart_rx_read implementation
│   └── proc/                TOP STUB -- does not build yet (see below)
├── sim/                     system-level / co-sim harness (WIP placeholder)
└── software/
    └── rom/program.hex      memory image loaded by mem
```

Each `rtl/<m>/` has `src/<m>.v`, `tb/<m>_tb.v`, and `<m>.mk`. Build artifacts
go in `rtl/<m>/build/{vcd,vvp}/`.

## Usage

```
make                 # list discovered modules
make rtl-uart-test   # build + run the uart testbench headless
make rtl-uart-run    # same, then open the waveform in Surfer
make rtl-mem-test    # etc.
make test            # run every module's testbench headless
make clean           # clean all module + sim build dirs
```

Module names: `addr_decode`, `mem`, `pc`, `uart`.

## UART VPI

`uart.v` calls `$uart_init` and `$uart_rx_read`, provided by a VPI library
compiled from `rtl/uart/vpi/uart_vpi.c`. `make rtl-uart-*` builds the `.vpi`
into `rtl/uart/build/` and loads it with `vvp -M build -m uart_vpi`. The
`test` target feeds one byte on stdin so the RX path completes non-interactively;
use `run` for an interactive session (type a key when prompted).

Requires a working C toolchain for `iverilog-vpi` (on macOS: Xcode Command Line
Tools, `xcode-select --install`).

## proc.v is a stub

`rtl/proc/src/proc.v` is the unfinished top. It does **not** compile (e.g.
`inital` typo, `pc` declared as a scalar reg, no datapath) and has **no** `.mk`,
so the build system skips it. The old single root Makefile's default target
globbed every `src/*.v` and pulled this stub in -- that, not the UART/VPI, is
why the previous `make` stopped working. Flesh out `proc.v` (and add
`rtl/proc/proc.mk` + `rtl/proc/tb/proc_tb.v`) to bring the top online.

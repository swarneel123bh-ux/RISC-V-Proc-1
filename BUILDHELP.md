# BUILD — how the make system works

Reference for `Makefile` (root), `rtl/<m>/<m>.mk`, and `sim/sim.mk`.
Everything runs from the **repo root** unless stated otherwise.

---

## 0. The one-line answer

Running a program on the processor:

```
  make prog PROG=subword_test
```

- **No file extension.** `PROG=subword_test`, not `subword_test.s`.
- **No path.** `software/` is prepended for you.
- `.c` and `.s` are auto-detected, in that order — if both
  `software/foo.c` and `software/foo.s` exist, **the `.c` wins silently**.

`make rtl-proc-test PROG=<anything>` does **not** assemble anything. `PROG` is
only read by the `prog` target. Passing it to `rtl-proc-test` is accepted and
ignored, and you re-run whatever `program.hex` was left over from last time.
This is the failure that produced a 200-cycle run with 45 branches on a
branchless test program.

---

## 1. Two independent build paths

They are **not** the same design. Know which one you're in.

| | `rtl/proc/proc.mk` | `sim/sim.mk` |
|---|---|---|
| Entered by | `make prog`, `make rtl-proc*` | `make proc-console`, `make proc-screen*` |
| Top module | `proc_tb` (`rtl/proc/tb/`) | `sim_tb` (`sim/src/`) |
| Ends | `$finish` at a fixed cycle count | never — runs until Ctrl-C |
| UART source | `uart_top.v` + `uart_rx.v` + `uart_tx.v` | **`uart.v`** |
| VPI loaded | `uart_vpi` | `uart_vpi` + `gpu_vpi` |
| Include paths | `-I../instruction_mem/src -I../uart/src` | **none** |
| ROM path | `../../software/rom/program.hex` | `../software/rom/program.hex` |

The two UART rows are the important one. `sim.mk` still compiles the retired
`uart.v` and does not compile `uart_top.v`, so anything going through `sim.mk`
builds against a module `data_mem.v` no longer instantiates. See §5.

---

## 2. Root Makefile targets

### Module discovery

```
  RTL_MODULES := $(notdir $(patsubst %/,%,$(dir $(wildcard rtl/*/*.mk))))
```

A directory under `rtl/` is a module **if and only if** it contains a `.mk`.
The `.mk` filename is not checked against the directory name, but the generated
target invokes `-C rtl/$(1) -f $(1).mk`, so `rtl/foo/bar.mk` gets discovered as
module `foo` and then fails to find `foo.mk`. Name them to match.

`rtl/gpu/gpu.mk` exists and is therefore in `make test`.

### Per-module targets

| Target | Runs in `<m>.mk` |
|---|---|
| `make rtl-<m>` | `all` — compile to `build/vvp/<m>_tb.vvp` |
| `make rtl-<m>-test` | `test` |
| `make rtl-<m>-run` | `run` |
| `make rtl-<m>-clean` | `clean` — `rm -rf build` |

**The root Makefile's own help text is wrong about `test` and `run`.** It claims
`-test` is headless and `-run` opens Surfer. In `proc.mk` it is the other way
round: `test` runs vvp **and then launches Surfer**, `run` is the headless one.
Check the `.mk` before believing the header.

### Aggregate targets

- `make` / `make list` — print discovered modules and usage.
- `make test` — every module's `test`, in discovery order. Since `proc`'s `test`
  opens Surfer, this pops a waveform viewer mid-run.
- `make clean` — every module's `clean`, plus `sim-clean`.

### Program targets

| Target | Effect |
|---|---|
| `make prog PROG=<n>` | assemble/compile → `program.hex` → run under `proc.mk`'s `test` |
| `make proc-console PROG=<n>` | same build, then `sim.mk`'s `console` (live stdin, no `$finish`) |
| `make proc-screen PROG=<n>` | `sim.mk`'s `screen` — SDL window, keyboard in terminal |
| `make proc-screen_only PROG=<n>` | `sim.mk`'s `screen_only` — SDL window captures keyboard |
| `make uart-console` | `rtl/uart`'s `console` |
| `make sim` / `make sim-clean` | `sim.mk`'s `all` / `clean` |

The three `proc-*` targets are all the same trick: re-enter `prog` with
`PROG_TARGET` overridden, so the compile pipeline is shared verbatim and only
the final dispatch differs.

```
  proc-console  →  prog PROG=<n> PROG_TARGET=rtl-proc-console
                     ↳ builds program.hex
                     ↳ make rtl-proc-console  →  make -C sim -f sim.mk console
```

`PROG_TARGET` defaults to `rtl-proc-test`, so plain `make prog` lands in
`proc.mk`. You can override it on the command line for a one-off:

```
  make prog PROG=subword_test PROG_TARGET=rtl-proc-run     # no Surfer
```

---

## 3. What `make prog` actually does

```
  1.  software/<PROG>.c exists?
        riscv64-elf-gcc -march=rv32i -mabi=ilp32 -T software/link.ld
          -nostdlib -nostartfiles -O1
          -o software/<PROG>.elf  software/crt0.s  software/<PROG>.c
      else software/<PROG>.s exists?
        riscv64-elf-gcc -march=rv32i -mabi=ilp32
          -nostdlib -nostartfiles -Wl,-Ttext=0x0
          -o software/<PROG>.elf  software/<PROG>.s
      else: error out

  2.  riscv64-elf-objcopy -O binary  <PROG>.elf → <PROG>.bin

  3.  python3 one-liner: pad .bin to a multiple of 4, emit one
      little-endian 8-hex-digit word per line → software/rom/program.hex

  4.  make $(PROG_TARGET)
```

### The asymmetry between `.c` and `.s` — this matters

| | `.c` path | `.s` path |
|---|---|---|
| `crt0.s` linked | yes | **no** |
| `link.ld` used | yes | **no** — `-Ttext=0x0` only |
| `.bss` zeroed | yes | no |
| `sp` initialised | yes, from `__stack_top` | **no — you set it yourself** |

So an `.s` test must set up any register it depends on. `subword_test.s` sets
`x2` itself, which is correct for this path.

This asymmetry is also a diagnostic. **If you run an `.s` program and the dump
shows `x2` holding a large stack-like value, the ROM is stale** — that value can
only have come from `crt0`, i.e. from a `.c` build. A branchless `.s` program
reporting nonzero `branches=` says the same thing.

---

## 4. Inside `proc.mk`

```
  all:   $(OUT) $(VPI_LIB)

  $(OUT): $(SOURCES) $(DEPS) $(TBENCH)
      python3 ../../software/imem_depth.py \
        ../../software/rom/program.hex --pow2 \
        --out ../instruction_mem/src/imem_params.vh
      iverilog -g2012 -Wall -I../instruction_mem/src -I../uart/src \
        -o build/vvp/proc_tb.vvp  <sources> <deps> <tb>

  test:  all
      printf 'X' | vvp -M build -m uart_vpi build/vvp/proc_tb.vvp +dump
      surfer build/vcd/proc_tb.vcd >/dev/null 2>&1

  run:   all
      vvp -M build -m uart_vpi build/vvp/proc_tb.vvp        # headless, no +dump

  console: all
      vvp -M build -m uart_vpi build/vvp/proc_tb.vvp        # identical to run
```

Notes that bite:

- **`+dump` is only on `test`.** `run` produces no VCD, so `make rtl-proc-run`
  followed by opening the VCD shows you the previous run's waveform.
- **`console` and `run` are byte-identical recipes.** `console` is vestigial here
  — the real interactive console is `sim.mk`'s.
- **`$(OUT)` does not depend on `$(ROM)`.** Changing `program.hex` alone does not
  relink, so `imem_params.vh` is not regenerated. It doesn't break the run —
  `$readmemh` reads the hex at elaboration time, every run — but the depth
  constant can lag the actual program. (`sim.mk` *does* list `$(ROM)` as a
  prerequisite. The two disagree.)
- **`DEPS` uses `$(wildcard ...)`.** A path typo silently expands to nothing and
  you get an "unknown module" error at elaboration, not a make error.
- **`printf 'X' |`** is left over from `uart.v`'s VPI stdin hook. `uart_top` has
  no VPI hooks, so this feeds a pipe nothing reads.
- **`$(VPI_LIB)` is still a prerequisite of `all`.** Same reason. Both are the
  §10 `P2` "uart.mk still carries the old VPI scaffolding" item, in `proc.mk`.

### Bypassing the root Makefile

```
  make -C rtl/proc -f proc.mk test
  make -C rtl/proc -f proc.mk run
  make -C rtl/proc -f proc.mk clean
```

Useful when you've already got the ROM you want and only changed RTL. Note the
relative paths (`../../software/...`) assume CWD is the module directory, which
`-C` guarantees.

---

## 5. Inside `sim.mk` — currently broken

```
  make -C sim -f sim.mk console      # or: make proc-console PROG=<n>
```

Two faults, both from step 2 of Phase 1.5:

1. **`SOURCES` lists `$(RTL)/uart/src/uart.v` and omits `uart_top.v`,
   `uart_rx.v`, `uart_tx.v`.** `data_mem.v` now instantiates `uart_top`, so
   elaboration fails on an unknown module.
2. **No `-I` flags at all.** Any `` `include `` of `top_params.vh` (or
   `imem_params.vh`) will not resolve. `proc.mk` has
   `-I../instruction_mem/src -I../uart/src`; `sim.mk` has nothing.

Fixing both makes `sim.mk` *elaborate*. It does not make `proc-console` work —
the VPI keyboard path terminated inside `uart.v` and `uart_top` has real
`ser_rx`/`ser_tx` pins with no VPI hooks. That's the open scope question on
`phase.1-5`, not a Makefile bug.

`screen` and `screen_only` differ only in who gets the keystrokes:

- `screen` — SDL runs in the background, `vvp` keeps the terminal's stdin.
- `screen_only` — `sdl_screen | vvp`, so the SDL window's stdout is vvp's stdin.
  Uses `trap 'kill 0'`, which signals the whole process group.

Both `rm -f /tmp/rv32_fb` first, so a stale framebuffer can't be mistaken for a
live one.

---

## 6. Common invocations

```
  make                                   # list modules

  make prog PROG=subword_test            # assemble .s, run, open Surfer
  make prog PROG=c_bubblesort            # compile .c with crt0+link.ld
  make prog PROG=subword_test PROG_TARGET=rtl-proc-run   # headless, no VCD

  make rtl-proc-test                     # re-run the CURRENT program.hex
  make rtl-uart-test                     # uart_top_tb
  make rtl-data_mem-test
  make rtl-proc-clean

  make proc-screen PROG=pong             # SDL window (see §5)

  make -C rtl/proc -f proc.mk run        # bypass root, headless
```

---

## 7. Failure signatures

| Symptom | Cause |
|---|---|
| Register dump doesn't match the program you just wrote | `PROG` passed to a target that ignores it; ROM is stale. Use `make prog`. |
| `.s` program shows `x2` = stack-like value | Same. That value comes from `crt0`, which `.s` builds don't link. |
| Branchless program reports nonzero `branches=` | Same. |
| `$readmemh: Not enough words in the file for the requested range` | Benign — the program is smaller than the array. Not a stale-ROM indicator. |
| `dangling input port N (<name>) floating` | An instantiation is missing a port connection. |
| Unknown module `uart_top` | You're in `sim.mk`. See §5. |
| Waveform doesn't reflect the last run | You ran `run`, not `test`; only `test` passes `+dump`. |
| Surfer opens when you wanted headless | `test` opens it. Use `run`. |
| A module you added isn't in `make test` | No `rtl/<m>/<m>.mk`, or the `.mk` name doesn't match the directory. |
| Elaboration can't find a module you know exists | `DEPS` wildcard path typo — expands to empty, no make error. |

---

## 8. Known issues in the build system

Ordered by how much they can mislead you.

- **`P1` — `sim.mk` compiles `uart.v`, not `uart_top.v`, and has no `-I` paths.**
  Every `sim.mk` target is dead until this is fixed. §5.
- **`P2` — root Makefile help text has `test` and `run` backwards** relative to
  `proc.mk`. Documentation that lies about which target opens a GUI.
- **`P2` — `proc.mk` still builds and loads `uart_vpi`, and pipes `printf 'X'`
  into a reader that no longer exists.** Makes an unused VPI library look
  load-bearing. Matches the §10 `P2` item for `uart.mk`.
- **`P2` — `imem_params.vh` is regenerated on every relink** into
  `rtl/instruction_mem/src/`, while a second stale copy sits in
  `rtl/proc/src/`. §10 marks both for deletion; `unified_memory.v` sizes itself.
  Deleting them means also removing `proc.mk`'s line 66 and
  `software/imem_depth.py`.
- **`P3` — `$(OUT)` in `proc.mk` doesn't depend on `$(ROM)`; in `sim.mk` it
  does.** Pick one.
- **`P3` — `PROG_TARGET := rtl-proc-test          # flip to rtl-proc-run for
  headless`.** The comment is right about the effect but the variable keeps the
  trailing whitespace before the `#` (make strips the comment, not the spaces).
  Harmless today because it's word-split at use. Put the comment on its own line.
- **`P3` — `console` in `proc.mk` duplicates `run` exactly.** Delete it; the
  real console is `sim.mk`'s.

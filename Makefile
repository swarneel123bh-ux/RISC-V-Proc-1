# ============================================================================
# RISC-V-Proc-Proj  --  master Makefile
# RV32I-inspired processor, simulation only (iverilog + vvp + Surfer).
#
# RTL modules are auto-discovered: any rtl/<m>/<m>.mk is picked up. A module
# directory WITHOUT a .mk (e.g. rtl/proc, an unfinished stub) is ignored.
#
# Targets:
#   make                 list discovered modules + usage
#   make rtl-<m>         build  rtl/<m>
#   make rtl-<m>-test    build + run headless
#   make rtl-<m>-run     build + run + open waveform in Surfer
#   make rtl-<m>-clean   remove rtl/<m>/build
#   make test            build + run every module headless
#   make clean           clean every module (+ sim)
#   make prog PROG=<n>   assemble software/<n>.s -> program.hex, run on proc
#   make sim / sim-clean  delegate to sim/sim.mk (co-sim harness, WIP)
#
# Recipe lines use TABS; everything else is 2-space.
# ============================================================================
# Discover modules by the presence of rtl/<m>/<m>.mk (notdir of its parent).
RTL_MODULES := $(notdir $(patsubst %/,%,$(dir $(wildcard rtl/*/*.mk))))
.PHONY: all list test clean sim sim-clean
all: list
list:
	@echo "RISC-V-Proc-Proj  --  discovered RTL modules:"
	@for m in $(RTL_MODULES); do echo "  - $$m"; done
	@echo ""
	@echo "Usage: make rtl-<m> | rtl-<m>-test | rtl-<m>-run | rtl-<m>-clean"
	@echo "       make test   (all modules, headless)"
	@echo "       make clean  (all modules + sim)"
	@echo "       make prog PROG=<name>  (assemble software/<name>.s -> hex, run on proc)"
	@echo "       make uart-console  (interactive UART VPI sim)"
# ---- per-module target generation ------------------------------------------
define RTL_RULES
.PHONY: rtl-$(1) rtl-$(1)-test rtl-$(1)-run rtl-$(1)-clean
rtl-$(1):
	@$$(MAKE) --no-print-directory -C rtl/$(1) -f $(1).mk all
rtl-$(1)-test:
	@$$(MAKE) --no-print-directory -C rtl/$(1) -f $(1).mk test
rtl-$(1)-run:
	@$$(MAKE) --no-print-directory -C rtl/$(1) -f $(1).mk run
rtl-$(1)-clean:
	@$$(MAKE) --no-print-directory -C rtl/$(1) -f $(1).mk clean
endef
$(foreach m,$(RTL_MODULES),$(eval $(call RTL_RULES,$(m))))
# ---- aggregate targets ------------------------------------------------------
test: $(addprefix run-test-,$(RTL_MODULES))
$(addprefix run-test-,$(RTL_MODULES)): run-test-%:
	@echo "==== [$*] ===="
	@$(MAKE) --no-print-directory -C rtl/$* -f $*.mk test
clean: $(addprefix run-clean-,$(RTL_MODULES)) sim-clean
$(addprefix run-clean-,$(RTL_MODULES)): run-clean-%:
	@$(MAKE) --no-print-directory -C rtl/$* -f $*.mk clean
# ---- program build + run ----------------------------------------------------
# Assemble a software/<PROG>.s test into program.hex, then run it on proc.
#   make prog PROG=addi_test
RISCV   := riscv64-elf-gcc
OBJCOPY := riscv64-elf-objcopy
SW_DIR  := software
ROM     := $(SW_DIR)/rom/program.hex
ARCH    := -march=rv32i -mabi=ilp32
LDFLAGS := -nostdlib -nostartfiles -Wl,-Ttext=0x0
PROG_TARGET := rtl-proc-test          # flip to rtl-proc-run for headless
.PHONY: prog
prog:
ifndef PROG
	$(error PROG not set. Usage: make prog PROG=<name>  for software/<name>.s)
endif
	@test -f $(SW_DIR)/$(PROG).s || { echo "no such file: $(SW_DIR)/$(PROG).s"; exit 1; }
	$(RISCV) $(ARCH) $(LDFLAGS) -o $(SW_DIR)/$(PROG).elf $(SW_DIR)/$(PROG).s
	$(OBJCOPY) -O binary $(SW_DIR)/$(PROG).elf $(SW_DIR)/$(PROG).bin
	python3 -c "d=open('$(SW_DIR)/$(PROG).bin','rb').read(); d+=b'\x00'*((-len(d))%4); open('$(ROM)','w').write('\n'.join(f'{int.from_bytes(d[i:i+4],\"little\"):08x}' for i in range(0,len(d),4))+'\n')"
	@$(MAKE) --no-print-directory $(PROG_TARGET)
# ---- interactive VPI console -----------------------------------------------
.PHONY: uart-console
uart-console:
	@$(MAKE) --no-print-directory -C rtl/uart -f uart.mk console
# ---- sim/ delegation (Verilator co-sim harness, work in progress) ----------
sim:
	@$(MAKE) --no-print-directory -C sim -f sim.mk all
sim-clean:
	@$(MAKE) --no-print-directory -C sim -f sim.mk clean

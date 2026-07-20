# ============================================================================
# proc.mk  --  unit build/sim for the `proc` module
# Invoked from the repo root as:  make rtl-proc / rtl-proc-test / rtl-proc-run
# Run directly with:              make -C rtl/proc -f proc.mk test
# Recipe lines use TABS (make requirement); everything else is 2-space.
# ============================================================================

IVERILOG := iverilog
VVP      := vvp
SURFER   := surfer
FLAGS    := -g2012 -Wall

SRC_DIR := src
TB_DIR  := tb
BUILD   := build
VVP_DIR := $(BUILD)/vvp
VCD_DIR := $(BUILD)/vcd

MODULE  := proc
TB      := $(MODULE)_tb

# Own RTL + any cross-module RTL this module instantiates (none here).
SOURCES := $(SRC_DIR)/$(MODULE).v
DEPS := $(wildcard \
	../add4/src/*.v \
	../mux2x1_32/src/*.v \
	../program_counter/src/*.v \
	../instruction_mem/src/*.v \
	../regfile/src/*.v \
	../immdataext/src/immdataext.v \
	../cu/src/cu.v \
	../alu/src/alu.v \
	../alu_control/src/alu_control.v \
	../data_mem/src/data_mem.v)
TBENCH  := $(TB_DIR)/$(TB).v

OUT  := $(VVP_DIR)/$(TB).vvp
WAVE := $(VCD_DIR)/$(TB).vcd

.PHONY: all test run clean
all: $(OUT)

$(OUT): $(SOURCES) $(DEPS) $(TBENCH)
	python3 ../../software/imem_depth.py ../../software/rom/program.hex --pow2 --out ../instruction_mem/src/imem_params.vh
	@mkdir -p $(VVP_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) -I../instruction_mem/src -o $@ $(SOURCES) $(DEPS) $(TBENCH)

test: all
	@mkdir -p $(VCD_DIR)
	$(VVP) $(OUT) +dump
	$(SURFER) $(WAVE) >/dev/null 2>&1

run: all
	$(VVP) $(OUT)

clean:
	rm -rf $(BUILD)

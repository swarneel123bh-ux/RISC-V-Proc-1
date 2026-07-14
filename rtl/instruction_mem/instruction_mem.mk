# ============================================================================
# instruction_mem.mk  --  unit build/sim for the `instruction_mem` module
# From repo root:  make rtl-instruction_mem / rtl-instruction_mem-test / rtl-instruction_mem-run
# Direct:          make -C rtl/instruction_mem -f instruction_mem.mk test
# Recipe lines use TABS; everything else 2-space.
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
MODULE  := instruction_mem
TB      := $(MODULE)_tb
SOURCES := $(SRC_DIR)/$(MODULE).v
DEPS    :=
TBENCH  := $(TB_DIR)/$(TB).v
OUT  := $(VVP_DIR)/$(TB).vvp
WAVE := $(VCD_DIR)/$(TB).vcd
.PHONY: all test run clean
all: $(OUT)
$(OUT): $(SOURCES) $(DEPS) $(TBENCH)
	python3 ../../software/imem_depth.py ../../software/rom/program.hex --pow2 --out $(SRC_DIR)/imem_params.vh
	@mkdir -p $(VVP_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) -I$(SRC_DIR) -o $@ $(SOURCES) $(DEPS) $(TBENCH)
test: all
	$(VVP) $(OUT) +dump
run: all
	$(VVP) $(OUT) +dump
	$(SURFER) $(WAVE) >/dev/null 2>&1
clean:
	rm -rf $(BUILD)

# ============================================================================
# program_counter.mk  --  unit build/sim for the `program_counter` module
# From repo root:  make rtl-program_counter / rtl-program_counter-test / rtl-program_counter-run
# Direct:          make -C rtl/program_counter -f program_counter.mk test
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
MODULE  := program_counter
TB      := $(MODULE)_tb
SOURCES := $(SRC_DIR)/$(MODULE).v
DEPS    :=
TBENCH  := $(TB_DIR)/$(TB).v
OUT  := $(VVP_DIR)/$(TB).vvp
WAVE := $(VCD_DIR)/$(TB).vcd
.PHONY: all test run clean
all: $(OUT)
$(OUT): $(SOURCES) $(DEPS) $(TBENCH)
	@mkdir -p $(VVP_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) -o $@ $(SOURCES) $(DEPS) $(TBENCH)
test: all
	$(VVP) $(OUT) +dump
run: all
	$(VVP) $(OUT) +dump
	$(SURFER) $(WAVE) >/dev/null 2>&1
clean:
	rm -rf $(BUILD)

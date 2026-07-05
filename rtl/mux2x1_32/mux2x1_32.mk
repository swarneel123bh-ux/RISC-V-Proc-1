# ============================================================================
# mux2x1_32.mk  --  unit build/sim for the `mux2x1_32` module
# From repo root:  make rtl-mux2x1_32 / rtl-mux2x1_32-test / rtl-mux2x1_32-run
# Direct:          make -C rtl/mux2x1_32 -f mux2x1_32.mk test
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
MODULE  := mux2x1_32
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

# ============================================================================
# forwarding_unit.mk  --  unit build/sim for the `forwarding_unit` module
# From repo root:  make rtl-forwarding_unit / rtl-forwarding_unit-test / rtl-forwarding_unit-run
# Direct:          make -C rtl/forwarding_unit -f forwarding_unit.mk test
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
MODULE  := forwarding_unit
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

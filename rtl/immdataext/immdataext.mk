# ============================================================================
# immdataext.mk  --  unit build/sim for the `immdataext` module
# From repo root:  make rtl-immdataext / rtl-immdataext-test / rtl-immdataext-run
# Direct:          make -C rtl/immdataext -f immdataext.mk test
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
MODULE  := immdataext
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

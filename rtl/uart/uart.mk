# ============================================================================
# uart.mk  --  unit build/sim for the `uart` module
# uart.v calls $uart_init / $uart_rx_read, provided by a VPI library compiled
# from vpi/uart_vpi.c. We build that .vpi into build/ and load it with
# `vvp -M build -m uart_vpi`.
# Recipe lines use TABS.
# ============================================================================

IVERILOG    := iverilog
IVERILOG_VPI:= iverilog-vpi
VVP         := vvp
SURFER      := surfer
FLAGS       := -g2012 -Wall

SRC_DIR := src
TB_DIR  := tb
VPI_DIR := vpi
BUILD   := build
VVP_DIR := $(BUILD)/vvp
VCD_DIR := $(BUILD)/vcd

MODULE  := uart
TB      := $(MODULE)_tb

SOURCES := $(SRC_DIR)/$(MODULE).v
DEPS    :=
TBENCH  := $(TB_DIR)/$(TB).v

OUT     := $(VVP_DIR)/$(TB).vvp
WAVE    := $(VCD_DIR)/$(TB).vcd
VPI_SRC := $(VPI_DIR)/uart_vpi.c
VPI_LIB := $(BUILD)/uart_vpi.vpi
VPI_RUN := -M $(BUILD) -m uart_vpi

.PHONY: all vpi test run console clean
all: $(OUT) $(VPI_LIB)

vpi: $(VPI_LIB)

# iverilog-vpi writes uart_vpi.{o,vpi} into its CWD, so build inside $(BUILD).
$(VPI_LIB): $(VPI_SRC)
	@mkdir -p $(BUILD)
	cd $(BUILD) && $(IVERILOG_VPI) ../$(VPI_SRC) --name=uart_vpi

$(OUT): $(SOURCES) $(DEPS) $(TBENCH)
	@mkdir -p $(VVP_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) -o $@ $(SOURCES) $(DEPS) $(TBENCH)

# uart_tb does an RX read; feed one keypress non-interactively under `test`.
test: all
	printf 'X' | $(VVP) $(VPI_RUN) $(OUT)

console: all
	@echo "[uart] interactive VPI console — type input, see output; ends on \$$finish or Ctrl-C"
	$(VVP) $(VPI_RUN) $(OUT)

run: all
	$(VVP) $(VPI_RUN) $(OUT)
	$(SURFER) $(WAVE) >/dev/null 2>&1

clean:
	rm -rf $(BUILD)

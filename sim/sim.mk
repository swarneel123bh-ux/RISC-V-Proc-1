# ============================================================================
# sim.mk -- system-level interactive harness: full proc + unified_memory + UART,
# running indefinitely (no $finish). Live keyboard via the uart VPI.
#   make -C sim -f sim.mk console     (runs until Ctrl-C)
# Driven from the repo root via: make proc-console PROG=<name>
# vvp runs with CWD = sim/, so program.hex is one level up: ../software/...
# Recipe lines use TABS.
# ============================================================================
IVERILOG     := iverilog
IVERILOG_VPI := iverilog-vpi
VVP          := vvp
FLAGS        := -g2012 -Wall

RTL     := ../rtl
SRC_DIR := src
BUILD   := build
VVP_DIR := $(BUILD)/vvp
VCD_DIR := $(BUILD)/vcd
TB      := sim_tb
TBENCH  := $(SRC_DIR)/$(TB).v

VPI_SRC     := $(RTL)/uart/vpi/uart_vpi.c
VPI_LIB     := $(BUILD)/uart_vpi.vpi
GPU_VPI_SRC := $(RTL)/vram/vpi/gpu_vpi.c
GPU_VPI_LIB := $(BUILD)/gpu_vpi.vpi

# Full processor RTL + uart (mirrors proc.mk's dependency set).
SOURCES := \
  $(RTL)/proc/src/proc.v \
  $(RTL)/add4/src/add4.v \
  $(RTL)/mux2x1_32/src/mux2x1_32.v \
  $(RTL)/program_counter/src/program_counter.v \
  $(RTL)/instruction_mem/src/instruction_mem.v \
  $(RTL)/regfile/src/regfile.v \
  $(RTL)/immdataext/src/immdataext.v \
  $(RTL)/cu/src/cu.v \
  $(RTL)/alu/src/alu.v \
  $(RTL)/alu_control/src/alu_control.v \
  $(RTL)/data_mem/src/data_mem.v \
  $(RTL)/uart/src/uart.v \
  $(RTL)/branch_unit/src/branch_unit.v \
  $(RTL)/forwarding_unit/src/forwarding_unit.v \
  $(RTL)/hazard_detection_unit/src/hazard_detection_unit.v \
  $(RTL)/mem_wrapper/src/mem_wrapper.v \
  $(RTL)/unified_memory/src/unified_memory.v \
  $(RTL)/vram/src/vram.v

OUT     := $(VVP_DIR)/$(TB).vvp
ROM     := ../software/rom/program.hex
HEXPATH := ../software/rom/program.hex

VPI_SRC := $(RTL)/uart/vpi/uart_vpi.c
VPI_LIB := $(BUILD)/uart_vpi.vpi
VPI_RUN := -M $(BUILD) -m uart_vpi -m gpu_vpi

.PHONY: all vpi console clean screen screen_only
all: $(OUT) $(VPI_LIB) $(GPU_VPI_LIB)
vpi: $(VPI_LIB) $(GPU_VPI_LIB)

$(VPI_LIB): $(VPI_SRC)
	@mkdir -p $(BUILD)
	cd $(BUILD) && $(IVERILOG_VPI) ../$(VPI_SRC) --name=uart_vpi

$(GPU_VPI_LIB): $(GPU_VPI_SRC)
	@mkdir -p $(BUILD)
	cd $(BUILD) && $(IVERILOG_VPI) ../$(GPU_VPI_SRC) --name=gpu_vpi

$(OUT): $(SOURCES) $(TBENCH) $(ROM)
	@mkdir -p $(VVP_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) -DUMEM_HEXFILE='"$(HEXPATH)"' -o $@ $(SOURCES) $(TBENCH)

console: all
	$(VVP) $(VPI_RUN) $(OUT)

clean:
	rm -rf $(BUILD)

# ---- SDL display process ----
SDL_SRC := $(SRC_DIR)/sdl_screen.c            # adjust if you put it elsewhere
SDL_BIN := $(BUILD)/sdl_screen

$(SDL_BIN): $(SDL_SRC)
	@mkdir -p $(BUILD)
	cc -O2 -o $@ $< $$(sdl2-config --cflags --libs)

# Graphics window + UART keyboard in the terminal.
screen: all $(SDL_BIN)
	@rm -f /tmp/rv32_fb
	@$(SDL_BIN) & SDLPID=$$!; \
	 trap "kill $$SDLPID 2>/dev/null" EXIT INT TERM; \
	 $(VVP) $(VPI_RUN) $(OUT)

# Graphics window + keyboard captured BY the window (for playing).
screen_only: all $(SDL_BIN)
	@rm -f /tmp/rv32_fb
	@trap 'kill 0' INT TERM; $(SDL_BIN) | $(VVP) $(VPI_RUN) $(OUT)

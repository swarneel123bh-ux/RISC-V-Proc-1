TOP       := proc
SRC_DIR   := src
TB_DIR    := tb
BUILD_DIR := build
VPI_DIR   := vpi

IVERILOG     := iverilog
VVP_CMD      := vvp
SURFER       := surfer
COMMON_FLAGS := -g2012 -Wall
VPI_FLAGS    := -M $(BUILD_DIR) -m uart_vpi

ifeq ($(OS),Windows_NT)
  RM      := rmdir /s /q
  MKDIR   := if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
  NULLDEV := NUL
else
  RM      := rm -rf
  MKDIR   := mkdir -p $(BUILD_DIR)
  NULLDEV := /dev/null
endif

.PHONY: all clean rebuild list

ifdef name
MODULE := $(patsubst %_tb,%,$(name))
OUT    := $(BUILD_DIR)/$(name).vvp
WAVE   := $(BUILD_DIR)/$(name).vcd

all:
	@$(MKDIR)
	@echo "[VPI]   Building VPI library"
	cd $(BUILD_DIR) && iverilog-vpi ../$(VPI_DIR)/uart_vpi.c --name=uart_vpi
	@echo "[BUILD] $(SRC_DIR)/$(MODULE).v + $(TB_DIR)/$(name).v"
	$(IVERILOG) $(COMMON_FLAGS) -o $(OUT) $(SRC_DIR)/$(MODULE).v $(TB_DIR)/$(name).v
	@echo "[RUN]   Running simulation"
	$(VVP_CMD) $(VPI_FLAGS) $(OUT)
	@echo "[WAVE]  Opening waveform"
	$(SURFER) $(WAVE)

else
OUT  := $(BUILD_DIR)/$(TOP).vvp
WAVE := $(BUILD_DIR)/$(TOP).vcd

all:
	@$(MKDIR)
	@echo "[VPI]   Building VPI library"
	cd $(BUILD_DIR) && iverilog-vpi ../$(VPI_DIR)/uart_vpi.c --name=uart_vpi
	@echo "[BUILD] All RTL + $(TB_DIR)/$(TOP)_tb.v"
	$(IVERILOG) $(COMMON_FLAGS) -o $(OUT) $(wildcard $(SRC_DIR)/*.v) $(TB_DIR)/$(TOP)_tb.v
	@echo "[RUN]   Running simulation"
	$(VVP_CMD) $(VPI_FLAGS) $(OUT)
	@echo "[WAVE]  Opening waveform"
	$(SURFER) $(WAVE)
endif

clean:
	@$(RM) $(BUILD_DIR) 2>$(NULLDEV)

rebuild: clean all

list:
ifdef name
	@echo "Module    : $(SRC_DIR)/$(MODULE).v"
	@echo "Testbench : $(TB_DIR)/$(name).v"
	@echo "Output    : $(OUT)"
	@echo "Waveform  : $(WAVE)"
else
	@echo "Sources   : $(wildcard $(SRC_DIR)/*.v)"
	@echo "Testbench : $(TB_DIR)/$(TOP)_tb.v"
	@echo "Output    : $(OUT)"
	@echo "Waveform  : $(WAVE)"
endif

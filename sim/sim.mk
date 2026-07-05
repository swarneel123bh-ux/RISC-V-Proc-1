# ============================================================================
# sim.mk  --  system-level simulation harness (PLACEHOLDER / WIP)
#
# The per-module testbenches under rtl/<m>/tb live with iverilog + the UART
# VPI. This directory is reserved for a full-processor / co-simulation harness
# (e.g. a Verilator C++ driver, or a top-level proc_tb once rtl/proc is real),
# mirroring the sim/ stage of the Modbus project.
#
# Nothing builds yet -- the proc top is still a stub (see rtl/proc/src/proc.v).
# Recipe lines use TABS.
# ============================================================================

BUILD := build

.PHONY: all clean
all:
	@echo "[sim] No system-level harness yet."
	@echo "[sim] Add sources under sim/src/ and wire them up here."
	@echo "[sim] (proc top is a stub: rtl/proc/src/proc.v)"

clean:
	@rm -rf $(BUILD)

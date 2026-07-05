#!/usr/bin/env python3
"""Scaffold rtl/<name>/ : src/, tb/, and <name>.mk. Creates missing pieces
only; never overwrites an existing file.
Usage: python3 create_module.py <name> [<name> ...]"""
import os, re, sys

MK_TEMPLATE = """\
# ============================================================================
# {name}.mk  --  unit build/sim for the `{name}` module
# From repo root:  make rtl-{name} / rtl-{name}-test / rtl-{name}-run
# Direct:          make -C rtl/{name} -f {name}.mk test
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
MODULE  := {name}
TB      := $(MODULE)_tb
SOURCES := $(SRC_DIR)/$(MODULE).v
DEPS    :=
TBENCH  := $(TB_DIR)/$(TB).v
OUT  := $(VVP_DIR)/$(TB).vvp
WAVE := $(VCD_DIR)/$(TB).vcd
.PHONY: all test run clean
all: $(OUT)
$(OUT): $(SOURCES) $(DEPS) $(TBENCH)
\t@mkdir -p $(VVP_DIR) $(VCD_DIR)
\t$(IVERILOG) $(FLAGS) -o $@ $(SOURCES) $(DEPS) $(TBENCH)
test: all
\t$(VVP) $(OUT) +dump
run: all
\t$(VVP) $(OUT) +dump
\t$(SURFER) $(WAVE) >/dev/null 2>&1
clean:
\trm -rf $(BUILD)
"""

SRC_TEMPLATE = """\
`timescale 1ns / 1ps
module {name} (
  // TODO: ports
);
  // TODO: implementation
endmodule
"""

TB_TEMPLATE = """\
`timescale 1ns / 1ps
module {name}_tb ();
  // TODO: declare signals and instantiate {name}
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("build/vcd/{name}_tb.vcd");
      $dumpvars(0, {name}_tb);
    end
    // TODO: stimulus
    #100;
    $finish;
  end
endmodule
"""

NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*$")

def find_root():
  d = os.getcwd()
  while True:
    if os.path.isdir(os.path.join(d, "rtl")):
      return d
    p = os.path.dirname(d)
    if p == d:
      return None
    d = p

def write_if_absent(path, content):
  if os.path.exists(path):
    print("  skip (exists):", path)
    return
  with open(path, "w") as f:
    f.write(content)
  print("  create:", path)

def scaffold(root, name):
  if not NAME_RE.match(name):
    print("  invalid module name:", name)
    return
  base = os.path.join(root, "rtl", name)
  os.makedirs(os.path.join(base, "src"), exist_ok=True)
  os.makedirs(os.path.join(base, "tb"), exist_ok=True)
  write_if_absent(os.path.join(base, "src", name + ".v"), SRC_TEMPLATE.format(name=name))
  write_if_absent(os.path.join(base, "tb", name + "_tb.v"), TB_TEMPLATE.format(name=name))
  write_if_absent(os.path.join(base, name + ".mk"), MK_TEMPLATE.format(name=name))

def main():
  if len(sys.argv) < 2:
    print("usage: python3 create_module.py <name> [<name> ...]")
    sys.exit(1)
  root = find_root()
  if root is None:
    print("error: no rtl/ dir found (run inside the project)")
    sys.exit(1)
  for name in sys.argv[1:]:
    print("module", name + ":")
    scaffold(root, name)

if __name__ == "__main__":
  main()

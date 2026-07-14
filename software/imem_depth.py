"""Compute instruction-memory depth (in words) from a $readmemh hex file.

Counts data words, ignoring blank lines, comments (// or #), and @-address
directives. Rounds up to a power of two (nice for $clog2 addressing).

Usage:
  python3 imem_depth.py <program.hex>                 # print depth
  python3 imem_depth.py <program.hex> --out imem_params.vh   # also write header
"""

import argparse
import math
import sys


def count_words(path):
    n = 0
    with open(path) as f:
        for line in f:
            s = line.split("//", 1)[0].split("#", 1)[0].strip()
            if not s:
                continue
            for tok in s.split():
                if tok.startswith("@"):  # address directive, not a word
                    continue
                n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hexfile")
    ap.add_argument("--out")
    ap.add_argument("--min", type=int, default=1, help="floor for depth (default 1)")
    ap.add_argument("--pow2", action="store_true", help="round up to a power of two")
    args = ap.parse_args()

    try:
        words = count_words(args.hexfile)
    except FileNotFoundError:
        sys.exit(f"error: {args.hexfile} not found")

    depth = max(words, args.min, 1)
    if args.pow2:
        depth = 1 << math.ceil(math.log2(depth))

    if args.out:
        with open(args.out, "w") as f:
            f.write(
                f"// AUTO-GENERATED — do not edit. Regenerated from {args.hexfile}\n"
            )
            f.write(f"`define IMEM_DEPTH {depth}\n")
        print(f"{args.out}: `define IMEM_DEPTH {depth}  ({words} words)")
    else:
        print(depth)


if __name__ == "__main__":
    main()

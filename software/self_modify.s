# self_modify.s — HARNESS, not Swarneel's code.
#
# Proves that a store into the code region becomes fetchable, i.e. that the
# instruction mirror in unified_memory is coherent with the data array.
# Also measures the effective FENCE.I distance: shrink NOP_GAP until it
# breaks, and that number is how far ahead the pipeline has already fetched.
#
# Result convention, readable from the proc_tb register dump:
#   a0 (x10) == 10      -> the patched instruction executed
#   a1 (x11) == 0x600D  -> pass
#   a1 (x11) == 0x0BAD  -> fail
#
# Build: make prog PROG=self_modify
# .s builds link neither crt0 nor link.ld, so _start is the entry and
# `scratch` lands wherever the assembler puts it — always below 8 KB for a
# program this size, which is what the mirror requires.

  .section .text
  .globl _start

_start:
  la    t0, scratch             # auipc+addi, PC-relative: base-independent

  li    a0, 0                   # poison. Must become 10, and 0 is NOT a
                                # plausible accidental value for this test.

  # ---- write two instructions into scratch ----
  li    t1, 0x00A00513          # addi a0, x0, 10
  sw    t1, 0(t0)
  li    t1, 0x00008067          # jalr x0, 0(ra)   (i.e. ret)
  sw    t1, 4(t0)

  # ---- gap. Shrink this to find the real FENCE.I distance. ----
  .set NOP_GAP, 0
  .rept NOP_GAP
  nop
  .endr

  jalr  ra, t0, 0               # call scratch. Taken, so IF/ID is flushed
                                # and the fetch that follows is post-store.

  # ---- verify ----
  li    t2, 10
  bne   a0, t2, fail

pass:
  li    a1, 0x600D
  j     done
fail:
  li    a1, 0x0BAD
done:
  j     done                    # spin. proc_tb dumps registers at +cycles.

# scratch sits in .text so it is inside the mirrored region. Initialised to
# an illegal-ish value rather than 0, so a run where the stores never landed
# does not accidentally look like a NOP slide.
  .align 2
scratch:
  .word 0xFFFFFFFF
  .word 0xFFFFFFFF

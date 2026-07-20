.section .text
.globl _start
_start:
    addi  x1, x0, 1          # x1=1  (runs; marker that we started)
    # NEED NOPS HERE BECAUSE FORWARDING UNIT NEEDED TO RESOLVE JAL PROPERLY
    nop
    nop
    nop

    # ---- JAL: jump forward, skip the poison, link to x5 ----
    jal   x5, jal_target
    addi  x2, x0, 0x7AD      # POISON: must be SKIPPED -> x2 stays 0

jal_target:
    addi  x3, x0, 7          # x3=7  proves JAL landed

    # ---- set up equal operands for branches (spaced, no forwarding) ----
    addi  x6, x0, 5          # x6=5
    addi  x7, x0, 5          # x7=5

    # ---- BEQ taken (5==5): skip poison, land ----
    beq   x6, x7, beq_target
    addi  x4, x0, 0x6EA      # POISON: skipped -> x4 stays 0

beq_target:
    addi  x10, x0, 9         # x10=9 proves BEQ-taken landed

    # ---- BNE not taken (5==5 -> not taken): fall through ----
    bne   x6, x7, bne_wrong
    addi  x11, x0, 0x11      # SHOULD run (bne not taken) -> x11=0x11
    jal   x0, after_bne      # skip the wrong-target block (jal x0 = plain jump)

bne_wrong:
    addi  x11, x0, 0x7AD     # must NOT run

after_bne:
    # ---- JALR: load a target addr into x12, jump through it ----
    la    x12, jalr_target   # x12 = &jalr_target  (pseudo-op; see note)
    # NOPS NEEDED HERE BECAUSE DATA NEEDS TO BE FORWARDED (LA IS PSEUDO INSTR, EXPANDS TO ADDI)
    nop
    nop
    nop
    jalr  x13, 0(x12)        # jump to x12, link x13
    addi  x15, x0, 0x7AD     # POISON: skipped -> x15 stays 0
    addi x16, x0, 0x7AD				# POISON: skipped -> x16 stays 0 (jalr skips next two instructions, so the target need
    # to be at least two instructions away ??)

jalr_target:
    addi  x14, x0, 0xBE      # x14=0x22 proves JALR landed

hang_:
		la x25, hang
		# SAME REASON NOPS NEEDED HERE
		nop
		nop
		nop
hang:			 # Loop indefinitely
		jalr x26, 0(x25)
		addi x20, x0, 0x7AD					# POISON

noexec:
		la x27, 0xAB

.section .text.init
.globl _start
_start:
    # ── 1. Set stack pointer ─────────────────────────────
    la sp, _stack_top
    la t0, trap_handler
    csrw mtvec, t0

<<<<<<< HEAD
    la a0, _bss_start
    la a1, _bss_end

bss_loop:
    bge a0, a1, bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j bss_loop
bss_done:
    jal ra, main
=======
    # ── 2. Set trap vector ───────────────────────────────
    la t0, trap_handler
    csrw mtvec, t0
>>>>>>> 9257098 (removed vcd files)

    # ── 3. Copy .rodata from LMA (IMEM) to VMA (DMEM) ───
    la a0, _rodata_lma      # source:      packed after .text in hex file
    la a1, _rodata_start    # destination: DMEM VMA
    la a2, _rodata_end
rodata_loop:
    bge a1, a2, rodata_done
    lw  t0, 0(a0)
    sw  t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j rodata_loop
rodata_done:

    # ── 4. Copy .data from LMA (IMEM) to VMA (DMEM) ─────
    la a0, _data_lma        # source:      packed after .rodata in hex file
    la a1, _data_start      # destination: DMEM VMA
    la a2, _data_end
data_loop:
    bge a1, a2, data_done
    lw  t0, 0(a0)
    sw  t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j data_loop
data_done:

    # ── 5. Zero .bss ─────────────────────────────────────
    la a0, _bss_start
    la a1, _bss_end
bss_loop:
    bge a0, a1, bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j bss_loop
bss_done:

    # ── 6. Jump to main ──────────────────────────────────
    jal ra, main
hang:
    j hang

.section .text.init
.globl _start

_start:
    # stack in DMEM (adjust size as needed)
    la sp, _stack_top
    la t0, trap_handler
    csrw mtvec, t0

    la a0, _bss_start
    la a1, _bss_end

bss_loop:
    bge a0, a1, bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j bss_loop
bss_done:
    jal ra, main

hang:
    j hang

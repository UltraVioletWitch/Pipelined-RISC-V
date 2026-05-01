.section .text.init
.globl _start

_start:
    # stack in DMEM (adjust size as needed)
    la sp, _stack_top

    call main

hang:
    j hang

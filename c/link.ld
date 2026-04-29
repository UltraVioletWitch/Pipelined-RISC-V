/* Simple linker script for bare-metal RISC-V CPU */

ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS
{
    /* Code section */
    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    /* Read-only data */
    .rodata : {
        *(.rodata*)
    } > IMEM

    /* Initialized data */
    .data : {
        *(.data*)
    } > DMEM

    /* Uninitialized data (BSS) */
    .bss : {
        *(.bss*)
        *(COMMON)
    } > DMEM

    /* Stack (grows downward) */
    . = ORIGIN(DMEM) + LENGTH(DMEM);
    _stack_top = .;
}

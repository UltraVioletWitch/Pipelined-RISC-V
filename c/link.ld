ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x4000
    DMEM (rw)  : ORIGIN = 0x00004000, LENGTH = 0x4000
}

SECTIONS
{
    . = ORIGIN(IMEM);

    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    .rodata : {
        *(.rodata*)
    } > IMEM

    .data : {
        *(.data*)
    } > DMEM

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DMEM

    . = ORIGIN(DMEM) + LENGTH(DMEM);
    _stack_top = .;
}

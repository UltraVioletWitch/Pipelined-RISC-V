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
        _rodata_start = .;
        *(.rodata*)
        _rodata_end = .;
    } > DMEM AT> IMEM
    _rodata_lma = LOADADDR(.rodata);

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > DMEM AT> IMEM
    _data_lma = LOADADDR(.data);

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DMEM

    . = ORIGIN(DMEM) + LENGTH(DMEM);
    _stack_top = .;
}

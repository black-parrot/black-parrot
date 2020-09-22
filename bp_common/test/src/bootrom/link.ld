SECTIONS
{
    . = 0x0000;
    .text.start : { *(.text.start) }
    . = 0x0120;
    .data.ucode : { *(.data.ucode) }
}

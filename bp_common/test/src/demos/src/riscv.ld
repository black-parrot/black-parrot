OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS {
. = 0x80000000;
.text.init : { *(.text.init) }
.text.emu . : { *(.text.emu) }
.text.amo . : { *(.text.amo) }
.text : { *(.text) }
.data : { *(.data) }
.sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
}

/* bss segment */
.sbss : {
  *(.sbss .sbss.* .gnu.linkonce.sb.*)
  *(.scommon)
}
.bss            :
  {
   *(.dynbss)
   *(.bss .bss.* .gnu.linkonce.b.*)
   *(COMMON)
   /* Align here to ensure that the .bss section occupies space up to
      _end.  Align after .bss to ensure correct alignment even if the
      .bss section disappears because there are no input sections.
      FIXME: Why do we need it? When there is no .bss section, we don't
      pad the .data section.  */
   . = ALIGN(. != 0 ? 32 / 8 : 1);
  }

/* thread-local data segment */
  .tdata :
  {
    _tls_data = .;
    *(.tdata.begin)
    *(.tdata)
    *(.tdata.end)
  }
  .tbss :
  {
    *(.tbss)
    *(.tbss.end)
  }

  /* End of uninitalized data segement */
  _end = .;
}

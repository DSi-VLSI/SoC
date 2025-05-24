ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x40000000, LENGTH = 128M
  PERIPHERALS (rwx) : ORIGIN = 0x20000000, LENGTH = 0x2000
}

SECTIONS
{

  .tohost_section 0x20000000 :
  {
    . = ALIGN(8);
    tohost = .;
    QUAD(0);
  } > PERIPHERALS

  .putchar_stdout_section 0x20001000 :
  {
    . = ALIGN(8);
    putchar_stdout = .;
    QUAD(0);
  } > PERIPHERALS

  . = ORIGIN(RAM);

  .text :
  {
    _start = .;
    *(.text)
    *(.text.*)
  } > RAM

  .rodata :
  {
    *(.rodata)
    *(.rodata.*)
  } > RAM

  .data :
  {
    *(.data)
    *(.data.*)
  } > RAM

  .bss :
  {
    *(.bss)
    *(.bss.*)
    *(COMMON)
  } > RAM

  _end = ALIGN(8);
}

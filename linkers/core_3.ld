ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x40060000, LENGTH = 128M
  PERIPHERALS (rwx) : ORIGIN = 0x20000000, LENGTH = 0x4000
}

SECTIONS
{

  .tohost_section 0x20000018 :
  {
    . = ALIGN(8);
    tohost = .;
    QUAD(0);
  } > PERIPHERALS

  .fromhost_section 0x20001018 :
  {
    . = ALIGN(8);
    fromhost = .;
    QUAD(0);
  } > PERIPHERALS

  .putchar_stdout_section 0x20002018 (NOLOAD) :
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

.section .data

.align 3
.globl tohost
tohost: .dword 0

.align 3
.globl putchar_stdout
putchar_stdout: .dword 0

.align 3
.section .text
.globl _start
_start:
    call main

_exit:
    la t0, tohost
    sd a0, 0(t0)

_forever_loop:
    j _forever_loop

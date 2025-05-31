.section .data
.align 3
.globl tohost
tohost: .dword 0

.section .data
    float_data: .word 0x40400000

.section .text
.align 3
.globl _start
_start:

    li t1, 0x00004000
    csrs mstatus, t1

    la x5, float_data
    flw f0, 0(x5)

_exit:
    la t0, tohost
    sd a0, 0(t0)

_forever_loop:
    j _forever_loop

.section .data
.align 3
.globl tohost
tohost: .dword 0

.section .rodata
.align 3
MEM00_FINAL_VALUE: .byte -4
MEM01_FINAL_VALUE: .byte -1
MEM02_FINAL_VALUE: .byte -3
MEM03_FINAL_VALUE: .byte -1
MEM04_FINAL_VALUE: .byte -2
MEM05_FINAL_VALUE: .byte -1
MEM06_FINAL_VALUE: .byte -1
MEM07_FINAL_VALUE: .byte -1
MEM08_FINAL_VALUE: .byte  0
MEM09_FINAL_VALUE: .byte  0
MEM10_FINAL_VALUE: .byte  1
MEM11_FINAL_VALUE: .byte  0
MEM12_FINAL_VALUE: .byte  2
MEM13_FINAL_VALUE: .byte  0
MEM14_FINAL_VALUE: .byte  3
MEM15_FINAL_VALUE: .byte  0

.section .data
.align 3
MEM00_WRITE_VALUE: .byte 0
MEM01_WRITE_VALUE: .byte 0
MEM02_WRITE_VALUE: .byte 0
MEM03_WRITE_VALUE: .byte 0
MEM04_WRITE_VALUE: .byte 0
MEM05_WRITE_VALUE: .byte 0
MEM06_WRITE_VALUE: .byte 0
MEM07_WRITE_VALUE: .byte 0
MEM08_WRITE_VALUE: .byte 0
MEM09_WRITE_VALUE: .byte 0
MEM10_WRITE_VALUE: .byte 0
MEM11_WRITE_VALUE: .byte 0
MEM12_WRITE_VALUE: .byte 0
MEM13_WRITE_VALUE: .byte 0
MEM14_WRITE_VALUE: .byte 0
MEM15_WRITE_VALUE: .byte 0

.section .text
_start:
    la t0, MEM08_WRITE_VALUE

    li t1,  0
    sh t1,  0(t0)

    li t1,  1
    sh t1,  2(t0)

    li t1,  2
    sh t1,  4(t0)

    li t1,  3
    sh t1,  6(t0)

    li t1, -1
    sh t1, -2(t0)

    li t1, -2
    sh t1, -4(t0)

    li t1, -3
    sh t1, -6(t0)

    li t1, -4
    sh t1, -8(t0)

    li a0, 0

    la t0, tohost
    sd a0, 0(t0)

_forever_loop:
    j _forever_loop

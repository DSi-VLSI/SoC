.section .rodata
.align 3
GPR00_CHECK: .dword 1
GPR00_VALUE: .dword 0
GPR01_CHECK: .dword 1
GPR01_VALUE: .dword 1
GPR02_CHECK: .dword 1
GPR02_VALUE: .dword 2
GPR03_CHECK: .dword 1
GPR03_VALUE: .dword 3
GPR04_CHECK: .dword 1
GPR04_VALUE: .dword 4
GPR05_CHECK: .dword 1
GPR05_VALUE: .dword 5
GPR06_CHECK: .dword 1
GPR06_VALUE: .dword 6
GPR07_CHECK: .dword 1
GPR07_VALUE: .dword 7
GPR08_CHECK: .dword 1
GPR08_VALUE: .dword 8
GPR09_CHECK: .dword 1
GPR09_VALUE: .dword 9
GPR10_CHECK: .dword 1
GPR10_VALUE: .dword 10
GPR11_CHECK: .dword 1
GPR11_VALUE: .dword 11
GPR12_CHECK: .dword 1
GPR12_VALUE: .dword 12
GPR13_CHECK: .dword 1
GPR13_VALUE: .dword 13
GPR14_CHECK: .dword 1
GPR14_VALUE: .dword 14
GPR15_CHECK: .dword 1
GPR15_VALUE: .dword 15
GPR16_CHECK: .dword 1
GPR16_VALUE: .dword 16
GPR17_CHECK: .dword 1
GPR17_VALUE: .dword 17
GPR18_CHECK: .dword 1
GPR18_VALUE: .dword 18
GPR19_CHECK: .dword 1
GPR19_VALUE: .dword 19
GPR20_CHECK: .dword 1
GPR20_VALUE: .dword 20
GPR21_CHECK: .dword 1
GPR21_VALUE: .dword 21
GPR22_CHECK: .dword 1
GPR22_VALUE: .dword 22
GPR23_CHECK: .dword 1
GPR23_VALUE: .dword 23
GPR24_CHECK: .dword 1
GPR24_VALUE: .dword 24
GPR25_CHECK: .dword 1
GPR25_VALUE: .dword 25
GPR26_CHECK: .dword 1
GPR26_VALUE: .dword 26
GPR27_CHECK: .dword 1
GPR27_VALUE: .dword 27
GPR28_CHECK: .dword 1
GPR28_VALUE: .dword 28
GPR29_CHECK: .dword 1
GPR29_VALUE: .dword 29
GPR30_CHECK: .dword 1
GPR30_VALUE: .dword 30
GPR31_CHECK: .dword 1
GPR31_VALUE: .dword 31

.section .data
.align 3
.globl tohost
tohost: .dword 0

.align 3
.section .text
.globl _start
_start:
    addi  x0,  x0, 1
    addi  x1,  x0, 1
    addi  x2,  x1, 1
    addi  x3,  x2, 1
    addi  x4,  x3, 1
    addi  x5,  x4, 1
    addi  x6,  x5, 1
    addi  x7,  x6, 1
    addi  x8,  x7, 1
    addi  x9,  x8, 1
    addi x10,  x9, 1
    addi x11, x10, 1
    addi x12, x11, 1
    addi x13, x12, 1
    addi x14, x13, 1
    addi x15, x14, 1
    addi x16, x15, 1
    addi x17, x16, 1
    addi x18, x17, 1
    addi x19, x18, 1
    addi x20, x19, 1
    addi x21, x20, 1
    addi x22, x21, 1
    addi x23, x22, 1
    addi x24, x23, 1
    addi x25, x24, 1
    addi x26, x25, 1
    addi x27, x26, 1
    addi x28, x27, 1
    addi x29, x28, 1
    addi x30, x29, 1

    la x31, tohost
    sd x0, 0(x31)

    addi x31, x30, 1

loop:
    j loop

.include "startup.s"

.section .rodata
.align 3
GPR00_CHECK: .dword 1
GPR00_VALUE: .dword 0
GPR06_CHECK: .dword 1
GPR06_VALUE: .dword -1
GPR07_CHECK: .dword 1
GPR07_VALUE: .dword 1
GPR28_CHECK: .dword 1
GPR28_VALUE: .dword 132
GPR29_CHECK: .dword 1
GPR29_VALUE: .dword -133
GPR30_CHECK: .dword 1
GPR30_VALUE: .dword 1
GPR31_CHECK: .dword 1
GPR31_VALUE: .dword 1232

.section .text
main:
    addi zero,  zero,   1
    addi   t1,  zero,  -1
    addi   t2,    t1,   2
    addi   t3,  zero,   132
    addi   t4,  zero,  -133
    addi   t5,    t4,   134
    addi   t6,  zero,   1232
    addi   a0,  zero,   0
    ret

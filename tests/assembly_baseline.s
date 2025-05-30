.include "startup.s"

.section .rodata
.align 3
GPR00_CHECK: .dword 0
GPR00_VALUE: .dword 0
GPR01_CHECK: .dword 0
GPR01_VALUE: .dword 0
GPR02_CHECK: .dword 0
GPR02_VALUE: .dword 0
GPR03_CHECK: .dword 0
GPR03_VALUE: .dword 0
GPR04_CHECK: .dword 0
GPR04_VALUE: .dword 0
GPR05_CHECK: .dword 0
GPR05_VALUE: .dword 0
GPR06_CHECK: .dword 0
GPR06_VALUE: .dword 0
GPR07_CHECK: .dword 0
GPR07_VALUE: .dword 0
GPR08_CHECK: .dword 0
GPR08_VALUE: .dword 0
GPR09_CHECK: .dword 0
GPR09_VALUE: .dword 0
GPR10_CHECK: .dword 0
GPR10_VALUE: .dword 0
GPR11_CHECK: .dword 0
GPR11_VALUE: .dword 0
GPR12_CHECK: .dword 0
GPR12_VALUE: .dword 0
GPR13_CHECK: .dword 0
GPR13_VALUE: .dword 0
GPR14_CHECK: .dword 0
GPR14_VALUE: .dword 0
GPR15_CHECK: .dword 0
GPR15_VALUE: .dword 0
GPR16_CHECK: .dword 0
GPR16_VALUE: .dword 0
GPR17_CHECK: .dword 0
GPR17_VALUE: .dword 0
GPR18_CHECK: .dword 0
GPR18_VALUE: .dword 0
GPR19_CHECK: .dword 0
GPR19_VALUE: .dword 0
GPR20_CHECK: .dword 0
GPR20_VALUE: .dword 0
GPR21_CHECK: .dword 0
GPR21_VALUE: .dword 0
GPR22_CHECK: .dword 0
GPR22_VALUE: .dword 0
GPR23_CHECK: .dword 0
GPR23_VALUE: .dword 0
GPR24_CHECK: .dword 0
GPR24_VALUE: .dword 0
GPR25_CHECK: .dword 0
GPR25_VALUE: .dword 0
GPR26_CHECK: .dword 0
GPR26_VALUE: .dword 0
GPR27_CHECK: .dword 0
GPR27_VALUE: .dword 0
GPR28_CHECK: .dword 0
GPR28_VALUE: .dword 0
GPR29_CHECK: .dword 0
GPR29_VALUE: .dword 0
GPR30_CHECK: .dword 0
GPR30_VALUE: .dword 0
GPR31_CHECK: .dword 0
GPR31_VALUE: .dword 0

.section .text
main:
    j pass

pass:
    addi a0, zero, 0
    j exit

fail:
    addi a0, zero, 1
    j exit

exit:
    ret

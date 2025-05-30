.include "startup.s"

.data
    hello_string: .asciz "Hello World!\n"

main:
    la t0, putchar_stdout
    la a0, hello_string

print_loop:
    lb t1, 0(a0)
    beqz t1, end_program
    sb t1, 0(t0)
    addi a0, a0, 1
    j print_loop

end_program:
    li a0, 0
    ret

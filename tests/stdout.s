.include "startup.s"

main:
    la t0, putchar_stdout
    
    li t1, 0x41  # ASCII 'A'
    li t2, 0x42  # ASCII 'B'
    li t3, 0x43  # ASCII 'C'
    li t4, 0x0A  # ASCII '\n'

    sb t1, 0(t0)  # Write 'A' to stdout
    sb t2, 0(t0)  # Write 'B' to stdout
    sb t3, 0(t0)  # Write 'C' to stdout
    sb t4, 0(t0)  # Write newline to stdout

    li a0, 0  # Success: exit code 0

    ret


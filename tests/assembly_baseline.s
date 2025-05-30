.include "startup.s"

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

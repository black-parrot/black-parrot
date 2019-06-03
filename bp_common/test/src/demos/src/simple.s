.file  "simple.s"
.option nopic
.text
.align 1
.globl main
.type  main, @function
main:
    /* print address */
    li x3, 0x8FFFEFFF

    /* uncached address */
    addi x4, x0, 1
    slli x4, x4, 0x26

    /* store value */
    addi x2, x0, 1

    /* do some stores */
    sb x2, 0(x4)
    addi x4, x4, 1

    sb x2, 0(x4)
    addi x4, x4, 1

    sb x2, 0(x4)
    addi x4, x4, 1

    sb x2, 0(x4)
    addi x4, x4, 1

    sb x2, 0(x4)

    /* summation */
    addi x5, x0, 0

    lb x2, 0(x4)
    add x5, x5, x2
    addi x4, x4, -1

    lb x2, 0(x4)
    add x5, x5, x2
    addi x4, x4, -1

    lb x2, 0(x4)
    add x5, x5, x2
    addi x4, x4, -1

    lb x2, 0(x4)
    add x5, x5, x2
    addi x4, x4, -1

    lb x2, 0(x4)
    add x5, x5, x2

    /* copy the result for pass/fail check */
    addi x6, x5, 0

    /* print the summation */
    addi x5, x5, 0x30
    sb x5, 0(x3)

    /* terminate the BP way */
    li a0, 0
    addi x7, x0, 5
    beq x6, x7, test_done
    li a0, -1

test_done:
    csrw 0x800, a0
    jalr x0, x1


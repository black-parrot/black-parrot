.file  "simple.s"
.option nopic
.text
.align 1
.globl main
.type  main, @function
main:
    /* NOTE:
    This test requires that the address range 0x0 to 0x3F_FFFF_FFFF be the uncached
    address range. This can be done by changing the uncached address check in both the FE and BE
    to ~paddr[high bit] instead of paddr[high bit].

    This file should also be compiled without the inclusion of any of the other helper code used
    by the other demos. Compile with uc_start.S.

    */

    /* print address */
    li x6, 0x8FFFEFFF

    /* uncached address */
    li x30, 0x400

    /* store value */
    addi x28, x0, 1

    /* do some stores */
    sb x28, 0(x30)
    addi x30, x30, 1

    sb x28, 0(x30)
    addi x30, x30, 1

    sb x28, 0(x30)
    addi x30, x30, 1

    sb x28, 0(x30)
    addi x30, x30, 1

    sb x28, 0(x30)

    /* summation */
    addi x29, x0, 0

    lb x28, 0(x30)
    add x29, x29, x28
    addi x30, x30, -1

    lb x28, 0(x30)
    add x29, x29, x28
    addi x30, x30, -1

    lb x28, 0(x30)
    add x29, x29, x28
    addi x30, x30, -1

    lb x28, 0(x30)
    add x29, x29, x28
    addi x30, x30, -1

    lb x28, 0(x30)
    add x29, x29, x28

    /* copy the result for pass/fail check */
    addi x28, x29, 0

    /* print the summation */
    addi x29, x29, 0x30
    sb x29, 0(x6)

    /* terminate the BP way */
    addi x6, x29, 0
    addi x6, x6, -0x30
    li a0, 0
    addi x7, x0, 5
    beq x6, x7, test_done
    li a0, -1

test_done:
    csrw 0x800, a0


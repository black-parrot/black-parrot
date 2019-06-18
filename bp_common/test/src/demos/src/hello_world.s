.file  "hello_world.s"
.option nopic
.text
.align 1
.globl main
.type  main, @function
main:
    li x3, 0x03001000

    /* H */
    li x2, 0x48
    sb x2, 0(x3)
    /* e */
    li x2, 0x65
    sb x2, 0(x3)
    /* l */
    li x2, 0x6C
    sb x2, 0(x3)
    /* l */
    li x2, 0x6C
    sb x2, 0(x3)
    /* o */
    li x2, 0x6F
    sb x2, 0(x3)
    /* space */
    li x2, 0x20
    sb x2, 0(x3)
    /* w */
    li x2, 0x77
    sb x2, 0(x3)
    /* o */
    li x2, 0x6F
    sb x2, 0(x3)
    /* r */
    li x2, 0x72
    sb x2, 0(x3)
    /* l */
    li x2, 0x6C
    sb x2, 0(x3)
    /* d */
    li x2, 0x64
    sb x2, 0(x3)
    /* ! */
    li x2, 0x21
    sb x2, 0(x3)
    /* \0 */
    sb x0, 0(x3)
    /* return back to the start code to finish the simulation */
    jalr x0, x1
    nop
    nop
    nop
    nop
    nop


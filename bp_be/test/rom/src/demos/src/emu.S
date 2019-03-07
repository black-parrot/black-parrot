.section ".text.init"
.option nopic
.text
.align 1
.globl _emu

_emu:
    addi x0, x0, 0
    li x3, 0x8FFFEFFF

    /* H */
    li x2, 'H'
    sb x2, 0(x3)
    /* e */
    li x2, 'e'
    sb x2, 0(x3)
    /* l */
    li x2, 'l'
    sb x2, 0(x3)
    /* l */
    li x2, 'l'
    sb x2, 0(x3)
    /* o */
    li x2, 'o'
    sb x2, 0(x3)
    /* space */
    li x2, ' '
    sb x2, 0(x3)
    /* w */
    li x2, 'w'
    sb x2, 0(x3)
    /* o */
    li x2, 'o'
    sb x2, 0(x3)
    /* r */
    li x2, 'r'
    sb x2, 0(x3)
    /* l */
    li x2, 'l'
    sb x2, 0(x3)
    /* d */
    li x2, 'd'
    sb x2, 0(x3)
    /* ! */
    li x2, '!'
    sb x2, 0(x3)
    /* \0 */
    sb x0, 0(x3)
    
    csrr x2, mepc
    addi x2, x2, 4
    csrw mepc, x2

    /* return back to the start code to finish the simulation */
    mret


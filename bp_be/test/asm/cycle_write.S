.section .text.init
.globl _start

_start:
    la t0, trap
    csrw mtvec, t0
    csrw cycle, zero
    j fail

.align 2
trap:
    csrr t0, mcause
    li t1, 2
    bne t0, t1, fail

pass:
    li t0, 0x00102000
    sw zero, 0(t0)
1:
    wfi
    j 1b

fail:
    li t0, 0x00102000
    li t1, 1
    sw t1, 0(t0)
2:
    wfi
    j 2b

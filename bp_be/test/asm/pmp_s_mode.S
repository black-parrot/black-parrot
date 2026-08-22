.section .text.init
.globl _start

_start:
    la t0, trap
    csrw mtvec, t0

    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1f
    csrw pmpcfg0, t0

    csrr t0, mstatus
    li t1, 3 << 11
    not t1, t1
    and t0, t0, t1
    li t1, 1 << 11
    or t0, t0, t1
    csrw mstatus, t0
    la t0, supervisor_mode
    csrw mepc, t0
    mret

supervisor_mode:
    csrr t0, pmpcfg0
    ecall

.align 2
trap:
    csrr t0, mcause
    li t1, 2
    bne t0, t1, fail
    csrr t0, mstatus
    srli t0, t0, 11
    andi t0, t0, 3
    li t1, 1
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

.section .text.init
.globl _start

_start:
    la t0, trap
    csrw mtvec, t0
    csrw mcounteren, zero
    li t0, 1
    csrw scounteren, t0

    csrr t0, mstatus
    li t1, 3 << 11
    not t1, t1
    and t0, t0, t1
    csrw mstatus, t0
    la t0, user_mode
    csrw mepc, t0
    mret

user_mode:
    csrr t0, cycle
    ecall

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

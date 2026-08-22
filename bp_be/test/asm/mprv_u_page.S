.section .text.init
.globl _start

_start:
    la t0, trap
    csrw mtvec, t0

    la t0, root_page_table
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    csrr t0, mstatus
    li t1, (3 << 11) | (1 << 17)
    not t1, t1
    and t0, t0, t1
    li t1, 1 << 17
    or t0, t0, t1
    csrw mstatus, t0

    li t0, 0x40000000
    ld t1, 0(t0)
    li t0, 1 << 17
    csrc mstatus, t0
    j fail

.align 2
trap:
    li t0, 1 << 17
    csrc mstatus, t0
    csrr t0, mcause
    li t1, 13
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

.section .data
.balign 4096
root_page_table:
    .zero 8
    .dword 0x20000043
    .zero 4080

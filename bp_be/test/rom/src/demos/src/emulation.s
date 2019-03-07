	.file	"emulation.c"
	.option pic
	.section	.rodata
	.align	3
.LC1:
	.string	"hello world!"
	.text
	.align	2
	.globl	decode_illegal
	.type	decode_illegal, @function
decode_illegal:
	addi	sp,sp,-64
	sd	s0,56(sp)
	addi	s0,sp,64
	sd	a0,-56(s0)
	lla	a5,.LC0
	ld	a5,0(a5)
	sd	a5,-24(s0)
	lla	a5,.LC1
	ld	a4,0(a5)
	sd	a4,-40(s0)
	lw	a5,8(a5)
	sw	a5,-32(s0)
	nop
	ld	s0,56(sp)
	addi	sp,sp,64
	jr	ra
	.size	decode_illegal, .-decode_illegal
	.section	.rodata
	.align	3
.LC0:
	.dword	2415915007
	.ident	"GCC: (GNU) 7.2.0"

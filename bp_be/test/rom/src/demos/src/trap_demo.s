	.file	"trap_demo.c"
	.option pic
	.globl	next_core
	.bss
	.align	3
	.type	next_core, @object
	.size	next_core, 8
next_core:
	.zero	8
	.text
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-64
	sd	s0,56(sp)
	addi	s0,sp,64
	sd	a0,-56(s0)
	sd	a1,-64(s0)
	li	a5,9
	slli	a5,a5,28
	addi	a5,a5,-1
	sd	a5,-24(s0)
	li	a5,305418240
	addi	a5,a5,1656
	sd	a5,-32(s0)
 #APP
# 13 "src/trap_demo.c" 1
	csrr  a5, mhartid
# 0 "" 2
 #NO_APP
	sd	a5,-40(s0)
	ld	a5,-32(s0)
 #APP
# 14 "src/trap_demo.c" 1
	csrw mtvec, a5
# 0 "" 2
 #NO_APP
	li	a5,0
	mv	a0,a5
	ld	s0,56(sp)
	addi	sp,sp,64
	jr	ra
	.size	main, .-main
	.ident	"GCC: (GNU) 7.2.0"

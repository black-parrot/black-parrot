	.file	"copy_example.c"
	.option pic
	.text
	.align	2
	.globl	copy_function
	.type	copy_function, @function
copy_function:
	addi	sp,sp,-32
	sd	s0,24(sp)
	addi	s0,sp,32
	li	a5,9
	slli	a5,a5,28
	addi	a5,a5,-1
	sd	a5,-24(s0)
	li	a5,1
	sd	a5,-32(s0)
	ld	a5,-32(s0)
	ld	a4,-24(s0)
 #APP
# 7 "src/copy_example.c" 1
	sb a5, 0(a4)
# 0 "" 2
 #NO_APP
	nop
	ld	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	copy_function, .-copy_function
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-80
	sd	ra,72(sp)
	sd	s0,64(sp)
	addi	s0,sp,80
	sd	a0,-72(s0)
	sd	a1,-80(s0)
	li	a5,1
	slli	a5,a5,31
	addi	a5,a5,452
	sd	a5,-40(s0)
	li	a5,1
	slli	a5,a5,31
	addi	a5,a5,516
	sd	a5,-48(s0)
	li	a5,536870912
	addi	a5,a5,1097
	slli	a5,a5,2
	sd	a5,-32(s0)
	ld	a5,-32(s0)
	sd	a5,-56(s0)
	ld	a5,-40(s0)
	sd	a5,-24(s0)
	j	.L3
.L4:
	ld	a5,-24(s0)
	ld	a4,0(a5)
	ld	a5,-32(s0)
	sd	a4,0(a5)
	ld	a5,-24(s0)
	addi	a5,a5,8
	sd	a5,-24(s0)
	ld	a5,-32(s0)
	addi	a5,a5,8
	sd	a5,-32(s0)
.L3:
	ld	a4,-24(s0)
	ld	a5,-48(s0)
	bleu	a4,a5,.L4
	ld	a5,-56(s0)
	jalr	a5
	li	a5,0
	mv	a0,a5
	ld	ra,72(sp)
	ld	s0,64(sp)
	addi	sp,sp,80
	jr	ra
	.size	main, .-main
	.ident	"GCC: (GNU) 7.2.0"

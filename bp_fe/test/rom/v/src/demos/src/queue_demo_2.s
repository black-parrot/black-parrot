	.file	"queue_demo.c"
	.option pic
	.comm	queue,272,8
	.globl	barrier_mem
	.bss
	.align	3
	.type	barrier_mem, @object
	.size	barrier_mem, 8
barrier_mem:
	.zero	8
	.comm	queue_entering,16,8
	.comm	queue_num,16,8
	.text
	.align	2
	.globl	lock_queue
	.type	lock_queue, @function
lock_queue:
	addi	sp,sp,-64
	sd	s0,56(sp)
	addi	s0,sp,64
	sd	a0,-56(s0)
	sd	zero,-40(s0)
	la	a4,queue_entering
	ld	a5,-56(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	li	a4,1
	sd	a4,0(a5)
	sd	zero,-24(s0)
	j	.L2
.L4:
	la	a4,queue_num
	ld	a5,-24(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a5,0(a5)
	ld	a4,-40(s0)
	bgeu	a4,a5,.L3
	la	a4,queue_num
	ld	a5,-24(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a5,0(a5)
	sd	a5,-40(s0)
.L3:
	ld	a5,-24(s0)
	addi	a5,a5,1
	sd	a5,-24(s0)
.L2:
	ld	a4,-24(s0)
	li	a5,1
	bleu	a4,a5,.L4
	ld	a5,-40(s0)
	addi	a4,a5,1
	la	a3,queue_num
	ld	a5,-56(s0)
	slli	a5,a5,3
	add	a5,a3,a5
	sd	a4,0(a5)
	la	a4,queue_entering
	ld	a5,-56(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	sd	zero,0(a5)
	sd	zero,-32(s0)
	j	.L5
.L9:
	nop
.L6:
	la	a4,queue_entering
	ld	a5,-32(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a5,0(a5)
	bnez	a5,.L6
	nop
.L8:
	la	a4,queue_num
	ld	a5,-32(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a5,0(a5)
	beqz	a5,.L7
	la	a4,queue_num
	ld	a5,-56(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a4,0(a5)
	la	a3,queue_num
	ld	a5,-32(s0)
	slli	a5,a5,3
	add	a5,a3,a5
	ld	a5,0(a5)
	bgtu	a4,a5,.L8
	la	a4,queue_num
	ld	a5,-56(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a4,0(a5)
	la	a3,queue_num
	ld	a5,-32(s0)
	slli	a5,a5,3
	add	a5,a3,a5
	ld	a5,0(a5)
	bne	a4,a5,.L7
	ld	a4,-56(s0)
	ld	a5,-32(s0)
	bgtu	a4,a5,.L8
.L7:
	ld	a5,-32(s0)
	addi	a5,a5,1
	sd	a5,-32(s0)
.L5:
	ld	a4,-32(s0)
	li	a5,1
	bleu	a4,a5,.L9
	nop
	ld	s0,56(sp)
	addi	sp,sp,64
	jr	ra
	.size	lock_queue, .-lock_queue
	.align	2
	.globl	unlock_queue
	.type	unlock_queue, @function
unlock_queue:
	addi	sp,sp,-32
	sd	s0,24(sp)
	addi	s0,sp,32
	sd	a0,-24(s0)
	la	a4,queue_num
	ld	a5,-24(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	sd	zero,0(a5)
	nop
	ld	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	unlock_queue, .-unlock_queue
	.align	2
	.globl	enqueue
	.type	enqueue, @function
enqueue:
	addi	sp,sp,-48
	sd	ra,40(sp)
	sd	s0,32(sp)
	addi	s0,sp,48
	sd	a0,-40(s0)
	sd	a1,-48(s0)
	sd	zero,-24(s0)
	ld	a0,-40(s0)
	call	lock_queue@plt
	la	a5,queue
	ld	a5,8(a5)
	addi	a5,a5,1
	andi	a4,a5,31
	la	a5,queue
	ld	a5,0(a5)
	bne	a4,a5,.L12
	li	a5,1
	sd	a5,-24(s0)
	j	.L13
.L12:
	la	a5,queue
	ld	a5,8(a5)
	la	a4,queue
	addi	a5,a5,2
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a4,-48(s0)
	sd	a4,0(a5)
	la	a5,queue
	ld	a5,8(a5)
	addi	a5,a5,1
	andi	a4,a5,31
	la	a5,queue
	sd	a4,8(a5)
.L13:
	ld	a0,-40(s0)
	call	unlock_queue@plt
	ld	a5,-24(s0)
	mv	a0,a5
	ld	ra,40(sp)
	ld	s0,32(sp)
	addi	sp,sp,48
	jr	ra
	.size	enqueue, .-enqueue
	.align	2
	.globl	dequeue
	.type	dequeue, @function
dequeue:
	addi	sp,sp,-64
	sd	ra,56(sp)
	sd	s0,48(sp)
	addi	s0,sp,64
	sd	a0,-56(s0)
	sd	a1,-64(s0)
	sd	zero,-24(s0)
	li	a5,9
	slli	a5,a5,28
	addi	a5,a5,-1
	sd	a5,-32(s0)
	ld	a0,-56(s0)
	call	lock_queue@plt
	la	a5,queue
	ld	a4,8(a5)
	la	a5,queue
	ld	a5,0(a5)
	bne	a4,a5,.L16
	li	a5,1
	sd	a5,-24(s0)
	j	.L17
.L16:
	la	a5,queue
	ld	a5,0(a5)
	la	a4,queue
	addi	a5,a5,2
	slli	a5,a5,3
	add	a5,a4,a5
	ld	a4,0(a5)
	ld	a5,-64(s0)
	sd	a4,0(a5)
	la	a5,queue
	ld	a5,0(a5)
	addi	a5,a5,1
	andi	a4,a5,31
	la	a5,queue
	sd	a4,0(a5)
	ld	a5,-64(s0)
	ld	a5,0(a5)
	sd	a5,-40(s0)
	ld	a5,-40(s0)
	ld	a4,-32(s0)
 #APP
# 125 "src/queue_demo.c" 1
	sb a5, 0(a4)
# 0 "" 2
 #NO_APP
.L17:
	ld	a0,-56(s0)
	call	unlock_queue@plt
	ld	a5,-24(s0)
	mv	a0,a5
	ld	ra,56(sp)
	ld	s0,48(sp)
	addi	sp,sp,64
	jr	ra
	.size	dequeue, .-dequeue
	.align	2
	.globl	thread_main
	.type	thread_main, @function
thread_main:
	addi	sp,sp,-48
	sd	ra,40(sp)
	sd	s0,32(sp)
	addi	s0,sp,48
	sd	zero,-48(s0)
	sd	zero,-24(s0)
 #APP
# 142 "src/queue_demo.c" 1
	csrr a5, mhartid
# 0 "" 2
 #NO_APP
	sd	a5,-32(s0)
	ld	a5,-32(s0)
	andi	a5,a5,1
	bnez	a5,.L24
	j	.L21
.L22:
	ld	a5,-48(s0)
	mv	a1,a5
	ld	a0,-32(s0)
	call	enqueue@plt
	sd	a0,-40(s0)
	ld	a5,-40(s0)
	bnez	a5,.L21
	ld	a5,-48(s0)
	addi	a5,a5,1
	sd	a5,-48(s0)
	ld	a5,-24(s0)
	addi	a5,a5,1
	sd	a5,-24(s0)
.L21:
	ld	a4,-24(s0)
	li	a5,9
	bleu	a4,a5,.L22
	j	.L23
.L25:
	addi	a5,s0,-48
	mv	a1,a5
	ld	a0,-32(s0)
	call	dequeue@plt
	sd	a0,-40(s0)
	ld	a5,-40(s0)
	bnez	a5,.L24
	ld	a5,-24(s0)
	addi	a5,a5,1
	sd	a5,-24(s0)
.L24:
	ld	a4,-24(s0)
	li	a5,9
	bleu	a4,a5,.L25
.L23:
	nop
	mv	a0,a5
	ld	ra,40(sp)
	ld	s0,32(sp)
	addi	sp,sp,48
	jr	ra
	.size	thread_main, .-thread_main
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-48
	sd	ra,40(sp)
	sd	s0,32(sp)
	addi	s0,sp,48
	sd	a0,-40(s0)
	sd	a1,-48(s0)
 #APP
# 168 "src/queue_demo.c" 1
	csrr a5, mhartid
# 0 "" 2
 #NO_APP
	sd	a5,-32(s0)
	ld	a5,-32(s0)
	bnez	a5,.L35
	sd	zero,-24(s0)
	j	.L28
.L29:
	la	a4,queue_entering
	ld	a5,-24(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	sd	zero,0(a5)
	la	a4,queue_num
	ld	a5,-24(s0)
	slli	a5,a5,3
	add	a5,a4,a5
	sd	zero,0(a5)
	ld	a5,-24(s0)
	addi	a5,a5,1
	sd	a5,-24(s0)
.L28:
	ld	a4,-24(s0)
	li	a5,1
	bleu	a4,a5,.L29
	la	a5,queue
	sd	zero,0(a5)
	la	a5,queue
	sd	zero,8(a5)
	sd	zero,-24(s0)
	j	.L30
.L31:
	la	a4,queue
	ld	a5,-24(s0)
	addi	a5,a5,2
	slli	a5,a5,3
	add	a5,a4,a5
	li	a4,933982208
	slli	a4,a4,2
	addi	a4,a4,-273
	sd	a4,0(a5)
	ld	a5,-24(s0)
	addi	a5,a5,1
	sd	a5,-24(s0)
.L30:
	ld	a4,-24(s0)
	li	a5,31
	bleu	a4,a5,.L31
	la	a5,barrier_mem
	li	a4,933982208
	slli	a4,a4,2
	addi	a4,a4,-273
	sd	a4,0(a5)
	j	.L32
.L35:
	nop
.L33:
	la	a5,barrier_mem
	ld	a4,0(a5)
	li	a5,933982208
	slli	a5,a5,2
	addi	a5,a5,-273
	bne	a4,a5,.L33
.L32:
	call	thread_main@plt
	li	a5,0
	mv	a0,a5
	ld	ra,40(sp)
	ld	s0,32(sp)
	addi	sp,sp,48
	jr	ra
	.size	main, .-main
	.ident	"GCC: (GNU) 7.2.0"

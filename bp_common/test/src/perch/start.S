.section ".text.init"
.globl _start

_start:
/* setup stack pointers. Stacks start at 0x8FFF_CFFF */
/* We then subtract off 8K*coreID. The top 4K is for the core emulation stack
 * the lower 4K is for the program TODO: Maybe larger stack value? */
    li   sp, 0x80010000
    csrr x1, mhartid 
    slli x1, x1, 13
    sub  sp, sp, x1

/* save the stack pointer to mscratch, so it can be used on first trap entry*/
    csrw mscratch, sp
/* get 4K and subtract it off to get the program stack pointer */
    li   x1, 1
    slli x1, x1, 12
    sub  sp, sp, x1 

/* setup mtvec */ 
   la x1, bp_mtvec_handler
   csrw mtvec, x1

/* 0 all registers */
    addi x1,  x0, 0
    /* x2 is the sp which we set, so don't zero */
    addi x3,  x0, 0
    addi x4,  x0, 0
    addi x5,  x0, 0
    addi x6,  x0, 0
    addi x7,  x0, 0
    addi x8,  x0, 0
    addi x9,  x0, 0
    addi x10, x0, 0
    addi x11, x0, 0
    addi x12, x0, 0
    addi x13, x0, 0
    addi x14, x0, 0
    addi x15, x0, 0
    addi x16, x0, 0
    addi x17, x0, 0
    addi x18, x0, 0
    addi x19, x0, 0
    addi x20, x0, 0
    addi x21, x0, 0
    addi x22, x0, 0
    addi x23, x0, 0
    addi x24, x0, 0
    addi x25, x0, 0
    addi x26, x0, 0
    addi x27, x0, 0
    addi x28, x0, 0
    addi x29, x0, 0
    addi x30, x0, 0
    addi x31, x0, 0


/* jump to main */
    jal main

/* to stop, make an ecall */
loop:
    addi x0, x0, 0
    j loop

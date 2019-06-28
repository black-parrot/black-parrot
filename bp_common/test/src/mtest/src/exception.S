.section ".text.emu"
.option nopic
.text
.align 1
.globl bp_mtvec_handler

.globl decode_illegal
.type  decode_illegal, @function

bp_mtvec_handler:
    # Swap in the machine mode stack pointer
    # Note: We only need to save the stack if we have a special emu stack. Security?
    csrrw sp, mscratch, sp 

    # Push temp registers onto stack
    sd x31, 0(sp)
    sd x30, -8(sp)
    sd x29, -16(sp)
    sd x28, -24(sp)
    sd x27, -32(sp)
    sd x26, -40(sp)
    sd x25, -48(sp)
    sd x24, -56(sp)
    sd x23, -64(sp)
    sd x22, -72(sp)
    sd x21, -80(sp)
    sd x20, -88(sp)
    sd x19, -96(sp)
    sd x18, -104(sp)
    sd x17, -112(sp)
    sd x16, -120(sp)
    sd x15, -128(sp)
    sd x14, -136(sp)
    sd x13, -144(sp)
    sd x12, -152(sp)
    sd x11, -160(sp)
    sd x10, -168(sp)
    sd x9, -176(sp)
    sd x8, -184(sp)
    sd x7, -192(sp)
    sd x6, -200(sp)
    sd x5, -208(sp)
    sd x4, -216(sp)
    sd x3, -224(sp)
    /* the user stack pointer needs to be saved slightly differently since its in mscratch 
     * at this point. On the upside, we can clobber almost anything we want now
     */
    csrr t0, mscratch
    sd t0, -232(sp)
    sd x1, -240(sp)
    sd x0, -248(sp)

    # Adjust the stack    
    addi sp, sp, -256 

    ## Decode the faulting instruction
    # Save a pointer to the registers
    addi a0, sp, 8
    # Read the faulting instruction
    csrr a1, mcause
    # Read the trap value
    csrr a2, mbadaddr
    jal decode_illegal

    # Return address is the instruction after MEPC
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    # Pop temp registers from stack
    addi sp, sp, 256
    # Save the machine mode scratch pointer in mscratch
    csrw mscratch, sp

    ld x0, -248(sp)
    ld x1, -240(sp)
    /* we need to restore the user stack pointer at the end, so we can finish restoring
     * user registers
     */
    ld x3, -224(sp)
    ld x4, -216(sp)
    ld x5, -208(sp)
    ld x6, -200(sp)
    ld x7, -192(sp)
    ld x8, -184(sp)
    ld x9, -176(sp)
    ld x10, -168(sp)
    ld x11, -160(sp)
    ld x12, -152(sp)
    ld x13, -144(sp)
    ld x14, -136(sp)
    ld x15, -128(sp)
    ld x16, -120(sp)
    ld x17, -112(sp)
    ld x18, -104(sp)
    ld x19, -96(sp)
    ld x20, -88(sp)
    ld x21, -80(sp)
    ld x22, -72(sp)
    ld x23, -64(sp)
    ld x24, -56(sp)
    ld x25, -48(sp)
    ld x26, -40(sp)
    ld x27, -32(sp)
    ld x28, -24(sp)
    ld x29, -16(sp)
    ld x30, -8(sp)
    ld x31,  0(sp)

    # Restore the user stack pointer as the last thing we do
    ld x2, -232(sp)

    # Return from the trap
    mret


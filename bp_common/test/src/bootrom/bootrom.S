/*
 * The bootrom loads the CCE ucode and the processor configuration and switches to the program for execution
 */

// CCE parameters
#define CCE_PC_WIDTH 8
#define NUM_CCE_INSTR (1 << CCE_PC_WIDTH)
#define CCE_INSTR_END 0xFFFFFFFFFFFFFFFF

// Configuration parameters
#define CFG_CCE_UCODE_BASE_ADDR 0x00208000

#define CFG_CCE_MODE_ADDR 0x00200081
#define CFG_DCACHE_MODE_ADDR 0x00200043
#define CFG_ICACHE_MODE_ADDR 0x00200022

#define CFG_CORE_OFFSET 24

.section .text.start
.globl _start
_start:
    li x0, 0
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    // Read hartid to set offset correctly
    csrr t4, mhartid
    slli t4, t4, CFG_CORE_OFFSET
    
    // Copy CCE microcode
    la t0, _ucode
    li t1, CFG_CCE_UCODE_BASE_ADDR
    or t1, t1, t4
    li t2, CCE_INSTR_END
load_ucode:
    ld t3, 0(t0)
    beq t3, t2, load_config
    sd t3, 0(t1)
    addi t0, t0, 8
    addi t1, t1, 1
    j load_ucode
        
    // Switch I$, D$ and CCE modes
load_config:
    li t0, 1

    li t1, CFG_CCE_MODE_ADDR
    or t1, t1, t4
    sd t0, 0(t1)

    li t1, CFG_DCACHE_MODE_ADDR
    or t1, t1, t4
    sd t0, 0(t1)
    
    li t1, CFG_ICACHE_MODE_ADDR
    or t1, t1, t4
    sd t0, 0(t1)

    fence
    
    li t0, 0x80000000
    csrw dpc, t0
    csrwi dcsr, 0x3

    // Zero out used registers
    li t0, 0
    li t1, 0
    li t2, 0
    li t3, 0
    li t4, 0

    dret
halt:
    j halt

_ucode:
    .incbin "cce_ucode.bin" 

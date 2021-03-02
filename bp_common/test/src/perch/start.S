.section ".text.init"
.globl _start
.type  _start, @function
_start:
# Setup the global pointer
.option push
.option norelax
  la gp, _gp
.option pop

# Setup stack pointers. Stacks start at 0x800F0000
# We then subtract off 8K*coreID. The top 4K is for the core emulation stack
# the lower 4K is for the program TODO: Maybe larger stack value?
  li   sp, 0x800F0000
  csrr t0, mhartid
  slli t0, t0, 13
  sub  sp, sp, t0

# Save the stack pointer to mscratch, so it can be used on first trap entry
  csrw mscratch, sp
# Get 4K and subtract it off to get the program stack pointer
  li   t0, 1
  slli t0, t0, 12
  sub  sp, sp, t0

# Setup mtvec
  la t0, bp_mtvec_handler
  csrw mtvec, t0

# Enable FPU
  li t0, 0x00006000 & (0x00006000 >> 1);
  csrs mstatus, t0;
  csrwi fcsr, 0

# 0 all registers except sp and gp
  addi x1,  x0, 0
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

  la      a0, __libc_fini_array # Register global termination functions
  call    atexit                #  to be called upon exit
  call    __libc_init_array     # Run global initialization functions

#ifdef _DRAMFS
  call dramfs_init
#endif

  call main
  tail bp_finish

# Loop if we pass exit
loop:
  nop
  j loop

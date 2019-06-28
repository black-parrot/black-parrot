# See LICENSE for license details.

#include "encoding.h"

#if __riscv_xlen == 64
# define LREG ld
# define SREG sd
# define REGBYTES 8
#else
# define LREG lw
# define SREG sw
# define REGBYTES 4
#endif

  .section ".text.init"
  .globl _start
_start:

  auipc sp, 0x200
  
  #We then subtract off 8K*coreID. 
  #The top 4K is for the core emulation stack
  #the lower 4K is for the program
  csrr t0, mhartid 
  slli t0, t0, 13
  sub  sp, sp, t0

  #save the stack pointer to mscratch, so it can be used on first trap entry
  csrw mscratch, sp
  #get 4K and subtract it off to get the program stack pointer
  li   t0, 1
  slli t0, t0, 12
  sub  sp, sp, t0 

  # initialize trap vector
  la t0, bp_mtvec_handler
  csrw mtvec, t0

  # initialize global pointer
.option push
.option norelax
  la gp, __global_pointer$
.option pop

  # get core id
  csrr a0, mhartid
  j _init

.section ".tdata.begin"
.globl _tdata_begin
_tdata_begin:

.section ".tdata.end"
.globl _tdata_end
_tdata_end:

.section ".tbss.end"
.globl _tbss_end
_tbss_end:

.section ".tohost","aw",@progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0

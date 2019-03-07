#include <stdint.h>

#include "emulation.h"

uint64_t csr_array[4096];

#define CSR_ADDR_MVENDORID  0xF11
#define CSR_ADDR_MARCHID    0xF12
#define CSR_ADDR_MIMPID     0xF13
#define CSR_ADDR_MHARTID    0xF14

#define RISCV_OPCODE_SYSTEM 0b1110011

typedef union {
  uint64_t bits;
  struct {
    uint32_t padding  : 32;
    uint16_t csr_addr : 12;
    uint8_t  rs1      : 5;
    uint8_t  funct3   : 3;
    uint8_t  rd       : 5;
    uint8_t  opcode   : 7;
  } csr;
} riscv_instr_t;

void decode_illegal(uint64_t *regs, uint64_t instr) 
{
  //riscv_instr_t riscv_instr;
  //uint64_t print_address = (uint64_t) 0x8FFFEFFF;

  //riscv_instr.bits = instr;

  uint64_t x0  = regs[0];
  uint64_t x1  = regs[1];
  uint64_t x2  = regs[2];
  uint64_t x3  = regs[3];

  x0 = x0 + x0;
  x1 = x1 + x1;
  x2 = x2 + x2;
  x3 = x3 + x3;

/*
  if (riscv_instr.csr.opcode == 1110011) {
    switch (riscv_instr.csr
  } else {
    while (1); // Infinite loop because we don't have a 'we messed up' mechanism
  }
*/

  return;
}


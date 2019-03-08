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

uint8_t get_byte(uint64_t dword, uint8_t byte_idx)
{
  return (dword >> 8*byte_idx) & 0xFF;
} 

void print_reg(uint8_t reg, uint64_t dword)
{
  uint8_t *print_address_n = (uint8_t*) 0x8FFFFFFF;
  uint8_t *print_address_c = (uint8_t*) 0x8FFFEFFF;

  *print_address_c = 'r';
  *print_address_c = 'e';
  *print_address_c = 'g';
  *print_address_c = ' ';
  *print_address_n = reg;
  *print_address_c = ' ';

  for (int i = 0; i < 8; i++)
  {
    *print_address_n = get_byte(dword, i);
  }
  *print_address_c = ' ';
  *print_address_c = ' ';
  *print_address_c = ' ';
}

void decode_illegal(uint64_t *regs, uint64_t instr) 
{
  //riscv_instr_t riscv_instr;

  //riscv_instr.bits = instr;
  print_reg(0, regs[0]);
  print_reg(1, regs[1]);
  print_reg(2, regs[2]);
  print_reg(3, regs[3]);
  print_reg(4, regs[4]);
  print_reg(5, regs[5]);
  print_reg(6, regs[6]);
  print_reg(7, regs[7]);
  print_reg(8, regs[8]);
  print_reg(9, regs[9]);
  print_reg(10, regs[10]);
  print_reg(11, regs[11]);
  print_reg(12, regs[12]);
  print_reg(13, regs[13]);
  print_reg(14, regs[14]);
  print_reg(15, regs[15]);
  print_reg(16, regs[16]);
  print_reg(17, regs[17]);
  print_reg(18, regs[18]);

/*
  if (riscv_instr.csr.opcode == 1110011) {
    switch (riscv_instr.csr
  } else {
    while (1); // Infinite loop because we don't have a 'we messed up' mechanism
  }
*/

  return;
}


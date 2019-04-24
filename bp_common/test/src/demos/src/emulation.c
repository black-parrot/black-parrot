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
  struct {
    uint32_t padding : 32;
    uint8_t  funct7  : 7;
    uint8_t  rs2     : 5;
    uint8_t  rs1     : 5;
    uint8_t  funct3  : 3;
    uint8_t  rd      : 5;
    uint8_t  opcode  : 7;
  } arith;
} riscv_instr_t;

//uint64_t multiply(

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

  for (int i = 7; i >= 0; i--)
  {
    *print_address_n = get_byte(dword, i);
  }
  *print_address_c = ' ';
  *print_address_c = ' ';
  *print_address_c = ' ';
}

void decode_illegal(uint64_t *regs, uint64_t instr) 
{
  riscv_instr_t riscv_instr;
  riscv_instr.bits = instr;

  /*
  uint8_t rs1_addr, rs2_addr, rd_addr;
  uint64_t rs1_data, rs2_data, rd_data;
  __int128 rd_data_128;

  rs1_addr = riscv_instr.rs1;
  rs2_addr = riscv_instr.rs2;
  rd_addr  = riscv_instr.rd;

  rs1_data = regs[rs1_addr];
  rs2_data = regs[rs2_addr];

  // M extension
  if (riscv_instr.arith.opcode == 0b0110011) {
    switch (riscv_instr.arith.funct3) {
      case 0b000: rd_data_128 = (int64_t) rs1_data * (int64_t) rs2_data;
                  rd_data     = (rd_data_128 >>  0) & 0xFFFFFFFFFFFFFFFF;
                  break;
      case 0b001: rd_data_128 = (int64_t) rs1_data * (int64_t) rs2_data;
                  rd_data     = (rd_data_128 >> 64) & 0xFFFFFFFFFFFFFFFF;
                  break;
      case 0b010: rd_data_128 = (int64_t) rs1_data * rs2_data;
                  rd_data     = (rd_data_128 >> 64) & 0xFFFFFFFFFFFFFFFF;
                  break;
      case 0b011: rd_data_128 = rs1_data * rs2_data;
                  rd_data     = (rd_data_128 >>  
    }
  } else {
    while (1); // Infinite loop because we don't have a 'we messed up' mechanism
  }
  */

  return;
}


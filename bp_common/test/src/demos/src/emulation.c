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
  struct __attribute__((__packed__)) {
    uint8_t  opcode  : 7;
    uint8_t  rd      : 5;
    uint8_t  funct3  : 3;
    uint8_t  rs1     : 5;
    uint8_t  rs2     : 5;
    uint8_t  rl      : 1;
    uint8_t  aq      : 1;
    uint8_t  funct5  : 5;
    uint32_t padding : 32;
  } atomic;
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

  for (int i = 7; i >= 0; i--)
  {
    *print_address_n = get_byte(dword, i);
  }
  *print_address_c = ' ';
  *print_address_c = ' ';
  *print_address_c = ' ';
}

void decode_illegal(uint64_t *regs, uint64_t mcause, uint64_t instr) 
{
  riscv_instr_t riscv_instr;
  riscv_instr.bits = instr;

  uint8_t rs1_addr, rs2_addr, rd_addr;
  uint64_t rs1_data, rs2_data, rd_data;

  
  uint8_t *print_address_n = (uint8_t*) 0x8FFFFFFF;

  //*print_address_n = get_byte((uint64_t) riscv_instr.bits, 3);
  //*print_address_n = get_byte((uint64_t) riscv_instr.bits, 2);
  //*print_address_n = get_byte((uint64_t) riscv_instr.bits, 1);
  //*print_address_n = get_byte((uint64_t) riscv_instr.bits, 0);

  //*print_address_n = get_byte(" ", 0);

  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.padding), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.funct5), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.aq), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.rl), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.rs1), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.funct3), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.rd), 0);
  //*print_address_n = get_byte((uint64_t)(riscv_instr.atomic.opcode), 0);
  

  for (int i = 0; i < 32; i++) {
    //print_reg(i, regs[i]);
  }

  // A extension
  if (riscv_instr.atomic.opcode == 0x2f) { 
    rs1_addr = riscv_instr.atomic.rs1;
    rs2_addr = riscv_instr.atomic.rs2;
    rd_addr  = riscv_instr.atomic.rd;
    
    rs1_data = regs[rs1_addr];
    rs2_data = regs[rs2_addr];

    //print_reg(rs1_addr, rs1_data);
    //print_reg(rs2_addr, rs2_data);

    uint64_t result = amo_addd(rs1_data, rs2_data);
    regs[rd_addr] = result;
  } else {
    while (1); // Infinite loop because we don't have a 'we messed up' mechanism
  }

  return;
}


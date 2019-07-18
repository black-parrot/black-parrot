#include <stdint.h>

#include "emulation.h"

#define CSR_ADDR_MVENDORID  0xF11
#define CSR_ADDR_MARCHID    0xF12
#define CSR_ADDR_MIMPID     0xF13
#define CSR_ADDR_MHARTID    0xF14

#define RISCV_OPCODE_SYSTEM 0b1110011
#define RISCV_OPCODE_ATOMIC 0b0101111

#define OPCODE(x)  ((x >> 0) & 0x7F)
#define RD(x)      ((x >> 7) & 0x1F)
#define FUNCT3(x)  ((x >> 12) & 0x7)
#define RS1(x)     ((x >> 15) & 0x1F)
#define RS2(x)     ((x >> 20) & 0x1F)
#define FUNCT5(x)  ((x >> 27) & 0x1F)
#define FUNCT11(x) ((x >> 20) & 0x7FF)

static uint64_t csr_array[4096];

static uint64_t (*amow_jt[32])(uint64_t, uint64_t) =
{
  amo_addw, amo_swapw, 0, 0, amo_xorw, 0, 0, 0,
  amo_orw, 0, 0, 0, amo_andw, 0, 0, 0,
  amo_minw, 0, 0, 0, amo_maxw, 0, 0, 0,
  amo_minuw, 0, 0, 0, amo_maxuw, 0, 0, 0,
};

static uint64_t (*amod_jt[32])(uint64_t, uint64_t) = 
{
  amo_addd, amo_swapd, 0, 0, amo_xord, 0, 0, 0,
  amo_ord, 0, 0, 0, amo_andd, 0, 0, 0,
  amo_mind, 0, 0, 0, amo_maxd, 0, 0, 0,
  amo_minud, 0, 0, 0, amo_maxud, 0, 0, 0,
};

static uint64_t (**amo_jt[8])(uint64_t, uint64_t) = 
{
  0, 0, amow_jt, amod_jt, 0, 0, 0, 0
};

void decode_illegal(uint64_t *regs, uint64_t mcause, uint64_t instr) 
{
  // TODO: We only emulate A extension for now
  uint16_t funct11 = FUNCT11(instr);
  uint8_t funct5 = FUNCT5(instr);
  uint8_t rs2_addr = RS2(instr);
  uint8_t rs1_addr = RS1(instr);
  uint8_t funct3 = FUNCT3(instr);
  uint8_t rd_addr = RD(instr);
  uint8_t opcode = OPCODE(instr);
  
  uint64_t rs1_data = regs[rs1_addr];
  uint64_t rs2_data = regs[rs2_addr];

  if (opcode == RISCV_OPCODE_ATOMIC) {
    regs[rd_addr] = amo_jt[funct3][funct5](rs1_data, rs2_data);
  } else {
    while (1); // Infinite loop, since we don't have a truly illegal instruction handler
  }
}


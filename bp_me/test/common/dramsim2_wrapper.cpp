#include "dramsim2_wrapper.hpp"

using namespace DRAMSim;

extern "C" void read_resp(svBitVecVal* data);
extern "C" void write_resp();

static MultiChannelMemorySystem *mem;
static bp_dram dram;

void bp_dram::read_hex(char *filename)
{
  string line, tok;
  char delimiter = ' ';
  std::ifstream hexfile(filename);
  uint64_t current_addr = 0;

  if (hexfile.is_open()) {
    while (getline(hexfile, line)) {
      if (line.find("@") != std::string::npos) {
        current_addr = std::stoull(line.substr(1), nullptr, 16);
      } else {
        std::istringstream ss(line);
        // Print dump line by line
        //std::cout << "LINE: " << line << std::endl;
        unsigned int c;
        while (ss >> std::hex >> c) {
          dram.mem[current_addr++] = c;
        }
      }
    }
  } else {
    std::cout << "Unable to open file: " << filename << std::endl;
  }

  // Dump a bit of the memory file
  //for (unsigned int i = 0x80000000; i < 0x800001FF; i++) 
  //{
  //  std::cout << dram.mem[i] << std::endl;
  //}
}

extern "C" void mem_read_req(uint64_t addr)
{
  mem->addTransaction(false, addr);
}

void bp_dram::read_complete(unsigned id, uint64_t addr, uint64_t cycle)
{
  for (int i = 0; i < 16; i++) {
    uint32_t word = 0;
    for (int j = 0; j < 4; j++) {
      word |= (dram.mem[addr+i*4+j] << (j*8));
    }
    dram.result_data[i] = word;
  }

  dram.result_pending = true;
  read_resp(dram.result_data);
}

extern "C" void mem_write_req(uint64_t addr, svBitVecVal *data)
{
  for (int i = 0; i < 16; i++) {
    uint32_t word = data[i];
    for (int j = 0; j < 4; j++) {
      dram.mem[addr+i*4+j] = (word >> j*8) & (0xFFFFFF00);
    }
  }
  mem->addTransaction(true, addr);
}

void bp_dram::write_complete(unsigned id, uint64_t addr, uint64_t cycle)
{
  dram.result_pending = true;
  write_resp();
}

extern "C" void init(uint64_t clock_period_in_ps
                     , char *prog_name
                     , char *dram_cfg_name 
                     , char *dram_sys_cfg_name
                     , uint64_t dram_capacity
                     )
{
  TransactionCompleteCB *read_cb = 
    new Callback<bp_dram, void, unsigned, uint64_t, uint64_t>(&dram, &bp_dram::read_complete);
  TransactionCompleteCB *write_cb = 
    new Callback<bp_dram, void, unsigned, uint64_t, uint64_t>(&dram, &bp_dram::write_complete);

  mem = 
    getMemorySystemInstance(dram_cfg_name, dram_sys_cfg_name, "", "", dram_capacity);
  mem->RegisterCallbacks(read_cb, write_cb, NULL);

  uint64_t clock_freq_in_hz = (uint64_t) (1.0 / (clock_period_in_ps * 1.0E-12));
  mem->setCPUClockSpeed(clock_freq_in_hz); 
  dram.read_hex(prog_name);
}

extern "C" bool tick() 
{
  mem->update();

  bool result = dram.result_pending;
  
  dram.result_pending = false;
  
  return result;
}


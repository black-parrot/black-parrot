#include "dramsim2_wrapper.hpp"

using namespace DRAMSim;

static MultiChannelMemorySystem *mem;
static bp_dram dram;

extern "C" bool mem_read_req(uint64_t addr)
{
  string scope = svGetNameFromScope(svGetScope());

  if (!mem->willAcceptTransaction()) {
     return false;
  }

  mem->addTransaction(false, addr);
  dram.addr_tracker[addr].push(scope);
  dram.result_pending[scope] = false;

  return true;
}

extern "C" bool mem_write_req(uint64_t addr, svBitVecVal *data, int reqSize=0)
{
  string scope = svGetNameFromScope(svGetScope());

  if (!mem->willAcceptTransaction()) {
     return false;
  }

  mem->addTransaction(true, addr);
  dram.addr_tracker[addr].push(scope);
  dram.result_pending[scope] = false;

  return true;
}

void bp_dram::read_complete(unsigned id, uint64_t addr, uint64_t cycle)
{
  string scope = dram.addr_tracker[addr].front();
  dram.addr_tracker[addr].pop();

  dram.result_pending[scope] = true;
}

void bp_dram::write_complete(unsigned id, uint64_t addr, uint64_t cycle)
{
  string scope = dram.addr_tracker[addr].front();
  dram.addr_tracker[addr].pop();

  dram.result_pending[scope] = true;
}

extern "C" void init(uint64_t clock_period_in_ps, char *dram_cfg_name , char *dram_sys_cfg_name, uint64_t dram_capacity)
{
  if (!mem) {
    TransactionCompleteCB *read_cb = 
      new Callback<bp_dram, void, unsigned, uint64_t, uint64_t>(&dram, &bp_dram::read_complete);
    TransactionCompleteCB *write_cb = 
      new Callback<bp_dram, void, unsigned, uint64_t, uint64_t>(&dram, &bp_dram::write_complete);

    mem = getMemorySystemInstance(dram_cfg_name, dram_sys_cfg_name, "", "", dram_capacity);
    mem->RegisterCallbacks(read_cb, write_cb, NULL);

    uint64_t clock_freq_in_hz = (uint64_t) (1.0 / (clock_period_in_ps * 1.0E-12));
    mem->setCPUClockSpeed(clock_freq_in_hz); 
  }
}

extern "C" bool tick() 
{
  string scope = svGetNameFromScope(svGetScope());
  mem->update();

  bool result = dram.result_pending[scope];
  dram.result_pending[scope] = false;

  return result;
}


#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string>

using namespace std;

dromajo_cosim_state_t* dromajo_pointer;
uint64_t d_address = 0;
uint64_t d_count = 0;

extern "C" void dromajo_init(char* cfg_f_name, int hartid, int ncpus, int memory_size, bool checkpoint) {

  if(hartid == 0) {
    cout << "Running with Dromajo cosimulation" << endl;

    string ncpus_str = "--ncpus=" + to_string(ncpus);
    string memsize_str = "--memory_size=" + to_string(memory_size);
    string mmio_str = "--mmio_range=0x20000:0x80000000";
    char* load_str = "--load=prog";

    if(checkpoint) {
      char* argv[] = {"dromajo", (char*)(&ncpus_str[0]), (char*)(&memsize_str[0]), (char*)(&mmio_str[0]), load_str, "prog.elf"};
      dromajo_pointer = dromajo_cosim_init(6, argv);
    }
    else {
      char* argv[] = {"dromajo", (char*)(&ncpus_str[0]), (char*)(&memsize_str[0]), (char*)(&mmio_str[0]), "prog.elf"};
      dromajo_pointer = dromajo_cosim_init(5, argv);
    }
  }
}

extern "C" bool dromajo_step(int      hart_id,
                             uint64_t pc,
                             uint32_t insn,
                             uint64_t wdata) {
  int exit_code = dromajo_cosim_step(dromajo_pointer, 
                                     hart_id,
                                     pc,
                                     insn,
                                     wdata,
                                     0,
                                     true,
                                     false);
  if(exit_code != 0)
    return true;
  else
    return false;
}

extern "C" void dromajo_trap(int hart_id, uint64_t cause) {
  dromajo_cosim_raise_trap(dromajo_pointer, hart_id, cause, false);
}

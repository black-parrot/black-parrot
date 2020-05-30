#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string>

using namespace std;

dromajo_cosim_state_t* dromajo_pointer;
uint64_t d_address = 0;
uint64_t d_count = 0;

extern "C" void dromajo_init(char* cfg_f_name, int hartid, int ncpus) {

  if(hartid == 0) {
    cout << "Running with Dromajo cosimulation" << endl;
    string ncpus_str = "--ncpus=" + to_string(ncpus);
    char *argv[] = {(char*)"", cfg_f_name, (char*)(&ncpus_str[0])};
    dromajo_pointer = dromajo_cosim_init(3, argv);
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

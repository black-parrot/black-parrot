#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string>

dromajo_cosim_state_t* dromajo_pointer;
uint64_t d_address = 0;
uint64_t d_count = 0;

extern "C" void init_dromajo(char* cfg_f_name) {
  char *argv[] = {(char*)"Variane", cfg_f_name};

  dromajo_pointer = dromajo_cosim_init(2, argv);
}

extern "C" void dromajo_step(int      hart_id,
                             uint64_t pc,
                             uint32_t insn,
                             uint64_t wdata,
                             uint64_t mstatus) {
  int exit_code = dromajo_cosim_step(dromajo_pointer, 
                                     hart_id,
                                     pc,
                                     insn,
                                     wdata,
                                     0,
                                     true);

  if (exit_code != 0) {
    std::cout << "oops!" << std::endl;
    abort();
  }
}

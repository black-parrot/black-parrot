#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string>
#include <vector>

using namespace std;

dromajo_cosim_state_t* dromajo_pointer;
vector<bool>* finish;

extern "C" void dromajo_init(char* cfg_f_name, int hartid, int ncpus, int memory_size, bool checkpoint, bool amo_en) {

  if(hartid == 0) {
    cout << "Running with Dromajo cosimulation" << endl;

    finish = new vector<bool>(ncpus, false);

    char dromajo_str[50];
    sprintf(dromajo_str, "dromajo");
    char ncpus_str[50];
    sprintf(ncpus_str, "--ncpus=%d", ncpus);
    char memsize_str[50];
    sprintf(memsize_str, "--memory_size=%d", memory_size);
    char mmio_str[50];
    sprintf(mmio_str, "--mmio_range=0x20000:0x80000000");
    char load_str[50];
    sprintf(load_str, "--load=prog");
    char amo_str[50];
    sprintf(amo_str, "--enable_amo");
    char prog_str[50];
    sprintf(prog_str, "prog.elf");

    if(checkpoint) {
      if(amo_en) {
        char* argv[] = {dromajo_str, ncpus_str, memsize_str, mmio_str, amo_str, load_str, prog_str};
        dromajo_pointer = dromajo_cosim_init(7, argv);
      }
      else {
        char* argv[] = {dromajo_str, ncpus_str, memsize_str, mmio_str, load_str, prog_str};
        dromajo_pointer = dromajo_cosim_init(6, argv);
      }
    }
    else {
      if(amo_en) {
        char* argv[] = {dromajo_str, ncpus_str, memsize_str, mmio_str, amo_str, prog_str};
        dromajo_pointer = dromajo_cosim_init(6, argv);
      }
      else {
        char* argv[] = {dromajo_str, ncpus_str, memsize_str, mmio_str, prog_str};
        dromajo_pointer = dromajo_cosim_init(5, argv);
      }
    }
  }
}

extern "C" bool dromajo_step(int      hartid,
                             uint64_t pc,
                             uint32_t insn,
                             uint64_t wdata,
                             uint64_t mstatus) {
  int exit_code = dromajo_cosim_step(dromajo_pointer, 
                                     hartid,
                                     pc,
                                     insn,
                                     wdata,
                                     mstatus,
                                     true,
                                     false);
  if(exit_code != 0)
    return true;
  else
    return false;
}

extern "C" void dromajo_trap(int hartid, uint64_t cause) {
  dromajo_cosim_raise_trap(dromajo_pointer, hartid, cause, false);
}

extern "C" bool get_finish(int hartid) {
  if(!finish)
    return false;
  return finish->at(hartid);
}

extern "C" void set_finish(int hartid) {
  finish->at(hartid) = true;
}

extern "C" bool check_terminate() {
  if(!finish)
    return false;

  for(int i=0; i < finish->size(); i++)
    if(finish->at(i) == false)
      return false;
  return true;
}

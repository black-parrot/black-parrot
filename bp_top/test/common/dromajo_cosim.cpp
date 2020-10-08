#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string>
#include <vector>

using namespace std;

dromajo_cosim_state_t* dromajo_pointer;
vector<bool>* finish;

extern "C" void dromajo_init(char* cfg_f_name, int hartid, int ncpus, int memory_size, bool checkpoint) {

  if(hartid == 0) {
    cout << "Running with Dromajo cosimulation" << endl;

    finish = new vector<bool>(ncpus, false);

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

extern "C" bool dromajo_step(int      hartid,
                             uint64_t pc,
                             uint32_t insn,
                             uint64_t wdata) {
  int exit_code = dromajo_cosim_step(dromajo_pointer, 
                                     hartid,
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

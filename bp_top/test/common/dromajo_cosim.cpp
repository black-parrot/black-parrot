
#ifdef DROMAJO_COSIM

#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string>
#include <vector>

using namespace std;

dromajo_cosim_state_t* dromajo_pointer;

extern "C" void cosim_init(int hartid, int ncpus, int memory_size, bool checkpoint) {
    if (dromajo_pointer == NULL && hartid == 0) {
        cout << "Running with Dromajo cosimulation" << endl;

        char dromajo_str[50];
        sprintf(dromajo_str, "dromajo");
        char ncpus_str[50];
        sprintf(ncpus_str, "--ncpus=%d", ncpus);
        char memsize_str[50];
        sprintf(memsize_str, "--memory_size=%d", memory_size);
        char load_str[50];
        sprintf(load_str, "--load=prog");
        char prog_str[50];
        sprintf(prog_str, "prog.elf");

        if (checkpoint) {
            char* argv[] = {dromajo_str, ncpus_str, memsize_str, load_str, prog_str};
            dromajo_pointer = dromajo_cosim_init(5, argv);
        }
        else {
            char* argv[] = {dromajo_str, ncpus_str, memsize_str, prog_str};
            dromajo_pointer = dromajo_cosim_init(4, argv);
        }
    }
}

extern "C" int cosim_step(int      hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t mstatus) {
    if (!dromajo_pointer) return 0;

    return dromajo_cosim_step(dromajo_pointer,
            hartid,
            pc,
            insn,
            wdata,
            mstatus,
            true,
            false);
}

extern "C" void cosim_trap(int hartid, uint64_t cause) {
    dromajo_cosim_raise_trap(dromajo_pointer, hartid, cause, false);
}

extern "C" void cosim_finish() {
    if (dromajo_pointer) {
        delete dromajo_pointer;
        dromajo_pointer = NULL;
    }
}

#endif



#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string.h>
#include <vector>

extern "C" void* cosim_init(int hartid, int ncpus, bool checkpoint) {
    char *argv[64];
    char argv_str[1024];
    int argc = 0;

    if (checkpoint) {
        sprintf(argv_str, "dromajo --ncpus=%d --memory_size=256 --load=prog prog.riscv");
    } else {
        sprintf(argv_str, "dromajo --ncpus=%d --memory_size=256 prog.riscv");
    }

    // Tokenize the string
    char *token = strtok(argv_str, " ");
    while (token != NULL) {
        argv[argc++] = token;  // Assign each token to argv
        token = strtok(NULL, " ");
    }

    argv[argc] = NULL;

    std::cout << "Running with Dromajo cosimulation" << std::endl;
    return dromajo_cosim_init(argc, argv);
}

extern "C" int cosim_step(dromajo_cosim_state_t *dromajo_pointer,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status,
        uint64_t cause) {
    bool check = true;
    bool verbose = false;

    return dromajo_cosim_step(dromajo_pointer,
            hartid,
            pc,
            insn,
            wdata,
            status,
            check,
            verbose);
}

extern "C" int cosim_trap(dromajo_cosim_state_t *dromajo_pointer,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status,
        uint64_t cause) {
    bool check = true;
    bool verbose = false;

    dromajo_cosim_raise_trap(dromajo_pointer, hartid, cause, verbose);

    return 0;
}

extern "C" void cosim_finish(dromajo_cosim_state_t *dromajo_pointer) {
    if (dromajo_pointer) {
        std::cout << "Terminating Dromajo cosimulation" << std::endl;
        dromajo_cosim_fini(dromajo_pointer);
    }
}


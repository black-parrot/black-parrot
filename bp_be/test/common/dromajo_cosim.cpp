
#include "svdpi.h"
#include <iostream>
#include "dromajo_cosim.h"
#include "stdlib.h"
#include <string.h>
#include <vector>
#include <mutex>
#include <cstdarg>

static dromajo_cosim_state_t *handle = nullptr;
static std::once_flag handle_init_once, handle_fini_once;

void printf_stub(int hartid, const char *fmt, ...) { }

extern "C" void* cosim_init(int ncpus, int memsize) {

    std::call_once(handle_init_once, [&] {
        char argv_str[1024];
        char *argv[64];
        int argc = 0;
        // Create the argument string
        sprintf(argv_str, "dromajo --ncpus=%d --memory_size=%d prog.riscv", ncpus, memsize);

        // Tokenize the string
        char *token = strtok(argv_str, " ");
        while (token != NULL) {
            argv[argc++] = token;  // Assign each token to argv
            token = strtok(NULL, " ");
        }

        argv[argc] = NULL;

        std::cout << "Running with Dromajo cosimulation" << std::endl;

        handle = dromajo_cosim_init(argc, argv);
        // without this, dromajo prints a ton of garbage...
        dromajo_install_new_loggers(handle, printf_stub, printf_stub);
    });

    return handle;
}

extern "C" int cosim_step(dromajo_cosim_state_t *dromajo_pointer,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status) {
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

extern "C" int cosim_trap(dromajo_cosim_state_t *dromajo_pointer, int hartid, int cause) {
    bool verbose = false;

    dromajo_cosim_raise_trap(dromajo_pointer, hartid, cause, verbose);

    return 0;
}

extern "C" void* cosim_finish(dromajo_cosim_state_t *dromajo_pointer) {

    std::call_once(handle_fini_once, [&] {
        std::cout << "Terminating Dromajo cosimulation" << std::endl;
        dromajo_cosim_fini(dromajo_pointer);
        handle = nullptr;
    });
    return handle;
}



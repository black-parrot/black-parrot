
#include "svdpi.h"
#include <iostream>
#include "stdlib.h"
#include <string.h>
#include <vector>

extern "C" void* __attribute__((weak)) cosim_init(int ncpus, int memsize) {
    return nullptr;
}

extern "C" int __attribute__((weak)) cosim_step(void *handle,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status) {
    return 0;
}

extern "C" int __attribute__((weak)) cosim_trap(void *handle,
        int hartid,
        uint64_t cause) {
    return 0;
}

extern "C" void* __attribute__((weak)) cosim_finish(void *handle) {
    return nullptr;
}


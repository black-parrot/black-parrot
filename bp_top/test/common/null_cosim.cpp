
#include "svdpi.h"
#include <iostream>
#include "stdlib.h"
#include <string.h>
#include <vector>

extern "C" void* cosim_init(int hartid, int ncpus, int memory_size, bool checkpoint) {
    return NULL;
}

extern "C" int cosim_step(void *handle,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status,
        uint64_t cause) {
    return 0;
}

extern "C" int cosim_trap(void *handle,
        int hartid,
        uint64_t pc,
        uint32_t insn,
        uint64_t wdata,
        uint64_t status,
        uint64_t cause) {
    return 0;
}

extern "C" void cosim_finish(void *handle) {

}


#include <stdint.h>
#include "bp_utils.h"

#include "write_demo.h"

#ifndef NUM_CORES
#define NUM_CORES 8
#endif

#define K (N/NUM_CORES)

volatile uint64_t end_barrier_mem = 0;

uint64_t main(uint64_t argc, char * argv[]) {
    uint64_t i;
    uint64_t core_id;
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
   
    uint32_t sum = 0;
    for (int i = 0; i < K; i++) {
      MATRIX[i*NUM_CORES + core_id] += core_id;
      sum += MATRIX[i*NUM_CORES + core_id];
    }

    bp_finish(0);

    return 0;
}

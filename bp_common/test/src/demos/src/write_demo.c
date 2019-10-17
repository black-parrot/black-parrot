#include <stdint.h>
#include "bp_utils.h"

#include "write_demo_small.h"

#ifndef NUM_CORES
#define NUM_CORES 2
#endif

#define K (N/NUM_CORES)

uint64_t main(uint64_t argc, char * argv[]) {
    uint64_t i;
    uint64_t core_id;
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

    uint64_t sum = 0;
    for (int i = 0; i < K; i++) {
      MATRIX[i*NUM_CORES + core_id] = 1;
      sum += MATRIX[i*NUM_CORES + core_id];

      /*
      if (sum != i+1) {
        bp_finish(1);
        return 0;
      }
      */
    }

    bp_hprint((uint8_t)sum);

    if (sum == K) {
      bp_finish(0);
    } else {
      bp_finish(1);
    }

    return 0;
}

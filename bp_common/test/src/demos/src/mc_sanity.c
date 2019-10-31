/*
 * Name:
 *   mc_sanity.c
 *
 * Description:
 *   This program has each core write to unique entries in memory and then locally sum
 *   the values. The cores deliberately false share cache blocks, forcing the coherence
 *   system to transfer blocks between the cores as a basic sanity check of coherence
 *   functionality in a multicore system.
 *
 */

#include <stdint.h>
#include "bp_utils.h"

#ifndef NUM_CORES
#define NUM_CORES 2
#endif

#define K 512

#ifndef N
#define N (NUM_CORES*K)
#endif

typedef uint64_t matrix[N];
matrix MATRIX;

uint64_t main(uint64_t argc, char * argv[]) {
    uint64_t i;
    uint64_t core_id;
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

    uint64_t sum = 0;
    for (int i = 0; i < K; i++) {
      MATRIX[i*NUM_CORES + core_id] = 1;
      sum += MATRIX[i*NUM_CORES + core_id];
    }

    bp_hprint((uint8_t)sum);

    if (sum == K) {
      bp_finish(0);
    } else {
      bp_finish(1);
    }

    return 0;
}

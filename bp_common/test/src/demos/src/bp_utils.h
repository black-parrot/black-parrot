#ifndef BP_UTILS_H
#define BP_UTILS_H
#include <stdint.h>

void barrier_end(volatile uint64_t *barrier_address, uint64_t total_num_cores);

#endif

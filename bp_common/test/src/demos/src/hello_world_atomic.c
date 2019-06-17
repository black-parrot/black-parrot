#include <stdint.h>
#include "bp_utils.h"
/* CHANGEME for the number of cores under test */
#define NUM_CORES 8
volatile uint64_t core_num = 0;
volatile uint64_t barrier = 0;

int main(int argc, char** argv) {
    uint64_t core_id;
    uint64_t atomic_inc = 1;
    uint64_t atomic_result = 0;

    uint64_t print_addr = (uint64_t)(0x000000008FFFFFFF);
    
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
    
    // synchronize with other cores and wait until it is this core's turn
    while (core_num != core_id) { }
    
    // print out this core id
    __asm__ volatile("sb %0, 0(%1)": : "r"(core_id), "r"(print_addr):);

    // increment atomic counter
    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) 
                                            : "r"(&core_num), "r"(atomic_inc)
                                            :);
    barrier_end(&barrier, NUM_CORES);

    return 0;
}


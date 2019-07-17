#include <stdint.h>
#include "bp_utils.h"

void bp_barrier_end(volatile uint64_t * barrier_address, uint64_t total_num_cores) {
    uint64_t core_id;
    uint64_t atomic_inc = 1;
    uint64_t atomic_result;
    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);
    
    /* if we're not core 0, increment the barrier and then just loop */
    if (core_id != 0) {
        __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) 
                                                : "r"(barrier_address), "r"(atomic_inc)
                                                :);
        while (1) { }
    }
    /* 
     * if we're core 0, increment the barrier as well and then test if the
     * barrier is equal to the total number of cores
     */
    else {
        uint64_t finish_value = 0;
        __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) 
                                                : "r"(barrier_address), "r"(atomic_inc)
                                                :);
        while(*barrier_address < total_num_cores) {

            
        }
        bp_finish(0);
    }
}

void bp_finish(uint8_t code) {
  uint64_t core_id;

  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

  *(FINISH_BASE_ADDR+core_id*8) = code;
}

void bp_hprint(uint8_t hex) {
  uint64_t core_id;

  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

  *(HPRINT_BASE_ADDR+core_id*8) = hex;
}

void bp_cprint(uint8_t ch) {
  uint64_t core_id;

  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

  *(CPRINT_BASE_ADDR+core_id*8) = ch;
}


#include <stdint.h>

uint64_t next_core = 0;

uint64_t main (uint64_t argc, char *argv[]) {
    uint64_t core_id;
    uint64_t next_id;

    uint64_t print_addr = (uint64_t)(0x000000008FFFFFFF);

    uint64_t trap_addr = (uint64_t)(0x0000000012345678);

    __asm__ volatile("csrr  %0, mhartid": "=r" (core_id): :);
    __asm__ volatile("csrw mtvec, %0": :"r"(trap_addr) :);

    return 0;
}

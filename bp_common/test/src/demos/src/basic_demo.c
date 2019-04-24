#include <stdint.h>

uint64_t next_core = 0;

uint64_t main (uint64_t argc, char *argv[]) {
    uint64_t core_id;
    uint64_t next_id;

    uint64_t print_addr = (uint64_t)(0x000000008FFFFFFF);

    __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

    while (next_core != core_id) {   }

    __asm__ volatile("sb %0, 0(%1)": : "r"(core_id), "r"(print_addr):);
    next_id = core_id + 1;
    next_core = next_id;

    return 0;
}

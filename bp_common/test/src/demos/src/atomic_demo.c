#include <stdint.h>

extern uint64_t bp_mtvec_handler;

uint64_t next_core = 0;
uint64_t atomic_var = 1234;

uint64_t main (uint64_t argc, char *argv[]) {
    uint8_t *print_addr = (uint8_t *)(0x000000008FFFFFFF);

    uint64_t trap_addr = (uint64_t)&bp_mtvec_handler;
    __asm__ volatile("csrw mtvec, %0": :"r"(trap_addr) :);

    uint64_t atomic_inc = 3;
    uint64_t atomic_result = 0;

    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) : "r"(&atomic_var), "r"(atomic_inc):);
    *print_addr = (uint8_t) atomic_result >> 8;
    *print_addr = (uint8_t) atomic_result;
    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) : "r"(&atomic_var), "r"(atomic_inc):);
    *print_addr = (uint8_t) atomic_result >> 8;
    *print_addr = (uint8_t) atomic_result;
    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) : "r"(&atomic_var), "r"(atomic_inc):);
    *print_addr = (uint8_t) atomic_result >> 8;
    *print_addr = (uint8_t) atomic_result;
    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) : "r"(&atomic_var), "r"(atomic_inc):);
    *print_addr = (uint8_t) atomic_result >> 8;
    *print_addr = (uint8_t) atomic_result;
    __asm__ volatile("amoadd.d %0, %2, (%1)": "=r"(atomic_result) : "r"(&atomic_var), "r"(atomic_inc):);
    *print_addr = (uint8_t) atomic_result >> 8;
    *print_addr = (uint8_t) atomic_result;

    return 0;
}

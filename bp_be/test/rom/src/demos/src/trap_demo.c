#include <stdint.h>

extern uint64_t _emu;

uint64_t next_core = 0;

uint64_t main (uint64_t argc, char *argv[]) {
    uint64_t core_id;
    uint64_t vendor_id;
    uint64_t hpmcounter3;

    uint64_t print_addr = (uint64_t)(0x000000008FFFFFFF);

    uint64_t trap_addr = (uint64_t)&_emu;

    uint64_t mstatus = (uint64_t)(0xFFFFFFFFFFFFFFFF);
    uint64_t mie     = (uint64_t)(0xFFFFFFFFFFFFFFFF);

    __asm__ volatile("csrw mstatus, %0": :"r"(mstatus) :);
    __asm__ volatile("csrw mie, %0": :"r"(mie) :);
    __asm__ volatile("csrr  %0, mhartid": "=r" (core_id): :);
    __asm__ volatile("csrw mtvec, %0": :"r"(trap_addr<<2) :);

    __asm__ volatile("csrr  %0, mvendorid": "=r" (vendor_id): :);

    // Illegal instruction
    __asm__ volatile("csrr  %0, mhpmcounter3": "=r" (hpmcounter3): :);

    return 0;
}

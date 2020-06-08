#ifndef BP_UTILS_H
#define BP_UTILS_H
#include <stdint.h>
#include "bsg_newlib_intf.h"

#define HOST_DEV_BASE_ADDR ((char *)(0x00100000))
#define GETCHAR_BASE_ADDR  ((char *)(HOST_DEV_BASE_ADDR+0x0000))
#define PUTCHAR_BASE_ADDR  ((char *)(HOST_DEV_BASE_ADDR+0x1000))
#define FINISH_BASE_ADDR   ((char *)(HOST_DEV_BASE_ADDR+0x2000))


uint64_t bp_get_hart();

void bp_barrier_end(volatile uint64_t *barrier_address, uint64_t total_num_cores);

void bp_hprint(uint8_t hex);

void bp_cprint(uint8_t ch);

void bp_finish(uint8_t code);

#define BP_CFG_BASE_ADDR ((char *)(0x00200000))

#endif

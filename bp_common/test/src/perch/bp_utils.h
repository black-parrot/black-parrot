#ifndef BP_UTILS_H
#define BP_UTILS_H
#include <stdint.h>

#define HOST_DEV_BASE_ADDR ((char *)(0x03000000))
#define HPRINT_BASE_ADDR ((char *)(HOST_DEV_BASE_ADDR+0x0000))
#define CPRINT_BASE_ADDR ((char *)(HOST_DEV_BASE_ADDR+0x1000))
#define FINISH_BASE_ADDR ((char *)(HOST_DEV_BASE_ADDR+0x2000))

void bp_barrier_end(volatile uint64_t *barrier_address, uint64_t total_num_cores);

void bp_hprint(uint8_t hex);

void bp_cprint(uint8_t ch);

void bp_finish(uint8_t code);

#define BP_CFG_RESET ((char *)(0x01000001))
#define BP_CFG_FREEZE ((char *)(0x01000002))
#define BP_CFG_CORE_ID ((char *)(0x01000003))
#define BP_CFG_ICACHE_ID ((char *)(0x01000021))
#define BP_CFG_ICACHE_MODE ((char *)(0x01000022))
#define BP_CFG_NPC ((char *)(0x01000040))
#define BP_CFG_DCACHE_ID ((char *)(0x01000041))
#define BP_CFG_DCACHE_MDOE ((char *)(0x01000042))
#define BP_CFG_PRIV ((char *)(0x00000043))
#define BP_CFG_IRF_BASE ((char *)(0x00000050))
#define BP_CFG_CCE_ID ((char *)(0x00000080))
#define BP_CFG_CCE_MODE ((char *)(0x00000081))
#define BP_CFG_NUM_LCE ((char *)(0x00000082))
#define BP_CFG_CSR_BASE ((char *)(0x00006000))
#define BP_CFG_CCE_UCODE_BASE ((char *)(0x00008000))

#endif

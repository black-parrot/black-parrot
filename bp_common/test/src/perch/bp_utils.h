#ifndef BP_UTILS_H
#define BP_UTILS_H
#include <stdint.h>

#define HOST_DEV_BASE_ADDR ((char *)(0x00100000))
#define HPRINT_BASE_ADDR ((char *)(HOST_DEV_BASE_ADDR+0x0000))
#define CPRINT_BASE_ADDR ((char *)(HOST_DEV_BASE_ADDR+0x1000))
#define FINISH_BASE_ADDR ((char *)(HOST_DEV_BASE_ADDR+0x2000))


void bp_barrier_end(volatile uint64_t *barrier_address, uint64_t total_num_cores);

void bp_hprint(uint8_t hex);

void bp_cprint(uint8_t ch);

void bp_finish(uint8_t code);

#define BP_CFG_BASE_ADDR ((char *)(0x00200000))

/////////////////////////accelerator_vector_dot_product////////////////////
#define CACCEL_VDP_BASE_ADDR ((uint64_t *)(0x02000000))
#define SACCEL_VDP_BASE_ADDR ((uint64_t *)(0x03000000))
#define SACCEL_VDP_MEM_BASE ((uint64_t *)(0x1000000000))

#define ACCEL_VPD_INPUT_A_PTR    0
#define ACCEL_VPD_INPUT_B_PTR    1
#define ACCEL_VPD_INPUT_LEN      2
#define ACCEL_VPD_START_CMD      3
#define ACCEL_VPD_RESP_STATUS    4
#define ACCEL_VPD_RESP_PTR       5
#define ACCEL_VPD_RESP_LEN       6
#define ACCEL_VPD_OPERATION      7
#define ACCEL_VPD_NUM_CSRs       8

struct VDP_CSR
{ 
  uint64_t *input_a_ptr;
  uint64_t *input_b_ptr;
  uint64_t input_length;
  uint64_t *resp_ptr;
};

void bp_set_CSR(uint64_t *accel_base_address, uint8_t csr_idx, uint64_t csr_value);
uint64_t bp_get_CSR(uint64_t *accel_base_address, uint8_t csr_idx); 
void mem_cpy(uint64_t *src, uint64_t *dest, uint64_t length);

void bp_vdp_config_accelerator(uint64_t *base_cfg_addr, uint64_t *input_a_ptr,
                               uint64_t *input_b_ptr, uint64_t input_length, 
                               uint64_t operation, uint64_t *resp_ptr, uint64_t resp_length);
void bp_vdp_accelerator_start_cmd(uint64_t *base_cfg_addr);
void bp_vdp_wait_for_completion(uint64_t *base_cfg_addr);
void bp_call_vector_dot_product_accelerator(uint8_t type, struct VDP_CSR vdp_csrs);

#endif

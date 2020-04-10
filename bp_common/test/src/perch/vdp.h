#ifndef VDP_H
#define VDP_H
#include <stdint.h>


#define CONFIG 4
#define CACCEL_VDP_BASE_ADDR  (CONFIG == 1) ? ((uint64_t *)(0x01000000)) : ((uint64_t *)(0x04000000))
#define CACCEL_VADD_BASE_ADDR ((uint64_t *)(0x05000000))
#define SACCEL_VDP_BASE_ADDR  (CONFIG == 1) ? ((uint64_t *)(0x02000000)) : ((uint64_t *)(0x06000000))
#define SACCEL_VADD_BASE_ADDR ((uint64_t *)(0x07000000))
#define SACCEL_VDP_MEM_BASE   ((uint64_t *)(0x2000000000))
#define SACCEL_VADD_MEM_BASE  ((uint64_t *)(0x3000000000))

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

void bp_set_mmio_csr(uint64_t *accel_base_address, uint8_t csr_idx, uint64_t csr_value);
uint64_t bp_get_mmio_csr(uint64_t *accel_base_address, uint8_t csr_idx); 
void dma_cpy(uint64_t *src, uint64_t *dest, uint64_t length);

void bp_vdp_config_accelerator(uint64_t *base_cfg_addr, uint64_t *input_a_ptr,
                               uint64_t *input_b_ptr, uint64_t input_length, 
                               uint64_t operation, uint64_t *resp_ptr, uint64_t resp_length);
void bp_vdp_accelerator_start_cmd(uint64_t *base_cfg_addr);
void bp_vdp_wait_for_completion(uint64_t *base_cfg_addr);
void bp_call_vector_dot_product_accelerator(uint8_t type, struct VDP_CSR vdp_csrs);
void bp_call_vector_add_accelerator(uint8_t type, struct VDP_CSR vdp_csrs);

#endif

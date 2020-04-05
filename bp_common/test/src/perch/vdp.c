#include <stdint.h>
#include "vdp.h"

void bp_set_mmio_csr(uint64_t *accel_base_address, uint8_t csr_idx, uint64_t csr_value)
{
  *(accel_base_address+csr_idx*8) = csr_value;
}


uint64_t bp_get_mmio_csr(uint64_t *accel_base_address, uint8_t csr_idx)
{
  uint64_t csr_value;
  csr_value = *(accel_base_address+csr_idx*8);
  return csr_value;
}


void bp_vdp_accelerator_start_cmd(uint64_t *base_cfg_addr){
  bp_set_mmio_csr(base_cfg_addr, ACCEL_VPD_START_CMD, 1);
}


void dma_cpy(uint64_t *src, uint64_t *dest, uint64_t length){
  int i;
  for (i=0; i<length; i++) 
    dest[i] = src[i]; 
}


void bp_vdp_wait_for_completion(uint64_t *base_cfg_addr){
  uint64_t status;
  while (1)
    {
      status = bp_get_mmio_csr(base_cfg_addr, ACCEL_VPD_RESP_STATUS);
      if(status)
        break;
    }
}


void bp_vdp_config_accelerator(uint64_t *base_cfg_addr, uint64_t *input_a_ptr, 
                               uint64_t *input_b_ptr, uint64_t input_length, 
                               uint64_t operation, uint64_t *resp_ptr, uint64_t resp_length){

  bp_set_mmio_csr(base_cfg_addr, ACCEL_VPD_INPUT_A_PTR, (uint64_t) input_a_ptr);
  bp_set_mmio_csr(base_cfg_addr, ACCEL_VPD_INPUT_B_PTR, (uint64_t) input_b_ptr);
  bp_set_mmio_csr(base_cfg_addr, ACCEL_VPD_INPUT_LEN, input_length);
  bp_set_mmio_csr(base_cfg_addr, ACCEL_VPD_RESP_PTR, (uint64_t) resp_ptr);
  bp_set_mmio_csr(base_cfg_addr, ACCEL_VPD_RESP_LEN, resp_length); 
}


void bp_call_vector_dot_product_accelerator(uint8_t type, struct VDP_CSR vdp_csrs){

  uint64_t *cfg_base_addr;
  cfg_base_addr = type ? SACCEL_VDP_BASE_ADDR : CACCEL_VDP_BASE_ADDR;

  if(type){
    dma_cpy(vdp_csrs.input_a_ptr, SACCEL_VDP_MEM_BASE, vdp_csrs.input_length);
    dma_cpy(vdp_csrs.input_b_ptr, SACCEL_VDP_MEM_BASE+vdp_csrs.input_length, vdp_csrs.input_length);
  }

  uint64_t *src_vec_a, *src_vec_b, *result_vec;
  src_vec_a =  type ? SACCEL_VDP_MEM_BASE : vdp_csrs.input_a_ptr;
  src_vec_b =  type ? SACCEL_VDP_MEM_BASE+vdp_csrs.input_length : vdp_csrs.input_b_ptr;
  result_vec = type ? SACCEL_VDP_MEM_BASE+2*vdp_csrs.input_length : vdp_csrs.resp_ptr;

  bp_vdp_config_accelerator(cfg_base_addr, src_vec_a, src_vec_b, vdp_csrs.input_length, 0, result_vec, 1);
  bp_vdp_accelerator_start_cmd(cfg_base_addr);
  bp_vdp_wait_for_completion(cfg_base_addr);

  if(type){
    dma_cpy(result_vec, vdp_csrs.resp_ptr, 1);
  }
}

void bp_call_vector_add_accelerator(uint8_t type, struct VDP_CSR vdp_csrs){

  uint64_t *cfg_base_addr;
  cfg_base_addr = type ? SACCEL_VADD_BASE_ADDR : CACCEL_VADD_BASE_ADDR;

  if(type){
    dma_cpy(vdp_csrs.input_a_ptr, SACCEL_VADD_MEM_BASE, vdp_csrs.input_length);
    dma_cpy(vdp_csrs.input_b_ptr, SACCEL_VADD_MEM_BASE+vdp_csrs.input_length, vdp_csrs.input_length);
  }

  uint64_t *src_vec_a, *src_vec_b, *result_vec;
  src_vec_a =  type ? SACCEL_VADD_MEM_BASE : vdp_csrs.input_a_ptr;
  src_vec_b =  type ? SACCEL_VADD_MEM_BASE+vdp_csrs.input_length : vdp_csrs.input_b_ptr;
  result_vec = type ? SACCEL_VADD_MEM_BASE+2*vdp_csrs.input_length : vdp_csrs.resp_ptr;

  bp_vdp_config_accelerator(cfg_base_addr, src_vec_a, src_vec_b, vdp_csrs.input_length, 0, result_vec, 1);
  bp_vdp_accelerator_start_cmd(cfg_base_addr);
  bp_vdp_wait_for_completion(cfg_base_addr);

  if(type){
    dma_cpy(result_vec, vdp_csrs.resp_ptr, 1);
  }
}


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



///////////////////////////dot-product accelerator///////////////////////////

void bp_set_CSR(uint64_t *accel_base_address, uint8_t csr_idx, uint64_t csr_value)
{
   *(accel_base_address+csr_idx*8) = csr_value;
}
uint64_t bp_get_CSR(uint64_t *accel_base_address, uint8_t csr_idx)
{
  uint64_t csr_value;
  csr_value = *(accel_base_address+csr_idx*8);
  return csr_value;
}

void bp_vdp_config_accelerator(uint64_t *input_a_ptr, uint64_t *input_b_ptr, uint64_t input_length, 
                               uint64_t operation, uint64_t *resp_ptr, uint64_t resp_length){
  bp_set_CSR(ACCEL_VDP_BASE_ADDR, ACCEL_VPD_INPUT_A_PTR, (uint64_t) input_a_ptr);
  bp_set_CSR(ACCEL_VDP_BASE_ADDR, ACCEL_VPD_INPUT_B_PTR, (uint64_t) input_b_ptr);
  bp_set_CSR(ACCEL_VDP_BASE_ADDR, ACCEL_VPD_INPUT_LEN, input_length);
  bp_set_CSR(ACCEL_VDP_BASE_ADDR, ACCEL_VPD_RESP_PTR, (uint64_t) resp_ptr);
  bp_set_CSR(ACCEL_VDP_BASE_ADDR, ACCEL_VPD_RESP_LEN, resp_length); 
}

void bp_vdp_accelerator_start_cmd(){
  bp_set_CSR(ACCEL_VDP_BASE_ADDR, ACCEL_VPD_START_CMD, 1);
}


void bp_vdp_wait_for_completion(){
  uint64_t status;
  while (1)
    {
      status = bp_get_CSR(ACCEL_VDP_BASE_ADDR,ACCEL_VPD_RESP_STATUS);
      if(status)
        break;
    }
}

void bp_call_vector_dot_product_accelerator(struct VDP_CSR vdp_csrs){
  bp_vdp_config_accelerator(vdp_csrs.input_a_ptr, vdp_csrs.input_b_ptr, 
                            vdp_csrs.input_length, 0, vdp_csrs.resp_ptr,1);
  bp_vdp_accelerator_start_cmd(0);
  bp_vdp_wait_for_completion(0);
}



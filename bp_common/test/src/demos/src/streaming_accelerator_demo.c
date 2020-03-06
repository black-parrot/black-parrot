#include <stdint.h>
#include "bp_utils.h"
#include "vdp.h"

#define TO_HEX(i) (i <= 9 ? '0' + i : 'A' - 10 + i)

uint64_t main(uint64_t argc, char * argv[]) {

  uint8_t vlen;
  uint64_t input_array_a [8];
  uint64_t input_array_b [8];
  uint64_t resp_data = 0;
  struct VDP_CSR vdp_csr;

  uint64_t core_id;
  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);   
   
  /////////////first call////////////
  if (core_id == 0) {
 
    vlen = 2;
    int i;
    for(i = 0; i < vlen; ++i){
      input_array_a[i] = (i+1)*16;
      input_array_b[i] = (i+1)*32;
    }

    vdp_csr.input_a_ptr = (uint64_t *) &input_array_a;
    vdp_csr.input_b_ptr = (uint64_t *) &input_array_b;
    vdp_csr.input_length = vlen;
    vdp_csr.resp_ptr =  (uint64_t *) &resp_data;

    //type:1, streaming
    bp_call_vector_dot_product_accelerator(1, vdp_csr);

    for(i = 0; i < 16;++i){      
      bp_cprint(TO_HEX((uint8_t)((resp_data>>i*4) & 0x0F)));
    }

  }
  ////////second call/////////////
  if ((CONFIG > 3) &&  (core_id == 3)) {
    vlen = 4;
    int i =0;
    for(i = 0; i < vlen; ++i){
      input_array_a[i] = (i+1)*2;
      input_array_b[i] = (i+1)*5;
    }

    vdp_csr.input_a_ptr = (uint64_t *) &input_array_a;
    vdp_csr.input_b_ptr = (uint64_t *) &input_array_b;
    vdp_csr.input_length = vlen;
    vdp_csr.resp_ptr =  (uint64_t *) &resp_data;
    vdp_csr.input_length = vlen;

    //type:1, streaming
    bp_call_vector_add_accelerator(1, vdp_csr);
  
    for(i = 0; i < 16;++i){
      bp_cprint(TO_HEX((uint8_t)((resp_data>>i*4) & 0x0F)));
    }
  }

  bp_finish(0);
  
  return 0;
}

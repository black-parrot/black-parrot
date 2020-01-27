#include <stdint.h>
#include "bp_utils.h"

uint64_t main(uint64_t argc, char * argv[]) {


  uint8_t vlen;
  uint64_t input_array_a [8];
  uint64_t input_array_b [8];
  uint64_t resp_data = 0;
  struct VDP_CSR vdp_csr;
   
  /////////////first call////////////
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
  bp_call_vector_dot_product_accelerator(vdp_csr);

  for(i = 0; i < 8;++i){
    bp_hprint((uint8_t)(resp_data>>i*8));
  }
  ////////second call/////////////
  vlen = 4;
  for(i = 0; i < vlen; ++i){
    input_array_a[i] = (i+1)*2;
    input_array_b[i] = (i+1)*5;
  }

  vdp_csr.input_length = vlen;
  bp_call_vector_dot_product_accelerator(vdp_csr);

  for(i = 0; i < 8;++i){
    bp_hprint((uint8_t)(resp_data>>i*8));
  }


  bp_finish(0);

 /*int j;
 for (j = 0; j < vlen; ++j){
   for(i = 0; i < 8; ++i){
     bp_hprint((uint8_t)((uint64_t) (input_array_a+j)>>i*8));}
   for(i = 0; i < 8; ++i){
     bp_hprint((uint8_t)(input_array_a[j]>>i*8));}
 }

 for (j = 0; j < vlen; ++j){
   for(i = 0; i < 8; ++i){
     bp_hprint((uint8_t)((uint64_t) (input_array_b+j)>>i*8));}
   for(i = 0; i < 8; ++i){
     bp_hprint((uint8_t)(input_array_b[j]>>i*8));}
     }*/
  
 return 0;
}



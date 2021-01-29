#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "bp_utils.h"
#include <string.h>
#include "vdp.h"

#define TO_HEX(i) (i <= 9 ? '0' + i : 'A' - 10 + i)

uint64_t main(uint64_t argc, char * argv[]) {

  struct Zipline_CSR zipline_csr;

  uint64_t core_id;
  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);   
  //uint64_t resp_data [20];
  size_t len = 0;

  struct dma_cfg dma_tlv_header [5];
  uint64_t tlv_headers [14];
  //struct zipline_tlv tlv_headers [14];

  //rqe
  tlv_headers[0] = 0x400000000a000400;
  tlv_headers[1] = 0x0000000000000000;
  dma_tlv_header[0].data_ptr = tlv_headers;
  dma_tlv_header[0].length = 2;
  dma_tlv_header[0].type = 0;

  
  //cmd
  tlv_headers[2] = 0x800000000a000601;
  tlv_headers[3] = 0x000000000780b000;
  tlv_headers[4] = 0x3a00000000200d42; //xp10:0x3a00000000200654;
  dma_tlv_header[1].data_ptr = tlv_headers+2;
  dma_tlv_header[1].length = 3;
  dma_tlv_header[1].type = 1;
  

  //frmd 
  tlv_headers[5] = 0xc00000000a00020b;
  dma_tlv_header[2].data_ptr = tlv_headers+5;
  dma_tlv_header[2].length = 1;
  dma_tlv_header[2].type = 2;

  //data
  tlv_headers[6]  = 0xa00000000a000005;
  dma_tlv_header[3].data_ptr = tlv_headers+6;
  dma_tlv_header[3].length = 1;
  dma_tlv_header[3].type = 3;
  dma_tlv_header[3].part = 1;

  // Initialize LFS
  dramfs_init();

  // Read from a file
  FILE *hello = fopen("test.txt", "r");
  if(hello == NULL)
    return -1;

  int FILE_CHUNK = 48;
  char buffer[FILE_CHUNK];
  uint64_t resp_data [FILE_CHUNK/8];
  fseek(hello, 0, SEEK_SET);
  fread(buffer, FILE_CHUNK, 1, hello);

  dma_tlv_header[4].data_ptr = (uint64_t *) buffer;
  dma_tlv_header[4].length = FILE_CHUNK/8;
  dma_tlv_header[4].type = 3;
  dma_tlv_header[4].part = 2;

  //cqe
  tlv_headers[7] = 0x800000000a000409;
  tlv_headers[8] = 0x0000000000000000;
  dma_tlv_header[5].data_ptr = tlv_headers+7;
  dma_tlv_header[5].length = 2;
  dma_tlv_header[5].type = 4;
 
  
  if (core_id == 0) {
    //type:1, streaming
    zipline_csr.input_ptr = dma_tlv_header;
    zipline_csr.resp_ptr =  (uint64_t *) &resp_data;
    uint64_t tlv_num, comp_size;
    tlv_num = bp_call_zipline_accelerator(1, zipline_csr, 6);
    comp_size = (tlv_num-1) * 8;
    
    int i=0, j=0;
    for(i = 0; i < 16;++i){
      bp_cprint(TO_HEX((uint8_t)((comp_size>>i*4) & 0x0F)));
    }
    bp_cprint(10);

    for(j=0; j < tlv_num; j++){
      for(i = 0; i < 16;++i){      
        bp_cprint(TO_HEX((uint8_t)((resp_data[j]>>i*4) & 0x0F)));
      }
      bp_cprint(10);
    }

  }


  bp_finish(0);
  
  return 0;
}

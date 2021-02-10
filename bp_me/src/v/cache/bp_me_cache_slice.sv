
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_cache_slice
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, xce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [xce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_ready_o

   , output [xce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_yumi_i

   , output logic [cce_mem_msg_header_width_lp-1:0]    mem_cmd_header_o
   , output logic                                      mem_cmd_header_v_o
   , input                                             mem_cmd_header_yumi_i

   , output logic [dword_width_gp-1:0]                  mem_cmd_data_o
   , output logic                                      mem_cmd_data_v_o
   , input                                             mem_cmd_data_yumi_i

   , input [cce_mem_msg_header_width_lp-1:0]           mem_resp_header_i
   , input                                             mem_resp_header_v_i
   , output logic                                      mem_resp_header_ready_o

   , input [dword_width_gp-1:0]                         mem_resp_data_i
   , input                                             mem_resp_data_v_i
   , output logic                                      mem_resp_data_ready_o
   );

  `declare_bsg_cache_pkt_s(caddr_width_p, dword_width_gp);
  bsg_cache_pkt_s cache_pkt_li;
  logic cache_pkt_v_li, cache_pkt_ready_lo;
  logic [dword_width_gp-1:0] cache_data_lo;
  logic cache_data_v_lo, cache_data_yumi_li;
  bp_me_cce_to_cache
   #(.bp_params_p(bp_params_p))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(mem_cmd_i)
     ,.mem_cmd_v_i(mem_cmd_v_i)
     ,.mem_cmd_ready_o(mem_cmd_ready_o)

     ,.mem_resp_o(mem_resp_o)
     ,.mem_resp_v_o(mem_resp_v_o)
     ,.mem_resp_yumi_i(mem_resp_yumi_i)

     ,.cache_pkt_o(cache_pkt_li)
     ,.v_o(cache_pkt_v_li)
     ,.ready_i(cache_pkt_ready_lo)

     ,.data_i(cache_data_lo)
     ,.v_i(cache_data_v_lo)
     ,.yumi_o(cache_data_yumi_li)
     );

  `declare_bsg_cache_dma_pkt_s(caddr_width_p);
  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic dma_pkt_v_lo, dma_pkt_yumi_li;
  bsg_cache
   #(.addr_width_p(caddr_width_p)
     ,.data_width_p(dword_width_gp)
     ,.block_size_in_words_p(cce_block_width_p/dword_width_gp)
     ,.sets_p(l2_sets_p)
     ,.ways_p(l2_assoc_p)
     )
   cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cache_pkt_i(cache_pkt_li)
     ,.v_i(cache_pkt_v_li)
     ,.ready_o(cache_pkt_ready_lo)

     ,.data_o(cache_data_lo)
     ,.v_o(cache_data_v_lo)
     ,.yumi_i(cache_data_yumi_li)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

     ,.dma_data_i(mem_resp_data_i)
     ,.dma_data_v_i(mem_resp_data_v_i)
     ,.dma_data_ready_o(mem_resp_data_ready_o)

     ,.dma_data_o(mem_cmd_data_o)
     ,.dma_data_v_o(mem_cmd_data_v_o)
     ,.dma_data_yumi_i(mem_cmd_data_yumi_i)

     ,.v_we_o()
     );

  // coherence message block size
  // block size smaller than 8-bytes not supported
  localparam bp_bedrock_msg_size_e mem_cmd_block_size =
    (cce_block_width_p == 1024)
    ? e_bedrock_msg_size_128
    : (cce_block_width_p == 512)
      ? e_bedrock_msg_size_64
      : (cce_block_width_p == 256)
        ? e_bedrock_msg_size_32
        : (cce_block_width_p == 128)
          ? e_bedrock_msg_size_16
          : e_bedrock_msg_size_8;

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  `bp_cast_o(bp_bedrock_cce_mem_msg_header_s, mem_cmd_header);
  assign mem_cmd_header_cast_o = '{msg_type : dma_pkt_lo.write_not_read ? e_bedrock_mem_wr : e_bedrock_mem_rd
                                   ,size    : mem_cmd_block_size
                                   ,addr    : dma_pkt_lo.addr
                                   ,payload : '0
                                   };
  assign mem_cmd_header_v_o = dma_pkt_v_lo;
  assign dma_pkt_yumi_li = mem_cmd_header_yumi_i;

  // We're always "ready" for a mem_resp, because when we send a mem_cmd, the cache is waiting
  //   for the DMA data. Unsolicited mem_resp are not allowed by the protocol
  assign mem_resp_header_ready_o = 1'b1;
  wire unused = mem_resp_header_v_i;

endmodule


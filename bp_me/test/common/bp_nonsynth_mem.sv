
/**
 * bp_nonsynth_mem.v
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_nonsynth_mem
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   , parameter preload_mem_p = 0
   , parameter mem_els_p = 0
   , parameter dram_type_p = ""
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cce_mem_msg_width_lp-1:0]        mem_cmd_i
   , input                                   mem_cmd_v_i
   , output logic                            mem_cmd_ready_o

   , output logic [cce_mem_msg_width_lp-1:0] mem_resp_o
   , output logic                            mem_resp_v_o
   , input                                   mem_resp_yumi_i

   , input                                   dram_clk_i
   , input                                   dram_reset_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  bp_bedrock_cce_mem_msg_header_s mem_cmd_header_lo;
  logic [l2_data_width_p-1:0] mem_cmd_data_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li, mem_cmd_last_lo;
  bp_lite_to_stream
   #(.bp_params_p(bp_params_p)
   ,.in_data_width_p(cce_block_width_p)
   ,.out_data_width_p(l2_data_width_p)
   ,.payload_width_p(cce_mem_payload_width_lp)
   ,.payload_mask_p(mem_cmd_payload_mask_gp))
   lite2stream
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.in_msg_i(mem_cmd_i)
     ,.in_msg_v_i(mem_cmd_v_i)
     ,.in_msg_ready_and_o(mem_cmd_ready_o)

     ,.out_msg_header_o(mem_cmd_header_lo)
     ,.out_msg_data_o(mem_cmd_data_lo)
     ,.out_msg_v_o(mem_cmd_v_lo)
     ,.out_msg_ready_and_i(mem_cmd_ready_and_li)
     ,.out_msg_last_o(mem_cmd_last_lo)
     );

  bp_bedrock_cce_mem_msg_header_s mem_resp_header_li;
  logic [l2_data_width_p-1:0] mem_resp_data_li;
  logic mem_resp_v_li, mem_resp_ready_and_lo, mem_resp_last_li;
  bp_stream_to_lite
   #(.bp_params_p(bp_params_p)
   ,.in_data_width_p(l2_data_width_p)
   ,.out_data_width_p(cce_block_width_p)
   ,.payload_width_p(cce_mem_payload_width_lp)
   ,.payload_mask_p(mem_resp_payload_mask_gp))
   stream2lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.in_msg_header_i(mem_resp_header_li)
     ,.in_msg_data_i(mem_resp_data_li)
     ,.in_msg_v_i(mem_resp_v_li)
     ,.in_msg_ready_and_o(mem_resp_ready_and_lo)
     ,.in_msg_last_i(mem_resp_last_li)

     ,.out_msg_o(mem_resp_o)
     ,.out_msg_v_o(mem_resp_v_o)
     ,.out_msg_ready_and_i(mem_resp_yumi_i)
     );

  import bsg_cache_pkg::*;
  `declare_bsg_cache_pkt_s(caddr_width_p, l2_data_width_p);
  bsg_cache_pkt_s cache_pkt_li;
  logic cache_pkt_v_li, cache_pkt_ready_lo;
  logic [l2_data_width_p-1:0] cache_data_lo;
  logic cache_data_v_lo, cache_data_yumi_li;
  bp_me_cce_to_cache
   #(.bp_params_p(bp_params_p)
   ,.mem_data_width_p(l2_data_width_p))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(mem_cmd_header_lo)
     ,.mem_cmd_data_i(mem_cmd_data_lo)
     ,.mem_cmd_v_i(mem_cmd_v_lo)
     ,.mem_cmd_ready_and_o(mem_cmd_ready_and_li)
     ,.mem_cmd_last_i(mem_cmd_last_lo)

     ,.mem_resp_header_o(mem_resp_header_li)
     ,.mem_resp_data_o(mem_resp_data_li)
     ,.mem_resp_v_o(mem_resp_v_li)
     ,.mem_resp_ready_and_i(mem_resp_ready_and_lo)
     ,.mem_resp_last_o(mem_resp_last_li)

     ,.cache_pkt_o(cache_pkt_li)
     ,.cache_pkt_v_o(cache_pkt_v_li)
     ,.cache_pkt_ready_i(cache_pkt_ready_lo)

     ,.cache_data_i(cache_data_lo)
     ,.cache_v_i(cache_data_v_lo)
     ,.cache_yumi_o(cache_data_yumi_li)
     );

  `declare_bsg_cache_dma_pkt_s(caddr_width_p);
  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_fill_width_p-1:0] dma_data_li;
  logic dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_fill_width_p-1:0] dma_data_lo;
  logic dma_data_v_lo, dma_data_yumi_li;

  bsg_cache
   #(.addr_width_p(caddr_width_p)
     ,.data_width_p(l2_data_width_p)
     ,.block_size_in_words_p(l2_block_size_in_words_p)
     ,.sets_p(l2_sets_p)
     ,.ways_p(l2_assoc_p)
     ,.amo_support_p(((amo_swap_p == e_l2) << e_cache_amo_swap)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_xor)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_and)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_or)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_add)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_min)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_max)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_minu)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_maxu)
                     )
     ,.dma_data_width_p(l2_fill_width_p)
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

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_yumi_i(dma_data_yumi_li)

     ,.v_we_o()
     );

  bp_nonsynth_dram
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(preload_mem_p)
     ,.dram_type_p(dram_type_p)
     ,.mem_els_p(mem_els_p)
     )
   dram
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_and_i(dma_data_ready_and_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

endmodule


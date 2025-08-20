
/**
 * bp_nonsynth_mem.v
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_cache.svh"

module bp_nonsynth_mem
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   , parameter mem_str_p = "init_mem"
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]               mem_fwd_data_i
   , input                                          mem_fwd_v_i
   , output logic                                   mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_rev_data_o
   , output logic                                   mem_rev_v_o
   , input                                          mem_rev_ready_and_i
   );

  `declare_bsg_cache_dma_pkt_s(daddr_width_p, l2_block_size_in_words_p);
  bsg_cache_dma_pkt_s [l2_banks_p-1:0] dma_pkt_lo;
  logic [l2_banks_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [l2_banks_p-1:0] dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [l2_banks_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   l2s
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(mem_fwd_header_i)
     ,.mem_fwd_data_i(mem_fwd_data_i)
     ,.mem_fwd_v_i(mem_fwd_v_i)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_o)

     ,.mem_rev_header_o(mem_rev_header_o)
     ,.mem_rev_data_o(mem_rev_data_o)
     ,.mem_rev_v_o(mem_rev_v_o)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_i)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_ready_and_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_and_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_ready_and_i(dma_data_yumi_li)
     );

  bp_nonsynth_dram
   #(.num_dma_p(l2_banks_p)
     ,.dma_addr_width_p(daddr_width_p)
     ,.dma_data_width_p(l2_fill_width_p)
     ,.dma_burst_len_p(l2_block_size_in_fill_p)
     ,.dma_mask_width_p(l2_block_size_in_words_p)
     ,.mem_str_p(mem_str_p)
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
     );

endmodule


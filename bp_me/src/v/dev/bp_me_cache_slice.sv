/**
 *
 * Name:
 *   bp_me_cache_slice.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_cache.vh"
`include "bsg_noc_links.vh"

module bp_me_cache_slice
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)
   )
  (input                                                 clk_i
   , input                                               reset_i

   , input  [mem_fwd_header_width_lp-1:0]                mem_fwd_header_i
   , input  [l2_data_width_p-1:0]                        mem_fwd_data_i
   , input                                               mem_fwd_v_i
   , output logic                                        mem_fwd_ready_and_o
   , input                                               mem_fwd_last_i

   , output logic [mem_rev_header_width_lp-1:0]          mem_rev_header_o
   , output logic [l2_data_width_p-1:0]                  mem_rev_data_o
   , output logic                                        mem_rev_v_o
   , input                                               mem_rev_ready_and_i
   , output logic                                        mem_rev_last_o

   // DRAM interface
   , output logic [l2_banks_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [l2_banks_p-1:0]                       dma_pkt_v_o
   , input [l2_banks_p-1:0]                              dma_pkt_ready_and_i

   , input [l2_banks_p-1:0][l2_fill_width_p-1:0]         dma_data_i
   , input [l2_banks_p-1:0]                              dma_data_v_i
   , output logic [l2_banks_p-1:0]                       dma_data_ready_and_o

   , output logic [l2_banks_p-1:0][l2_fill_width_p-1:0]  dma_data_o
   , output logic [l2_banks_p-1:0]                       dma_data_v_o
   , input [l2_banks_p-1:0]                              dma_data_ready_and_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  `declare_bsg_cache_pkt_s(daddr_width_p, l2_data_width_p);
  bsg_cache_pkt_s [l2_banks_p-1:0] cache_pkt_li;
  logic [l2_banks_p-1:0] cache_pkt_v_li, cache_pkt_ready_and_lo;
  logic [l2_banks_p-1:0][l2_data_width_p-1:0] cache_data_lo;
  logic [l2_banks_p-1:0] cache_data_v_lo, cache_data_yumi_li;

  bp_me_cce_to_cache
   #(.bp_params_p(bp_params_p))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(mem_fwd_header_i)
     ,.mem_fwd_data_i(mem_fwd_data_i)
     ,.mem_fwd_v_i(mem_fwd_v_i)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_o)
     ,.mem_fwd_last_i(mem_fwd_last_i)

     ,.mem_rev_header_o(mem_rev_header_o)
     ,.mem_rev_data_o(mem_rev_data_o)
     ,.mem_rev_v_o(mem_rev_v_o)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_i)
     ,.mem_rev_last_o(mem_rev_last_o)

     ,.cache_pkt_o(cache_pkt_li)
     ,.cache_pkt_v_o(cache_pkt_v_li)
     ,.cache_pkt_ready_and_i(cache_pkt_ready_and_lo)

     ,.cache_data_i(cache_data_lo)
     ,.cache_data_v_i(cache_data_v_lo)
     ,.cache_data_yumi_o(cache_data_yumi_li)
     );

  for (genvar i = 0; i < l2_banks_p; i++)
    begin : bank
      bsg_cache
       #(.addr_width_p(daddr_width_p)
         ,.data_width_p(l2_data_width_p)
         ,.dma_data_width_p(l2_fill_width_p)
         ,.block_size_in_words_p(l2_block_size_in_words_p)
         ,.sets_p(l2_en_p ? l2_sets_p : 2)
         ,.ways_p(l2_en_p ? l2_assoc_p : 2)
         ,.amo_support_p(((l2_amo_support_p[e_amo_swap]) << e_cache_amo_swap)
                         | ((l2_amo_support_p[e_amo_fetch_logic]) << e_cache_amo_xor)
                         | ((l2_amo_support_p[e_amo_fetch_logic]) << e_cache_amo_and)
                         | ((l2_amo_support_p[e_amo_fetch_logic]) << e_cache_amo_or)
                         | ((l2_amo_support_p[e_amo_fetch_arithmetic]) << e_cache_amo_add)
                         | ((l2_amo_support_p[e_amo_fetch_arithmetic]) << e_cache_amo_min)
                         | ((l2_amo_support_p[e_amo_fetch_arithmetic]) << e_cache_amo_max)
                         | ((l2_amo_support_p[e_amo_fetch_arithmetic]) << e_cache_amo_minu)
                         | ((l2_amo_support_p[e_amo_fetch_arithmetic]) << e_cache_amo_maxu)
                         )
        )
       cache
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.cache_pkt_i(cache_pkt_li[i])
         ,.v_i(cache_pkt_v_li[i])
         ,.ready_o(cache_pkt_ready_and_lo[i])

         ,.data_o(cache_data_lo[i])
         ,.v_o(cache_data_v_lo[i])
         ,.yumi_i(cache_data_yumi_li[i])

         ,.dma_pkt_o(dma_pkt_o[i])
         ,.dma_pkt_v_o(dma_pkt_v_o[i])
         ,.dma_pkt_yumi_i(dma_pkt_ready_and_i[i] & dma_pkt_v_o[i])

         ,.dma_data_i(dma_data_i[i])
         ,.dma_data_v_i(dma_data_v_i[i])
         ,.dma_data_ready_o(dma_data_ready_and_o[i])

         ,.dma_data_o(dma_data_o[i])
         ,.dma_data_v_o(dma_data_v_o[i])
         ,.dma_data_yumi_i(dma_data_ready_and_i[i] & dma_data_v_o[i])

         ,.v_we_o()
         );
    end

endmodule


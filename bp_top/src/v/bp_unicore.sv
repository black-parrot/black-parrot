
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_unicore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   // Outgoing I/O
   , output logic [uce_mem_msg_width_lp-1:0]           io_cmd_o
   , output logic                                      io_cmd_v_o
   , input                                             io_cmd_ready_and_i

   , input [uce_mem_msg_width_lp-1:0]                  io_resp_i
   , input                                             io_resp_v_i
   , output logic                                      io_resp_yumi_o

   // Incoming I/O
   , input [uce_mem_msg_width_lp-1:0]                  io_cmd_i
   , input                                             io_cmd_v_i
   , output logic                                      io_cmd_yumi_o

   , output logic [uce_mem_msg_width_lp-1:0]           io_resp_o
   , output logic                                      io_resp_v_o
   , input                                             io_resp_ready_and_i

   // DRAM interface
   , output logic [dma_pkt_width_lp-1:0]               dma_pkt_o
   , output logic                                      dma_pkt_v_o
   , input                                             dma_pkt_yumi_i

   , input [l2_fill_width_p-1:0]                       dma_data_i
   , input                                             dma_data_v_i
   , output logic                                      dma_data_ready_and_o

   , output logic [l2_fill_width_p-1:0]                dma_data_o
   , output logic                                      dma_data_v_o
   , input                                             dma_data_yumi_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_bedrock_mem_if(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce);

  bp_bedrock_uce_mem_msg_s mem_cmd_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li;
  bp_bedrock_uce_mem_msg_s mem_resp_li;
  logic mem_resp_v_li, mem_resp_yumi_lo;

  bp_unicore_lite
   #(.bp_params_p(bp_params_p))
   unicore_lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.io_cmd_o(io_cmd_o)
     ,.io_cmd_v_o(io_cmd_v_o)
     ,.io_cmd_ready_and_i(io_cmd_ready_and_i)

     ,.io_resp_i(io_resp_i)
     ,.io_resp_v_i(io_resp_v_i)
     ,.io_resp_yumi_o(io_resp_yumi_o)

     ,.io_cmd_i(io_cmd_i)
     ,.io_cmd_v_i(io_cmd_v_i)
     ,.io_cmd_yumi_o(io_cmd_yumi_o)

     ,.io_resp_o(io_resp_o)
     ,.io_resp_v_o(io_resp_v_o)
     ,.io_resp_ready_and_i(io_resp_ready_and_i)

     ,.mem_cmd_o(mem_cmd_lo)
     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_ready_and_i(mem_cmd_ready_and_li)

     ,.mem_resp_i(mem_resp_li)
     ,.mem_resp_v_i(mem_resp_v_li)
     ,.mem_resp_yumi_o(mem_resp_yumi_lo)
     );

  import bsg_cache_pkg::*;
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
  
     ,.mem_cmd_i(mem_cmd_lo)
     ,.mem_cmd_v_i(mem_cmd_v_lo)
     ,.mem_cmd_ready_and_o(mem_cmd_ready_and_li)

     ,.mem_resp_o(mem_resp_li)
     ,.mem_resp_v_o(mem_resp_v_li)
     ,.mem_resp_yumi_i(mem_resp_yumi_lo)
  
     ,.cache_pkt_o(cache_pkt_li)
     ,.v_o(cache_pkt_v_li)
     ,.ready_i(cache_pkt_ready_lo)
  
     ,.data_i(cache_data_lo)
     ,.v_i(cache_data_v_lo)
     ,.yumi_o(cache_data_yumi_li)
     );
  
  bsg_cache
   #(.addr_width_p(caddr_width_p)
     ,.data_width_p(l2_data_width_p)
     ,.block_size_in_words_p(l2_block_size_in_words_p)
     ,.sets_p(l2_en_p ? l2_sets_p : 2)
     ,.ways_p(l2_en_p ? l2_assoc_p : 2)
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
  
     ,.dma_pkt_o(dma_pkt_o)
     ,.dma_pkt_v_o(dma_pkt_v_o)
     ,.dma_pkt_yumi_i(dma_pkt_yumi_i)
  
     ,.dma_data_i(dma_data_i)
     ,.dma_data_v_i(dma_data_v_i)
     ,.dma_data_ready_o(dma_data_ready_and_o)
  
     ,.dma_data_o(dma_data_o)
     ,.dma_data_v_o(dma_data_v_o)
     ,.dma_data_yumi_i(dma_data_yumi_i)
  
     ,.v_we_o()
     );

endmodule


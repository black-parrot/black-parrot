
module bp_me_cache_slice
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_yumi_i

   , output [cce_mem_msg_width_lp-1:0]  mem_cmd_o
   , output                             mem_cmd_v_o
   , input                              mem_cmd_yumi_i

   , input [cce_mem_msg_width_lp-1:0]   mem_resp_i
   , input                              mem_resp_v_i
   , output                             mem_resp_ready_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

  `declare_bsg_cache_pkt_s(paddr_width_p, dword_width_p);
  bsg_cache_pkt_s cache_pkt_li;
  logic cache_pkt_v_li, cache_pkt_ready_lo;
  logic [dword_width_p-1:0] cache_data_lo;
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

  `declare_bsg_cache_dma_pkt_s(paddr_width_p);
  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [dword_width_p-1:0] dma_data_li;
  logic dma_data_v_li, dma_data_ready_lo;
  logic [dword_width_p-1:0] dma_data_lo;
  logic dma_data_v_lo, dma_data_yumi_li;
  bsg_cache
   #(.addr_width_p(paddr_width_p)
     ,.data_width_p(dword_width_p)
     ,.block_size_in_words_p(cce_block_width_p/dword_width_p)
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

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_o(dma_data_ready_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_yumi_i(dma_data_yumi_li)

     ,.v_we_o()
     );

  bp_me_cache_dma_to_cce
   #(.bp_params_p(bp_params_p))
   dma_to_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_i(dma_data_ready_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)

     ,.mem_cmd_o(mem_cmd_o)
     ,.mem_cmd_v_o(mem_cmd_v_o)
     ,.mem_cmd_yumi_i(mem_cmd_yumi_i)

     ,.mem_resp_i(mem_resp_i)
     ,.mem_resp_v_i(mem_resp_v_i)
     ,.mem_resp_ready_o(mem_resp_ready_o)
     );

endmodule


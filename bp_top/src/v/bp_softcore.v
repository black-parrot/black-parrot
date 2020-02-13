

module bp_softcore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   , output [cce_mem_msg_width_lp-1:0]                 mem_cmd_o
   , output                                            mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output                                            mem_resp_yumi_o
   );


  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // TODO: Set PC and HartId
     ,.cfg_bus_i('0)
     ,.cfg_npc_data_o()
     ,.cfg_irf_data_o()
     ,.cfg_csr_data_o()
     ,.cfg_priv_data_o()

     ,.lce_ready_i()
     ,.lce_miss_i()
     ,.credits_full_i()
     ,.credits_empty_i()

     ,.load_miss_o()
     ,.store_miss_o()
     ,.lr_miss_o()
     ,.lr_hit_o()
     ,.cache_v_o()
     ,.uncached_load_req_o()
     ,.uncached_store_req_o()

     ,.data_mem_data_o()
     ,.miss_addr_o()
     ,.lru_way_o()
     ,.dirty_o()
     ,.store_o()
     ,.store_data_o()
     ,.size_op_o()

     ,.data_mem_pkt_i()
     ,.data_mem_pkt_v_i()
     ,.data_mem_pkt_yumi_o()

     ,.tag_mem_pkt_i()
     ,.tag_mem_pkt_v_i()
     ,.tag_mem_pkt_yumi_o()

     ,.stat_mem_pkt_i()
     ,.stat_mem_pkt_v_i()
     ,.stat_mem_pkt_yumi_o()

     ,.timer_irq_i()
     ,.software_irq_i()
     ,.external_irq_i()
     );

  bp_uce
   #(.bp_params_p(bp_params_p))
   uce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cache_service_i()
     ,.cache_service_v_i()
     ,.cache_service_ready_o()

     ,.tag_mem_pkt_o()
     ,.data_mem_pkt_o()
     ,.stat_mem_pkt_o()
     ,.cache_fill_v_o()
     ,.cache_fill_yumi_i()

     ,.mem_cmd_o()
     ,.mem_cmd_v_o()
     ,.mem_cmd_ready_i()

     ,.mem_resp_i()
     ,.mem_resp_v_i()
     ,.mem_resp_yumi_o()
     );

endmodule


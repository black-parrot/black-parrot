

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

   // Outgoing I/O
   , output [cce_mem_msg_width_lp-1:0]                 io_cmd_o
   , output                                            io_cmd_v_o
   , input                                             io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  io_resp_i
   , input                                             io_resp_v_i
   , output                                            io_resp_yumi_o

   // Incoming I/O
   , input [cce_mem_msg_width_lp-1:0]                  io_cmd_i
   , input                                             io_cmd_v_i
   , output                                            io_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]                 io_resp_o
   , output                                            io_resp_v_o
   , input                                             io_resp_ready_i

   // Memory Requests
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

     ,.cache_req_o()
     ,.cache_req_v_o()
     ,.cache_req_ready_i()

     ,.data_mem_pkt_i()
     ,.data_mem_pkt_v_i()
     ,.data_mem_pkt_ready_o()
     ,.data_mem_o()

     ,.tag_mem_pkt_i()
     ,.tag_mem_pkt_v_i()
     ,.tag_mem_pkt_ready_o()
     ,.tag_mem_o()

     ,.stat_mem_pkt_i()
     ,.stat_mem_pkt_v_i()
     ,.stat_mem_pkt_ready_o()
     ,.stat_mem_o()

     ,.cache_req_complete_o()

     ,.credits_full_i()
     ,.credits_empty_i()

     ,.timer_irq_i()
     ,.software_irq_i()
     ,.external_irq_i()
     );

  bp_uce
   #(.bp_params_p(bp_params_p))
   uce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cache_req_i()
     ,.cache_req_v_i()
     ,.cache_req_ready_o()

     ,.tag_mem_pkt_o()
     ,.tag_mem_pkt_v_o()
     ,.tag_mem_pkt_ready_i()
     ,.tag_mem_i()

     ,.data_mem_pkt_o()
     ,.data_mem_pkt_v_o()
     ,.data_mem_pkt_ready_i()
     ,.data_mem_i()

     ,.stat_mem_pkt_o()
     ,.stat_mem_pkt_v_o()
     ,.stat_mem_pkt_ready_i()
     ,.stat_mem_i()

     ,.cache_req_complete_o()

     ,.credits_full_i()
     ,.credits_empty()

     ,.mem_cmd_o()
     ,.mem_cmd_v_o()
     ,.mem_cmd_ready_i()

     ,.mem_resp_i()
     ,.mem_resp_v_i()
     ,.mem_resp_yumi_o()
     );

endmodule


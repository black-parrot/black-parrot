

module bp_l15_encoder
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   )
  (input clk_i
   , input reset_i

   , input [paddr_width_p-1:0]                         transducer_l15_address
   , output                                            transducer_l15_req_ack

   , input                                             l15_transducer_val
   , input [3:0]                                       l15_transducer_returntype

   , input [63:0]                                      l15_transducer_data_0
   , input [63:0]                                      l15_transducer_data_1

   // L1.5 -> BP
   , input [mem_cce_resp_width_lp-1:0]                 mem_resp_i
   , input                                             mem_resp_v_i
   , output                                            mem_resp_ready_o

   , input [mem_cce_data_resp_width_lp-1:0]            mem_data_resp_i
   , input                                             mem_data_resp_v_i
   , output                                            mem_data_resp_ready_o
   );



endmodule 
  

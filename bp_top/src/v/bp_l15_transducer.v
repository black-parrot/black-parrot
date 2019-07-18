

module bp_l15_transducer
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   )
  (input clk_i
   , input reset_i

   // BP -> L1.5 
   , input [cce_mem_cmd_width_lp-1:0]                  mem_cmd_i
   , input                                             mem_cmd_v_i
   , output                                            mem_cmd_yumi_o

   , input [cce_mem_data_cmd_width_lp-1:0]             mem_data_cmd_i
   , input                                             mem_data_cmd_v_i
   , output                                            mem_data_cmd_yumi_o

   // OpenPiton side
   , output [4:0]                                      transducer_l15_rqtype
   , output [2:0]                                      transducer_l15_size
   , output                                            transducer_l15_val
   , output [paddr_width_p-1:0]                        transducer_l15_address
   , output [63:0]                                     transducer_l15_data
   , output                                            transducer_l15_nc
   , input                                             l15_transducer_ack
   , input                                             l15_transducer_header_ack

   , input                                             l15_transducer_val
   , input [3:0]                                       l15_transducer_returntype
   , input [63:0]                                      l15_transducer_data_0
   , input [63:0]                                      l15_transducer_data_1
   , output                                            transducer_l15_req_ack

   // Unused OpenPiton side connections
   , output [3:0]                                      transducer_l15_amo_op
   , output [0:0]                                      transducer_l15_threadid
   , output                                            transducer_l15_prefetch
   , output                                            transducer_l15_invalidate_cacheline
   , output                                            transducer_l15_blockstore
   , output                                            transducer_l15_blockinitstore
   , output                                            transducer_l15_l1rplway
   , output                                            transducer_l15_data_next_entry
   , output                                            transducer_l15_csm_data

   // L1.5 -> BP
   , input [mem_cce_resp_width_lp-1:0]                 mem_resp_i
   , input                                             mem_resp_v_i
   , output                                            mem_resp_ready_o

   , input [mem_cce_data_resp_width_lp-1:0]            mem_data_resp_i
   , input                                             mem_data_resp_v_i
   , output                                            mem_data_resp_ready_o
   );

// BP -> L1.15
bp_l15_decoder 
 #(.cfg_p(cfg_p)) 
 l15_decoder 
  (.l15_req_addr_o(l15_req_addr_lo)
   ,.*
   );

// L1.5 -> BP
bp_l15_encoder 
 #(.cfg_p(cfg_p)) 
 l15_encoder 
  (.l15_req_addr_i(l15_req_addr_lo)
   ,.*
   );

endmodule 
  

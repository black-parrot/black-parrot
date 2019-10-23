/*                                  
 * wrapper.v
 */

module wrapper
 import bp_fe_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;  
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [`BSG_SAFE_CLOG2(num_lce_p)-1:0]           icache_id_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output                                           fe_cmd_ready_o

   , output [fe_queue_width_lp-1:0]                   fe_queue_o
   , output                                           fe_queue_v_o
   , input                                            fe_queue_ready_i

   , output [lce_cce_req_width_lp-1:0]                lce_req_o
   , output                                           lce_req_v_o
   , input                                            lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]               lce_resp_o
   , output                                           lce_resp_v_o
   , input                                            lce_resp_ready_i

   , output [lce_cce_data_resp_width_lp-1:0]          lce_data_resp_o     
   , output                                           lce_data_resp_v_o 
   , input                                            lce_data_resp_ready_i

   , input [cce_lce_cmd_width_lp-1:0]                 lce_cmd_i
   , input                                            lce_cmd_v_i
   , output                                           lce_cmd_ready_o

   , input [lce_data_cmd_width_lp-1:0]                lce_data_cmd_i
   , input                                            lce_data_cmd_v_i
   , output                                           lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]               lce_data_cmd_o
   , output                                           lce_data_cmd_v_o
   , input                                            lce_data_cmd_ready_i

   );

  bp_fe_top
  #(.bp_params_p(bp_params_p)) 
  dut
   (.*);

endmodule : wrapper


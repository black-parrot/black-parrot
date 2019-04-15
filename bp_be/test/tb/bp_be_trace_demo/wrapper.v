
module wrapper
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
    `declare_bp_proc_params(cfg_p)
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

    // Enables trace replay

   // Default parameters 
   , parameter load_to_use_forwarding_p    = 1
   , parameter trace_p                     = 0
   , parameter calc_debug_p                = 0

   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(num_core_p, num_lce_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_ready_o

   , output                                  fe_queue_clr_o
   , output                                  fe_queue_dequeue_o
   , output                                  fe_queue_rollback_o
 
   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_ready_i

   // LCE-CCE interface
   , output [lce_cce_req_width_lp-1:0]       lce_req_o
   , output                                  lce_req_v_o
   , input                                   lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]      lce_resp_o
   , output                                  lce_resp_v_o
   , input                                   lce_resp_ready_i                                 

   , output [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output                                  lce_data_resp_v_o
   , input                                   lce_data_resp_ready_i

   , input [cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   , input                                   lce_cmd_v_i
   , output                                  lce_cmd_ready_o

   , input [lce_data_cmd_width_lp-1:0]       lce_data_cmd_i
   , input                                   lce_data_cmd_v_i
   , output                                  lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]      lce_data_cmd_o
   , output                                  lce_data_cmd_v_o
   , input                                   lce_data_cmd_ready_i

   , input                                   timer_int_i
   , input                                   software_int_i
   , input                                   external_int_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   // Commit tracer for trace replay
   , output                                  cmt_rd_w_v_o
   , output [rv64_reg_addr_width_gp-1:0]     cmt_rd_addr_o
   , output                                  cmt_mem_w_v_o
   , output [dword_width_p-1:0]              cmt_mem_addr_o
   , output [`bp_be_fu_op_width-1:0]         cmt_mem_op_o
   , output [dword_width_p-1:0]              cmt_data_o
   );

  bp_be_top
   #(.cfg_p(cfg_p)
     ,.trace_p(trace_p)
     ,.calc_debug_p(calc_debug_p)
     )
   dut
    (.*);

endmodule : wrapper


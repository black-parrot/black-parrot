/**
 *
 * wrapper.v
 *
 */

module wrapper
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(cfg_p)
   , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)

   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0
   )
  (input                                                      clk_i
   , input                                                    reset_i
   , input [num_cce_p-1:0]                                    freeze_i

   // Config channel
   , input [num_cce_p-1:0][bp_cfg_link_addr_width_gp-2:0]        config_addr_i
   , input [num_cce_p-1:0][bp_cfg_link_data_width_gp-1:0]        config_data_i
   , input [num_cce_p-1:0]                                       config_v_i
   , input [num_cce_p-1:0]                                       config_w_i
   , output logic [num_cce_p-1:0]                                config_ready_o

   , output logic [num_cce_p-1:0][bp_cfg_link_data_width_gp-1:0] config_data_o
   , output logic [num_cce_p-1:0]                                config_v_o
   , input [num_cce_p-1:0]                                       config_ready_i

   , input [num_cce_p-1:0][mem_cce_resp_width_lp-1:0]         mem_resp_i
   , input [num_cce_p-1:0]                                    mem_resp_v_i
   , output [num_cce_p-1:0]                                   mem_resp_ready_o

   , input [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0]    mem_data_resp_i
   , input [num_cce_p-1:0]                                    mem_data_resp_v_i
   , output [num_cce_p-1:0]                                   mem_data_resp_ready_o

   , output [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0]         mem_cmd_o
   , output [num_cce_p-1:0]                                   mem_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_cmd_yumi_i

   , output [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output [num_cce_p-1:0]                                   mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_data_cmd_yumi_i

   , input [num_core_p-1:0]                                   external_irq_i
  );

  bp_top
   #(.cfg_p(cfg_p)
     ,.calc_trace_p(calc_trace_p)
     ,.cce_trace_p(cce_trace_p)
     )
   dut
    (.*);

endmodule : wrapper



/**
 * bp_mem.v
 */

module bp_mem
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , parameter mem_cap_in_bytes_p = "inv"
   , parameter mem_zero_p         = 0
   , parameter mem_load_p         = 0
   , parameter mem_file_p         = "inv"
   , parameter mem_offset_p       = 0

   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 0
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = "inv"

   , parameter dram_clock_period_in_ps_p = "inv"
   , parameter dram_cfg_p                = "inv"
   , parameter dram_sys_cfg_p            = "inv"
   , parameter dram_capacity_p           = "inv"

   , localparam num_block_bytes_lp = cce_block_width_p / 8
   )
  (input                                 clk_i
   , input                               reset_i

   // BP side
   , input [cce_mem_msg_width_lp-1:0]    mem_cmd_i
   , input                               mem_cmd_v_i
   , output                              mem_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
   , output                              mem_resp_v_o
   , input                               mem_resp_ready_i
   );

logic                          dram_v_li, dram_w_li;
logic [paddr_width_p-1:0]      dram_addr_li;
logic [num_block_bytes_lp-1:0] dram_wmask_li;
logic [cce_block_width_p-1:0]  dram_data_li, dram_data_lo;
logic                          dram_v_lo, delayed_dram_v_lo;
logic                          dram_ready_lo, delayed_dram_yumi_li;

bp_mem_transducer
 #(.cfg_p(cfg_p)
   ,.dram_offset_p(mem_offset_p)
   )
 transducer
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(mem_cmd_i)
   ,.mem_cmd_v_i(mem_cmd_v_i)
   ,.mem_cmd_yumi_o(mem_cmd_yumi_o)

   ,.mem_resp_o(mem_resp_o)
   ,.mem_resp_v_o(mem_resp_v_o)
   ,.mem_resp_ready_i(mem_resp_ready_i)

   ,.ready_i(dram_ready_lo)
   ,.v_o(dram_v_li)
   ,.w_o(dram_w_li)

   ,.addr_o(dram_addr_li)
   ,.data_o(dram_data_li)
   ,.write_mask_o(dram_wmask_li)

   ,.data_i(dram_data_lo)
   ,.v_i(delayed_dram_v_lo)
   ,.yumi_o(delayed_dram_yumi_li)
   );

bp_mem_delay_model
 #(.addr_width_p(paddr_width_p)
   ,.use_max_latency_p(use_max_latency_p)
   ,.use_random_latency_p(use_random_latency_p)
   ,.use_dramsim2_latency_p(use_dramsim2_latency_p)
   ,.max_latency_p(max_latency_p)
   ,.dram_clock_period_in_ps_p(dram_clock_period_in_ps_p)
   ,.dram_cfg_p(dram_cfg_p)
   ,.dram_sys_cfg_p(dram_sys_cfg_p)
   ,.dram_capacity_p(dram_capacity_p)
   )
 delay_model
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.v_i(dram_v_li)
   ,.w_i(dram_w_li)
   ,.addr_i(dram_addr_li)
   ,.ready_o(dram_ready_lo)

   ,.v_o(delayed_dram_v_lo)
   ,.yumi_i(delayed_dram_yumi_li)
   );

bp_mem_storage_sync
 #(.data_width_p(cce_block_width_p)
   ,.addr_width_p(paddr_width_p)
   ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
   ,.mem_zero_p(mem_zero_p)
   ,.mem_load_p(mem_load_p)
   ,.mem_file_p(mem_file_p)
   ,.mem_offset_p(mem_offset_p)
   )
 dram
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.v_i(dram_v_li)
   ,.w_i(dram_w_li)

   ,.addr_i(dram_addr_li)
   ,.data_i(dram_data_li)
   ,.write_mask_i(dram_wmask_li)

   ,.data_o(dram_data_lo)
   );

endmodule


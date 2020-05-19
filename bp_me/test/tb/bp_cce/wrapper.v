/**
 *
 * wrapper.v
 *
 */
 
`include "bsg_noc_links.vh"

module wrapper
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   // interface widths
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

   , parameter cce_trace_p = 0
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [cfg_bus_width_lp-1:0]                          cfg_bus_i
   , output logic [cce_instr_width_p-1:0]                  cfg_cce_ucode_data_o

   // LCE-CCE Interface
   , input [lce_cce_req_width_lp-1:0]                      lce_req_i
   , input                                                 lce_req_v_i
   , output logic                                          lce_req_yumi_o

   , input [lce_cce_resp_width_lp-1:0]                     lce_resp_i
   , input                                                 lce_resp_v_i
   , output logic                                          lce_resp_yumi_o

   , output logic [lce_cmd_width_lp-1:0]                   lce_cmd_o
   , output logic                                          lce_cmd_v_o
   , input                                                 lce_cmd_ready_i

   // CCE-MEM Interface
   , input [cce_mem_msg_width_lp-1:0]                      mem_resp_i
   , input                                                 mem_resp_v_i
   , output logic                                          mem_resp_yumi_o

   , output logic [cce_mem_msg_width_lp-1:0]               mem_cmd_o
   , output logic                                          mem_cmd_v_o
   , input                                                 mem_cmd_ready_i
  );

  bp_cce_wrapper
   #(.bp_params_p(bp_params_p))
   dut
    (.*);

endmodule : wrapper


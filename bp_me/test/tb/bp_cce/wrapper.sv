/**
 *
 * wrapper.sv
 *
 */

`include "bsg_noc_links.vh"

module wrapper
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   // interface widths
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   , input                                          ucode_v_i
   , input                                          ucode_w_i
   , input [cce_pc_width_p-1:0]                     ucode_addr_i
   , input [cce_instr_width_gp-1:0]                 ucode_data_i
   , output [cce_instr_width_gp-1:0]                ucode_data_o

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_ready_and_o
   , input                                          lce_req_has_data_i
   , input [bedrock_data_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_data_v_i
   , output logic                                   lce_req_data_ready_and_o
   , input                                          lce_req_last_i

   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , output logic                                   lce_resp_header_ready_and_o
   , input                                          lce_resp_has_data_i
   , input [bedrock_data_width_p-1:0]               lce_resp_data_i
   , input                                          lce_resp_data_v_i
   , output logic                                   lce_resp_data_ready_and_o
   , input                                          lce_resp_last_i

   , output logic [lce_cmd_header_width_lp-1:0]     lce_cmd_header_o
   , output logic                                   lce_cmd_header_v_o
   , input                                          lce_cmd_header_ready_and_i
   , output logic                                   lce_cmd_has_data_o
   , output logic [bedrock_data_width_p-1:0]        lce_cmd_data_o
   , output logic                                   lce_cmd_data_v_o
   , input                                          lce_cmd_data_ready_and_i
   , output logic                                   lce_cmd_last_o

   // CCE-MEM Interface
   // BedRock Burst protocol: ready&valid
   , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
   , input [bedrock_data_width_p-1:0]               mem_rev_data_i
   , input                                          mem_rev_v_i
   , output logic                                   mem_rev_ready_and_o
   , input                                          mem_rev_last_i

   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_data_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i
   , output logic                                   mem_fwd_last_o
  );

  bp_cce_wrapper
   #(.bp_params_p(bp_params_p))
   dut
    (.*);

endmodule


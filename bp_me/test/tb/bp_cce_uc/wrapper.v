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
   , localparam lg_num_cce_lp = `BSG_SAFE_CLOG2(num_cce_p)

   // interface widths
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
   , parameter cce_trace_p = 0
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [cfg_bus_width_lp-1:0]                         cfg_bus_i
   , output logic [cce_instr_width_p-1:0]                  cfg_cce_ucode_data_o

   // LCE-CCE Interface
   // inbound: ready&valid
   // Inputs to CCE from LCE are buffered by two element FIFOs
   , input [lce_cce_req_width_lp-1:0]                      lce_req_i
   , input                                                 lce_req_v_i
   , output logic                                          lce_req_ready_o

   , input [lce_cce_resp_width_lp-1:0]                     lce_resp_i
   , input                                                 lce_resp_v_i
   , output logic                                          lce_resp_ready_o

   // outbound: ready&valid
   // messages are not buffered by the CCE, and connection is directly to ME network
   , output logic [lce_cmd_width_lp-1:0]                   lce_cmd_o
   , output logic                                          lce_cmd_v_o
   , input                                                 lce_cmd_ready_i

   // CCE-MEM Interface
   // inbound: ready&valid, helpful consumer from demanding producer
   // outbound: valid->yumi, helpful producer to demanding consumer
   // Both inbound and outbound messages are buffered by two element FIFOs
   , input [cce_mem_msg_width_lp-1:0]                      mem_resp_i
   , input                                                 mem_resp_v_i
   , output logic                                          mem_resp_ready_o

   , input [cce_mem_msg_width_lp-1:0]                      mem_cmd_i
   , input                                                 mem_cmd_v_i
   , output logic                                          mem_cmd_ready_o

   , output logic [cce_mem_msg_width_lp-1:0]               mem_cmd_o
   , output logic                                          mem_cmd_v_o
   , input                                                 mem_cmd_yumi_i

   , output logic [cce_mem_msg_width_lp-1:0]               mem_resp_o
   , output logic                                          mem_resp_v_o
   , input                                                 mem_resp_yumi_i
   );

  bp_cce_top
   #(.bp_params_p(bp_params_p))
   dut
    (.*);

  bind bp_cce_top
    bp_cce_nonsynth_tracer
      #(.bp_params_p(bp_params_p))
      bp_cce_tracer
       (.clk_i(clk_i & (wrapper.cce_trace_p == 1))
        ,.reset_i(reset_i)
        ,.freeze_i(bp_cce.inst_ram.cfg_bus_cast_i.freeze)
  
        ,.cce_id_i('0)
  
        // To CCE
        ,.lce_req_i(lce_req_to_cce)
        ,.lce_req_v_i(lce_req_v_to_cce)
        ,.lce_req_yumi_i(lce_req_yumi_from_cce)
        ,.lce_resp_i(lce_resp_to_cce)
        ,.lce_resp_v_i(lce_resp_v_to_cce)
        ,.lce_resp_yumi_i(lce_resp_yumi_from_cce)
  
        // From CCE
        ,.lce_cmd_i(lce_cmd_o)
        ,.lce_cmd_v_i(lce_cmd_v_o)
        ,.lce_cmd_ready_i(lce_cmd_ready_i)
  
        // To CCE
        ,.mem_resp_i(mem_resp_to_cce)
        ,.mem_resp_v_i(mem_resp_v_to_cce)
        ,.mem_resp_yumi_i(mem_resp_yumi_from_cce)
  
        // From CCE
        ,.mem_cmd_i(mem_cmd_from_cce)
        ,.mem_cmd_v_i(mem_cmd_v_from_cce)
        ,.mem_cmd_ready_i(mem_cmd_ready_to_cce)
        );

endmodule : wrapper


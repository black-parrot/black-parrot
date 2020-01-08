/**
  *
  * testbench.v
  *
  */
  
`include "bsg_noc_links.vh"

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   // Tracing parameters
   , parameter calc_trace_p                = 0
   , parameter cce_trace_p                 = 0
   , parameter cmt_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter npc_trace_p                 = 0
   , parameter dcache_trace_p              = 0
   , parameter vm_trace_p                  = 0
   , parameter preload_mem_p               = 0
   , parameter skip_init_p                 = 0

   , parameter mem_zero_p         = 1
   , parameter mem_file_p         = "prog.mem"
   , parameter mem_cap_in_bytes_p = 2**20
   , parameter [paddr_width_p-1:0] mem_offset_p = paddr_width_p'(32'h8000_0000)

   // Number of elements in the fake BlackParrot memory
   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 1
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = 15

   , parameter dram_clock_period_in_ps_p = 1000
   , parameter dram_cfg_p                = "dram_ch.ini"
   , parameter dram_sys_cfg_p            = "dram_sys.ini"
   , parameter dram_capacity_p           = 16384
   )
  (input clk_i
   , input reset_i
   );

`declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
`declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p)

bp_io_noc_ral_link_s [E:P] cmd_link_li, cmd_link_lo;
bp_io_noc_ral_link_s [E:P] resp_link_li, resp_link_lo;

bp_cce_mem_msg_s dram_cmd_li;
logic            dram_cmd_v_li, dram_cmd_yumi_lo;
bp_cce_mem_msg_s dram_resp_lo;
logic            dram_resp_v_lo, dram_resp_ready_li;

bp_io_noc_ral_link_s proc_cmd_link_li, proc_cmd_link_lo;
bp_io_noc_ral_link_s proc_resp_link_li, proc_resp_link_lo;

bp_mem_noc_ral_link_s bypass_cmd_link_lo, bypass_resp_link_li;

bp_cce_io_msg_s        host_cmd_li;
logic                  host_cmd_v_li, host_cmd_yumi_lo;
bp_cce_io_msg_s        host_resp_lo;
logic                  host_resp_v_lo, host_resp_ready_li;

bp_cce_io_msg_s        load_cmd_lo;
logic                  load_cmd_v_lo, load_cmd_ready_li;
bp_cce_io_msg_s        load_resp_li;
logic                  load_resp_v_li, load_resp_ready_lo;

bp_cce_io_msg_s        cfg_cmd_lo;
logic                  cfg_cmd_v_lo, cfg_cmd_ready_li;
bp_cce_io_msg_s        cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

bp_cce_io_msg_s        nbf_cmd_lo;
logic                  nbf_cmd_v_lo, nbf_cmd_ready_li;
bp_cce_io_msg_s        nbf_resp_li;
logic                  nbf_resp_v_li, nbf_resp_ready_lo;

wire [io_noc_did_width_p-1:0] dram_did_li = '1;
wire [io_noc_did_width_p-1:0] proc_did_li = 1;

bp_io_noc_ral_link_s stub_cmd_link_li, stub_resp_link_li;
bp_io_noc_ral_link_s stub_cmd_link_lo, stub_resp_link_lo;
assign stub_cmd_link_li  = '0;
assign stub_resp_link_li = '0;

bp_mem_noc_ral_link_s stub_bypass_cmd_link_lo, stub_bypass_resp_link_li;
assign stub_bypass_resp_link_li = '0;
// Chip
wrapper
 #(.bp_params_p(bp_params_p))
 wrapper
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   );

endmodule


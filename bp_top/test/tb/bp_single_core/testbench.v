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

`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

bp_cce_mem_msg_s proc_cmd_lo;
logic proc_cmd_v_lo, proc_cmd_ready_li;
bp_cce_mem_msg_s proc_resp_li;
logic proc_resp_v_li, proc_resp_yumi_lo;
wrapper
 #(.bp_params_p(bp_params_p))
 wrapper
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_o(proc_cmd_lo)
   ,.mem_cmd_v_o(proc_cmd_v_lo)
   ,.mem_cmd_ready_i(proc_cmd_ready_li)

   ,.mem_resp_i(proc_resp_li)
   ,.mem_resp_v_i(proc_resp_v_li)
   ,.mem_resp_yumi_o(proc_resp_yumi_lo)
   );

bp_cce_mem_msg_s dram_cmd_li;
logic            dram_cmd_v_li, dram_cmd_yumi_lo;
bp_cce_mem_msg_s dram_resp_lo;
logic            dram_resp_v_lo, dram_resp_ready_li;

bsg_two_fifo
 #(.width_p($bits(bp_cce_mem_msg_s)))
 cmd_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(proc_cmd_lo)
   ,.v_i(proc_cmd_v_lo)
   ,.ready_o(proc_cmd_ready_li)

   ,.data_o(dram_cmd_li)
   ,.v_o(dram_cmd_v_li)
   ,.yumi_i(dram_cmd_yumi_lo)
   );

bsg_two_fifo
 #(.width_p($bits(bp_cce_mem_msg_s)))
 resp_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(dram_resp_lo)
   ,.v_i(dram_resp_v_lo)
   ,.ready_o(dram_resp_ready_li)

   ,.data_o(proc_resp_li)
   ,.v_o(proc_resp_v_li)
   ,.yumi_i(proc_resp_yumi_lo)
   );

bp_mem
 #(.bp_params_p(bp_params_p)
   ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
   ,.mem_load_p(preload_mem_p)
   ,.mem_zero_p(mem_zero_p)
   ,.mem_file_p(mem_file_p)
   ,.mem_offset_p(mem_offset_p)
 
   ,.use_max_latency_p(use_max_latency_p)
   ,.use_random_latency_p(use_random_latency_p)
   ,.use_dramsim2_latency_p(use_dramsim2_latency_p)
   ,.max_latency_p(max_latency_p)
 
   ,.dram_clock_period_in_ps_p(dram_clock_period_in_ps_p)
   ,.dram_cfg_p(dram_cfg_p)
   ,.dram_sys_cfg_p(dram_sys_cfg_p)
   ,.dram_capacity_p(dram_capacity_p)
   )
 mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
 
   ,.mem_cmd_i(dram_cmd_li)
   ,.mem_cmd_v_i(dram_cmd_v_li)
   ,.mem_cmd_yumi_o(dram_cmd_yumi_lo)
 
   ,.mem_resp_o(dram_resp_lo)
   ,.mem_resp_v_o(dram_resp_v_lo)
   ,.mem_resp_ready_i(dram_resp_ready_li)
   );

//bp_cce_mem_msg_s       host_cmd_li;
//logic                  host_cmd_v_li, host_cmd_yumi_lo;
//bp_cce_mem_msg_s       host_resp_lo;
//logic                  host_resp_v_lo, host_resp_ready_li;
//
//logic [num_core_p-1:0] program_finish;
//bp_nonsynth_host
// #(.bp_params_p(bp_params_p))
// host_mmio
//  (.clk_i(clk_i)
//   ,.reset_i(reset_i)
//
//   ,.io_cmd_i(host_cmd_li)
//   ,.io_cmd_v_i(host_cmd_v_li)
//   ,.io_cmd_yumi_o(host_cmd_yumi_lo)
//
//   ,.io_resp_o(host_resp_lo)
//   ,.io_resp_v_o(host_resp_v_lo)
//   ,.io_resp_ready_i(host_resp_ready_li)
//
//   ,.program_finish_o(program_finish)
//   );

bp_nonsynth_if_verif
 #(.bp_params_p(bp_params_p))
 if_verif
  ();

endmodule


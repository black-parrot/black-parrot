/**
  *
  * testbench.v
  *
  */
  
//`include "bp_be_dcache_pkt.vh"

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(cfg_p)

   // interface widths
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)

   , parameter cce_trace_p = 0
   , parameter axe_trace_p = 0
   , parameter instr_count = 1
   , parameter skip_init_p = 0
   , parameter lce_perf_trace_p = 0

   // Number of elements in the fake BlackParrot memory
   , parameter clock_period_in_ps_p = 1000
   , parameter prog_name_p = "prog.mem"
   , parameter dram_cfg_p  = "dram_ch.ini"
   , parameter dram_sys_cfg_p = "dram_sys.ini"
   , parameter dram_capacity_p = 16384

   // LCE Trace Replay Width
   , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
   , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
   , localparam tr_rom_addr_width_p = 20

   // Config link
   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

   )
  (input clk_i
   , input reset_i
   , input freeze_i

   // Load/Store command in
   , input tr_pkt_v_i
   , input [tr_ring_width_lp-1:0] tr_pkt_i
   , output logic tr_pkt_yumi_o

    // Load/store response out
   , output logic tr_pkt_v_o
   , output logic [tr_ring_width_lp-1:0] tr_pkt_o
   , input tr_pkt_ready_i

   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p);
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

// CFG IF
bp_cce_mem_data_cmd_s  cfg_data_cmd_lo;
logic                  cfg_data_cmd_v_lo, cfg_data_cmd_yumi_li;
bp_mem_cce_resp_s      cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

logic [cfg_addr_width_p-1:0] config_addr_li;
logic [cfg_data_width_p-1:0] config_data_li;
logic                        config_v_li;

// Freeze signal register
/*
logic freeze_r;
always_ff @(posedge clk_i) begin
  if (reset_i)
    freeze_r <= 1'b1;
  else if (config_v_li & (config_addr_li == bp_cfg_reg_freeze_gp))
    freeze_r <= config_data_li[0];
end
*/

// CCE-MEM IF
bp_mem_cce_resp_s      mem_resp;
logic                  mem_resp_v, mem_resp_ready;
bp_mem_cce_data_resp_s mem_data_resp;
logic                  mem_data_resp_v, mem_data_resp_ready;
bp_cce_mem_cmd_s       mem_cmd;
logic                  mem_cmd_v, mem_cmd_yumi;
bp_cce_mem_data_cmd_s  mem_data_cmd;
logic                  mem_data_cmd_v, mem_data_cmd_yumi;

// LCE-CCE IF
bp_lce_cce_req_s       lce_req;
logic                  lce_req_v, lce_req_ready;
bp_lce_cce_resp_s      lce_resp;
logic                  lce_resp_v, lce_resp_ready;
bp_lce_cce_data_resp_s lce_data_resp;
logic                  lce_data_resp_v, lce_data_resp_ready;
bp_cce_lce_cmd_s       lce_cmd;
logic                  lce_cmd_v, lce_cmd_ready;
bp_lce_data_cmd_s      lce_data_cmd_li;
logic                  lce_data_cmd_v_li, lce_data_cmd_ready_lo;
bp_lce_data_cmd_s      lce_data_cmd_lo;
logic                  lce_data_cmd_v_lo, lce_data_cmd_ready_li;
// Single LCE setup - LCE should never send a Data Command
assign lce_data_cmd_ready_li = '0;

// LCE
bp_me_nonsynth_mock_lce #(
  .cfg_p(cfg_p)
  ,.axe_trace_p(axe_trace_p)
  ,.perf_trace_p(lce_perf_trace_p)
) lce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.freeze_i(freeze_i)

  ,.lce_id_i('0)

  ,.tr_pkt_i(tr_pkt_i)
  ,.tr_pkt_v_i(tr_pkt_v_i)
  ,.tr_pkt_yumi_o(tr_pkt_yumi_o)

  ,.tr_pkt_v_o(tr_pkt_v_o)
  ,.tr_pkt_o(tr_pkt_o)
  ,.tr_pkt_ready_i(tr_pkt_ready_i)

  ,.lce_req_o(lce_req)
  ,.lce_req_v_o(lce_req_v)
  ,.lce_req_ready_i(lce_req_ready)

  ,.lce_resp_o(lce_resp)
  ,.lce_resp_v_o(lce_resp_v)
  ,.lce_resp_ready_i(lce_resp_ready)

  ,.lce_data_resp_o(lce_data_resp)
  ,.lce_data_resp_v_o(lce_data_resp_v)
  ,.lce_data_resp_ready_i(lce_data_resp_ready)

  ,.lce_cmd_i(lce_cmd)
  ,.lce_cmd_v_i(lce_cmd_v)
  ,.lce_cmd_ready_o(lce_cmd_ready)

  ,.lce_data_cmd_i(lce_data_cmd_li)
  ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
  ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo)

  ,.lce_data_cmd_o(lce_data_cmd_lo)
  ,.lce_data_cmd_v_o(lce_data_cmd_v_lo)
  ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li)
);

/* TODO: uncomment for tracing
// LCE
bind bp_me_nonsynth_mock_lce
bp_me_nonsynth_lce_tracer #(
  .cfg_p(cfg_p)
  ,.perf_trace_p(perf_trace_p)
) lce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.freeze_i(freeze_i)

  ,.lce_id_i('0)

  ,.tr_pkt_i(tr_pkt_i)
  ,.tr_pkt_v_i(tr_pkt_v_i)
  ,.tr_pkt_yumi_i(tr_pkt_yumi_o)

  ,.tr_pkt_v_o_i(tr_pkt_v_o)
  ,.tr_pkt_ready_i(tr_pkt_ready_i)

  ,.lce_req_i(lce_req_o)
  ,.lce_req_v_i(lce_req_v_o)
  ,.lce_req_ready_i(lce_req_ready_i)

  ,.lce_cmd_i(lce_cmd_i)
  ,.lce_cmd_v_i(lce_cmd_v_i)
  ,.lce_cmd_ready_i(lce_cmd_ready_o)

  ,.lce_data_cmd_i(lce_data_cmd_i)
  ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
  ,.lce_data_cmd_ready_i(lce_data_cmd_ready_o)
);
*/

// CCE
wrapper
#(.cfg_p(cfg_p)
  ,.cce_trace_p(cce_trace_p)
 )
wrapper
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  // maybe tie to reset?
  ,.freeze_i(freeze_i)

  ,.cfg_w_v_i('0)
  ,.cfg_addr_i('0)
  ,.cfg_data_i('0)

  ,.cce_id_i('0)

  ,.lce_cmd_o(lce_cmd)
  ,.lce_cmd_v_o(lce_cmd_v)
  ,.lce_cmd_ready_i(lce_cmd_ready)

  ,.lce_data_cmd_o(lce_data_cmd_li)
  ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
  ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

  ,.lce_req_i(lce_req)
  ,.lce_req_v_i(lce_req_v)
  ,.lce_req_ready_o(lce_req_ready)

  ,.lce_resp_i(lce_resp)
  ,.lce_resp_v_i(lce_resp_v)
  ,.lce_resp_ready_o(lce_resp_ready)

  ,.lce_data_resp_i(lce_data_resp)
  ,.lce_data_resp_v_i(lce_data_resp_v)
  ,.lce_data_resp_ready_o(lce_data_resp_ready)

  ,.mem_resp_i(mem_resp)
  ,.mem_resp_v_i(mem_resp_v)
  ,.mem_resp_ready_o(mem_resp_ready)

  ,.mem_data_resp_i(mem_data_resp)
  ,.mem_data_resp_v_i(mem_data_resp_v)
  ,.mem_data_resp_ready_o(mem_data_resp_ready)

  ,.mem_cmd_o(mem_cmd)
  ,.mem_cmd_v_o(mem_cmd_v)
  ,.mem_cmd_yumi_i(mem_cmd_yumi)

  ,.mem_data_cmd_o(mem_data_cmd)
  ,.mem_data_cmd_v_o(mem_data_cmd_v)
  ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi)
);

// DRAM
bp_mem_dramsim2
#(.mem_id_p(0)
   ,.clock_period_in_ps_p(clock_period_in_ps_p)
   ,.prog_name_p(prog_name_p)
   ,.dram_cfg_p(dram_cfg_p)
   ,.dram_sys_cfg_p(dram_sys_cfg_p)
   ,.dram_capacity_p(dram_capacity_p)
   ,.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.block_size_in_bytes_p(cce_block_width_p/8)
   ,.lce_sets_p(lce_sets_p)
   ,.lce_req_data_width_p(dword_width_p)
  )
mem
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(mem_cmd)
  ,.mem_cmd_v_i(mem_cmd_v)
  ,.mem_cmd_yumi_o(mem_cmd_yumi)

  ,.mem_data_cmd_i(mem_data_cmd)
  ,.mem_data_cmd_v_i(mem_data_cmd_v)
  ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi)

  ,.mem_resp_o(mem_resp)
  ,.mem_resp_v_o(mem_resp_v)
  ,.mem_resp_ready_i(mem_resp_ready)

  ,.mem_data_resp_o(mem_data_resp)
  ,.mem_data_resp_v_o(mem_data_resp_v)
  ,.mem_data_resp_ready_i(mem_data_resp_ready)
  );


endmodule : testbench


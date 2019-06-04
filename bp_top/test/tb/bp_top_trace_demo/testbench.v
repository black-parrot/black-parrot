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
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Number of elements in the fake BlackParrot memory
   , parameter clock_period_in_ps_p = 1000
   , parameter prog_name_p = "prog.mem"
   , parameter dram_cfg_p  = "dram_ch.ini"
   , parameter dram_sys_cfg_p = "dram_sys.ini"
   , parameter dram_capacity_p = 16384

   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

   // Trace replay parameters
   , parameter calc_trace_p                = 0
   , parameter cce_trace_p                 = 0
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   , localparam trace_rom_data_width_lp    = trace_ring_width_p + 4
   
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   
   , localparam noc_x_cord_width_lp = `BSG_SAFE_CLOG2(num_core_p)
   , localparam noc_y_cord_width_lp = 1
   
   )
  (input clk_i
   , input reset_i
   );

localparam clint_x_cord_lp = (num_core_p/2)-1;
localparam clint_y_cord_lp = 1;
localparam dram_x_cord_lp  = (num_core_p/2);
localparam dram_y_cord_lp  = 1;
   
`declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)     

bsg_ready_and_link_sif_s [1:0] ct_link_li, ct_link_lo;
bsg_ready_and_link_sif_s mem_link_li, mem_link_lo;
bsg_ready_and_link_sif_s cfg_link_li, cfg_link_lo;

assign ct_link_li = {cfg_link_lo, mem_link_lo};
assign {cfg_link_li, mem_link_li} = ct_link_lo;
   
logic [noc_width_p-1:0] multi_data_li, multi_data_lo;
logic multi_v_li, multi_v_lo;
logic multi_ready_lo, multi_yumi_li;
     
bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;
bp_mem_cce_data_resp_s mem_data_resp_li;
logic                  mem_data_resp_v_li, mem_data_resp_ready_lo;
bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;
bp_cce_mem_data_cmd_s  mem_data_cmd_lo;
logic                  mem_data_cmd_v_lo, mem_data_cmd_yumi_li;

bp_cce_mem_data_cmd_s  cfg_data_cmd_lo;
logic                  cfg_data_cmd_v_lo, cfg_data_cmd_yumi_li;
bp_mem_cce_resp_s      cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

// Chip
wrapper
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   ,.cce_trace_p(cce_trace_p)
   )
 wrapper
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.multi_data_i(multi_data_li)
   ,.multi_v_i(multi_v_li)
   ,.multi_ready_o(multi_ready_lo)

   ,.multi_data_o(multi_data_lo)
   ,.multi_v_o(multi_v_lo)
   ,.multi_yumi_i(multi_yumi_li & multi_v_lo)
   );
   
bsg_channel_tunnel_wormhole
 #(.width_p(noc_width_p)
   ,.x_cord_width_p(noc_x_cord_width_lp)
   ,.y_cord_width_p(noc_y_cord_width_lp)
   ,.len_width_p(4)
   ,.reserved_width_p(2)
   ,.num_in_p(2)
   ,.remote_credits_p(16)
   ,.max_payload_flits_p(8)
   ,.lg_credit_decimation_p(2)
  )
 channel_tunnel
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.multi_data_i(multi_data_lo)
   ,.multi_v_i(multi_v_lo)
   ,.multi_ready_o(multi_yumi_li)
   
   ,.multi_data_o(multi_data_li)
   ,.multi_v_o(multi_v_li)
   ,.multi_yumi_i(multi_ready_lo & multi_v_li)
   
   ,.link_i(ct_link_li)
   ,.link_o(ct_link_lo)
   );

bind bp_be_top
  bp_be_nonsynth_tracer
   #(.cfg_p(cfg_p))
   tracer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mhartid_i(be_calculator.proc_cfg.core_id)

     ,.issue_pkt_i(be_calculator.issue_pkt)
     ,.issue_pkt_v_i(be_calculator.issue_pkt_v_i)

     ,.fe_nop_v_i(be_calculator.fe_nop_v)
     ,.be_nop_v_i(be_calculator.be_nop_v)
     ,.me_nop_v_i(be_calculator.me_nop_v)
     ,.dispatch_pkt_i(be_calculator.dispatch_pkt)

     ,.ex1_br_tgt_i(be_calculator.calc_status.int1_br_tgt)
     ,.ex1_btaken_i(be_calculator.calc_status.int1_btaken)
     ,.iwb_result_i(be_calculator.comp_stage_n[3])
     ,.fwb_result_i(be_calculator.comp_stage_n[4])

     ,.cmt_trace_exc_i(be_calculator.exc_stage_n[1+:5])

     ,.trap_v_i(be_mem.csr.trap_v_o)
     ,.mtvec_i(be_mem.csr.mtvec_n)
     ,.mtval_i(be_mem.csr.mtval_n)
     ,.ret_v_i(be_mem.csr.ret_v_o)
     ,.mepc_i(be_mem.csr.mepc_n)
     ,.mcause_i(be_mem.csr.mcause_n)

     ,.priv_mode_i(be_mem.csr.priv_mode_n)
     ,.mpp_i(be_mem.csr.mstatus_n.mpp)
     );

bind bp_be_top
  bp_be_nonsynth_perf
   #(.cfg_p(cfg_p))
   perf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fe_nop_i(be_calculator.exc_stage_r[2].fe_nop_v)
     ,.be_nop_i(be_calculator.exc_stage_r[2].be_nop_v)
     ,.me_nop_i(be_calculator.exc_stage_r[2].me_nop_v)
     ,.poison_i(be_calculator.exc_stage_r[2].poison_v)
     ,.roll_i(be_calculator.exc_stage_r[2].roll_v)
     ,.instr_cmt_i(be_calculator.calc_status.instr_cmt_v)

     ,.program_pass_i(be_mem.csr.program_pass)
     ,.program_fail_i(be_mem.csr.program_fail)
     );

// DRAM + link 
bp_me_cce_to_wormhole_link_client
 #(.num_lce_p(num_lce_p)
  ,.paddr_width_p(paddr_width_p)
  ,.lce_assoc_p(lce_assoc_p)
  ,.block_size_in_bytes_p(cce_block_width_p/8)
  ,.lce_req_data_width_p(dword_width_p)
  ,.width_p(noc_width_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  ,.len_width_p(4)
  ,.reserved_width_p(2))
  client_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_o(mem_cmd_lo)
  ,.mem_cmd_v_o(mem_cmd_v_lo)
  ,.mem_cmd_yumi_i(mem_cmd_yumi_li)

  ,.mem_data_cmd_o(mem_data_cmd_lo)
  ,.mem_data_cmd_v_o(mem_data_cmd_v_lo)
  ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li)

  ,.mem_resp_i(mem_resp_li)
  ,.mem_resp_v_i(mem_resp_v_li)
  ,.mem_resp_ready_o(mem_resp_ready_lo)

  ,.mem_data_resp_i(mem_data_resp_li)
  ,.mem_data_resp_v_i(mem_data_resp_v_li)
  ,.mem_data_resp_ready_o(mem_data_resp_ready_lo)
  
  ,.my_x_i(noc_x_cord_width_lp'(dram_x_cord_lp))
  ,.my_y_i(noc_y_cord_width_lp'(dram_y_cord_lp))
  
  ,.link_i(mem_link_li)
  ,.link_o(mem_link_lo)
  );

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

  ,.mem_cmd_i(mem_cmd_lo)
  ,.mem_cmd_v_i(mem_cmd_v_lo)
  ,.mem_cmd_yumi_o(mem_cmd_yumi_li)

  ,.mem_data_cmd_i(mem_data_cmd_lo)
  ,.mem_data_cmd_v_i(mem_data_cmd_v_lo)
  ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_li)

  ,.mem_resp_o(mem_resp_li)
  ,.mem_resp_v_o(mem_resp_v_li)
  ,.mem_resp_ready_i(mem_resp_ready_lo)

  ,.mem_data_resp_o(mem_data_resp_li)
  ,.mem_data_resp_v_o(mem_data_resp_v_li)
  ,.mem_data_resp_ready_i(mem_data_resp_ready_lo)
  );

// CFG loader + rom + link
bp_me_cce_to_wormhole_link_master
 #(.num_lce_p(num_lce_p)
  ,.paddr_width_p(paddr_width_p)
  ,.lce_assoc_p(lce_assoc_p)
  ,.block_size_in_bytes_p(cce_block_width_p/8)
  ,.lce_req_data_width_p(dword_width_p)
  ,.width_p(noc_width_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  ,.len_width_p(4)
  ,.reserved_width_p(2))
  master_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i('0)
  ,.mem_cmd_v_i('0)
  ,.mem_cmd_yumi_o()

  ,.mem_data_cmd_i(cfg_data_cmd_lo)
  ,.mem_data_cmd_v_i(cfg_data_cmd_v_lo)
  ,.mem_data_cmd_yumi_o(cfg_data_cmd_yumi_li)

  ,.mem_resp_o(cfg_resp_li)
  ,.mem_resp_v_o(cfg_resp_v_li)
  ,.mem_resp_ready_i(cfg_resp_ready_lo)

  ,.mem_data_resp_o()
  ,.mem_data_resp_v_o()
  ,.mem_data_resp_ready_i(1'b1)
  
  ,.my_x_i(noc_x_cord_width_lp'(dram_x_cord_lp))
  ,.my_y_i(noc_y_cord_width_lp'(dram_y_cord_lp))
  
  ,.mem_cmd_dest_x_i(noc_x_cord_width_lp'(0))
  ,.mem_cmd_dest_y_i(noc_y_cord_width_lp'(0))
  ,.mem_data_cmd_dest_x_i(noc_x_cord_width_lp'(clint_x_cord_lp))
  ,.mem_data_cmd_dest_y_i(noc_y_cord_width_lp'(clint_y_cord_lp))
  
  ,.link_i(cfg_link_li)
  ,.link_o(cfg_link_lo)
  );

bp_cce_mmio_cfg_loader
  #(.cfg_p(cfg_p)
    ,.inst_width_p(`bp_cce_inst_width)
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p('0)
  )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.mem_data_cmd_o(cfg_data_cmd_lo)
   ,.mem_data_cmd_v_o(cfg_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_i(cfg_data_cmd_yumi_li)
   
   ,.mem_resp_i(cfg_resp_li)
   ,.mem_resp_v_i(cfg_resp_v_li)
   ,.mem_resp_ready_o(cfg_resp_ready_lo)
  );

endmodule : testbench


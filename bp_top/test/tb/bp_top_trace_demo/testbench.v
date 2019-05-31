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
   
   , parameter width_p = 64
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)
   
   , localparam noc_x_cord_width_lp = `BSG_SAFE_CLOG2(num_cce_p)
   , localparam noc_y_cord_width_lp = 1
   
   )
  (input clk_i
   , input reset_i
   );

// Config link
logic [num_cce_p-1:0][cce_instr_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]          cce_inst_boot_rom_data;

logic [bsg_ready_and_link_sif_width_lp-1:0] noc_link_li;
logic [bsg_ready_and_link_sif_width_lp-1:0] noc_link_lo;

   wrapper
    #(.cfg_p(cfg_p)
      ,.calc_trace_p(calc_trace_p)
      ,.cce_trace_p(cce_trace_p)
      ,.width_p(width_p)
      )
    wrapper
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.link_i(noc_link_li)
      ,.link_o(noc_link_lo)

      ,.external_irq_i('0)
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


`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)     
     
bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;

bp_mem_cce_data_resp_s mem_data_resp_li;
logic                  mem_data_resp_v_li, mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;

bp_cce_mem_data_cmd_s  mem_data_cmd_lo;
logic                  mem_data_cmd_v_lo, mem_data_cmd_yumi_li;

     
bp_me_cce_to_wormhole_link_client
 #(.num_lce_p(num_lce_p)
  ,.paddr_width_p(paddr_width_p)
  ,.lce_assoc_p(lce_assoc_p)
  ,.block_size_in_bytes_p(cce_block_width_p/8)
  ,.lce_req_data_width_p(dword_width_p)
  ,.width_p(width_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  ,.len_width_p(4)
  ,.reserved_width_p(2))
  wh_mem_link_client
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
  
  ,.my_x_i(noc_x_cord_width_lp'(0))
  ,.my_y_i(noc_y_cord_width_lp'(1))
  
  ,.link_i(noc_link_lo)
  ,.link_o(noc_link_li)
  );
     
/*
bp_mem_wormhole_dramsim2
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
   
   ,.width_p(width_p)
   ,.x_cord_width_p(noc_x_cord_width_lp)
   ,.y_cord_width_p(noc_y_cord_width_lp)
   ,.len_width_p(4)
   ,.reserved_width_p(2)
   )
 mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.link_i(noc_link_lo)
   ,.link_o(noc_link_li)
   );
*/


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
     
     
for (genvar i = 0; i < num_cce_p; i++) 
  begin : rof1
    bp_cce_nonsynth_cfg_loader
      #(.inst_width_p(`bp_cce_inst_width)
        ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
        ,.inst_ram_els_p(num_cce_instr_ram_els_p)
        ,.cfg_link_addr_width_p(bp_cfg_link_addr_width_gp)
        ,.cfg_link_data_width_p(bp_cfg_link_data_width_gp)
        ,.skip_ram_init_p('0)
      )
      cce_inst_ram_loader
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.freeze_o()
       ,.boot_rom_addr_o(cce_inst_boot_rom_addr[i])
       ,.boot_rom_data_i(cce_inst_boot_rom_data[i])
      );

    bp_cce_inst_rom
     #(.width_p(`bp_cce_inst_width)
       ,.addr_width_p(cce_instr_ram_addr_width_lp)
       )
     cce_inst_rom
      (.addr_i(cce_inst_boot_rom_addr[i])
       ,.data_o(cce_inst_boot_rom_data[i])
       );
end // rof1

endmodule : testbench


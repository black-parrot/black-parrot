/**
 *  bp_me_nonsynth_top_test.v
 */

`include "bp_be_dcache_pkt.vh"

module bp_me_nonsynth_top_test
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    , parameter mem_els_p="inv"
    , parameter boot_rom_els_p="inv"
    , parameter cce_trace_p = 0
    , parameter axe_trace_p = 0

    , localparam block_size_in_bytes_lp=(cce_block_width_p / 8)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
    , localparam mshr_width_lp=`bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

    // dramsim2 stuff
    , parameter dramsim2_en_p = 0
    , parameter clock_period_in_ps_p = 1000
    , parameter prog_name_p = "null.mem"
    , parameter dram_cfg_p  = "DDR2_micron_16M_8b_x8_sg3E.ini"
    , parameter dram_sys_cfg_p = "system.ini"
    , parameter dram_capacity_p = 16384
  )
  (
    input clk_i
    , input reset_i

    , input [num_lce_p-1:0][tr_ring_width_lp-1:0] tr_pkt_i
    , input [num_lce_p-1:0] tr_pkt_v_i
    , output logic [num_lce_p-1:0] tr_pkt_yumi_o

    , input [num_lce_p-1:0] tr_pkt_ready_i
    , output logic [num_lce_p-1:0] tr_pkt_v_o
    , output logic [num_lce_p-1:0][tr_ring_width_lp-1:0] tr_pkt_o
  );

  // Memory End
  //
  `declare_bp_me_if(paddr_width_p,cce_block_width_p,num_lce_p,lce_assoc_p,mshr_width_lp);

  // Config link
  logic [num_cce_p-1:0]                                  freeze_li;
  logic [num_cce_p-1:0][cfg_addr_width_p-1:0]   config_addr_li;
  logic [num_cce_p-1:0][cfg_data_width_p-1:0]   config_data_li;
  logic [num_cce_p-1:0]                                  config_v_li;
  logic [num_cce_p-1:0]                                  config_w_li;
  logic [num_cce_p-1:0]                                  config_ready_lo;

  logic [num_cce_p-1:0][cfg_data_width_p-1:0]   config_data_lo;
  logic [num_cce_p-1:0]                                  config_v_lo;
  logic [num_cce_p-1:0]                                  config_ready_li;

  bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp;
  logic [num_cce_p-1:0] mem_resp_v;
  logic [num_cce_p-1:0] mem_resp_ready;

  bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp;
  logic [num_cce_p-1:0] mem_data_resp_v;
  logic [num_cce_p-1:0] mem_data_resp_ready;

  bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd;
  logic [num_cce_p-1:0] mem_cmd_v;
  logic [num_cce_p-1:0] mem_cmd_yumi;

  bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd;
  logic [num_cce_p-1:0] mem_data_cmd_v;
  logic [num_cce_p-1:0] mem_data_cmd_yumi;

  bp_me_nonsynth_top #(
    .cfg_p(cfg_p)
    ,.trace_p(0)
    ,.calc_debug_p(0)
    ,.cce_trace_p(cce_trace_p)
    ,.axe_trace_p(axe_trace_p)
  ) me_top (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.freeze_i(freeze_li)

    ,.cfg_addr_i(config_addr_li)
    ,.cfg_data_i(config_data_li)
    ,.cfg_w_v_i(config_v_li)

    ,.tr_pkt_i(tr_pkt_i)
    ,.tr_pkt_v_i(tr_pkt_v_i)
    ,.tr_pkt_yumi_o(tr_pkt_yumi_o)

    ,.tr_pkt_v_o(tr_pkt_v_o)
    ,.tr_pkt_o(tr_pkt_o)
    ,.tr_pkt_ready_i(tr_pkt_ready_i)

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

for (genvar i = 0; i < num_cce_p; i++)
  begin 
   bp_mem_dramsim2
   #(.mem_id_p('0)
     ,.clock_period_in_ps_p(clock_period_in_ps_p)
     ,.prog_name_p(prog_name_p)
     ,.dram_cfg_p(dram_cfg_p)
     ,.dram_sys_cfg_p(dram_sys_cfg_p)
     ,.dram_capacity_p(dram_capacity_p)
     ,.num_lce_p(num_lce_p)
     ,.num_cce_p(num_cce_p)
     ,.paddr_width_p(paddr_width_p)
     ,.lce_assoc_p(lce_assoc_p)
     ,.block_size_in_bytes_p(block_size_in_bytes_lp)
     ,.lce_sets_p(lce_sets_p)
     ,.lce_req_data_width_p(dword_width_p)
     )
   mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(mem_cmd[i])
     ,.mem_cmd_v_i(mem_cmd_v[i])
     ,.mem_cmd_yumi_o(mem_cmd_yumi[i])

     ,.mem_data_cmd_i(mem_data_cmd[i])
     ,.mem_data_cmd_v_i(mem_data_cmd_v[i])
     ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi[i])

     ,.mem_resp_o(mem_resp[i])
     ,.mem_resp_v_o(mem_resp_v[i])
     ,.mem_resp_ready_i(mem_resp_ready[i])

     ,.mem_data_resp_o(mem_data_resp[i])
     ,.mem_data_resp_v_o(mem_data_resp_v[i])
     ,.mem_data_resp_ready_i(mem_data_resp_ready[i])
     );

    // We use the clint just as a config loader converter
  bp_clint
  #(.cfg_p(cfg_p))
  clint
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_cmd_i('0)
    ,.mem_cmd_v_i(1'b0)
    ,.mem_cmd_yumi_o()

    ,.mem_data_cmd_i(cfg_data_cmd_lo[i])
    ,.mem_data_cmd_v_i(cfg_data_cmd_v_lo[i])
    ,.mem_data_cmd_yumi_o(cfg_data_cmd_yumi_li[i])

    ,.mem_resp_o(cfg_resp_li[i])
    ,.mem_resp_v_o(cfg_resp_v_li[i])
    ,.mem_resp_ready_i(cfg_resp_ready_lo[i])

    ,.mem_data_resp_o()
    ,.mem_data_resp_v_o()
    ,.mem_data_resp_ready_i(1'b0)

    ,.soft_irq_o()
    ,.timer_irq_o()
    ,.external_irq_o()

    ,.cfg_link_w_v_o(config_v_li[i])
    ,.cfg_link_addr_o(config_addr_li[i])
    ,.cfg_link_data_o(config_data_li[i])
    );
  end


endmodule

/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_core
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
  )
 (input                                          clk_i
  , input                                        reset_i

  , input [cfg_bus_width_lp-1:0]                 cfg_bus_i

  // LCE-CCE interface
  , output [1:0][lce_req_msg_width_lp-1:0]       lce_req_o
  , output [1:0]                                 lce_req_v_o
  , input [1:0]                                  lce_req_ready_i

  , output [1:0][lce_resp_msg_width_lp-1:0]      lce_resp_o
  , output [1:0]                                 lce_resp_v_o
  , input [1:0]                                  lce_resp_ready_i

  // CCE-LCE interface
  , input [1:0][lce_cmd_msg_width_lp-1:0]        lce_cmd_i
  , input [1:0]                                  lce_cmd_v_i
  , output [1:0]                                 lce_cmd_yumi_o

  , output [1:0][lce_cmd_msg_width_lp-1:0]       lce_cmd_o
  , output [1:0]                                 lce_cmd_v_o
  , input [1:0]                                  lce_cmd_ready_i

  , input                                        timer_irq_i
  , input                                        software_irq_i
  , input                                        external_irq_i
  );

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);

  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  bp_icache_req_s icache_req_lo;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_busy_li;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic icache_req_metadata_v_lo;
  logic icache_req_critical_li, icache_req_complete_li;
  logic icache_req_credits_full_li, icache_req_credits_empty_li;

  bp_dcache_req_s dcache_req_lo;
  logic dcache_req_v_lo, dcache_req_yumi_li, dcache_req_busy_li;
  bp_dcache_req_metadata_s dcache_req_metadata_lo;
  logic dcache_req_metadata_v_lo;
  logic dcache_req_critical_li, dcache_req_complete_li;
  logic dcache_req_credits_full_li, dcache_req_credits_empty_li;

  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic icache_tag_mem_pkt_v_li;
  logic icache_tag_mem_pkt_yumi_lo;
  bp_icache_tag_info_s icache_tag_mem_lo;

  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic icache_data_mem_pkt_v_li;
  logic icache_data_mem_pkt_yumi_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic icache_stat_mem_pkt_v_li;
  logic icache_stat_mem_pkt_yumi_lo;
  bp_icache_stat_info_s icache_stat_mem_lo;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li;
  logic dcache_tag_mem_pkt_yumi_lo;
  bp_dcache_tag_info_s dcache_tag_mem_lo;

  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li;
  logic dcache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;

  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li;
  logic dcache_stat_mem_pkt_yumi_lo;
  bp_dcache_stat_info_s dcache_stat_mem_lo;

  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core_minimal
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_cast_i)

     ,.icache_req_o(icache_req_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_yumi_i(icache_req_yumi_li)
     ,.icache_req_busy_i(icache_req_busy_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.icache_req_complete_i(icache_req_complete_li)
     ,.icache_req_critical_i(icache_req_critical_li)
     ,.icache_req_credits_full_i(icache_req_credits_full_li)
     ,.icache_req_credits_empty_i(icache_req_credits_empty_li)

     ,.icache_tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.icache_tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.icache_tag_mem_pkt_yumi_o(icache_tag_mem_pkt_yumi_lo)
     ,.icache_tag_mem_o(icache_tag_mem_lo)

     ,.icache_data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.icache_data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.icache_data_mem_pkt_yumi_o(icache_data_mem_pkt_yumi_lo)
     ,.icache_data_mem_o(icache_data_mem_lo)

     ,.icache_stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.icache_stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.icache_stat_mem_pkt_yumi_o(icache_stat_mem_pkt_yumi_lo)
     ,.icache_stat_mem_o(icache_stat_mem_lo)

     ,.dcache_req_o(dcache_req_lo)
     ,.dcache_req_v_o(dcache_req_v_lo)
     ,.dcache_req_yumi_i(dcache_req_yumi_li)
     ,.dcache_req_busy_i(dcache_req_busy_li)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)
     ,.dcache_req_complete_i(dcache_req_complete_li)
     ,.dcache_req_critical_i(dcache_req_critical_li)
     ,.dcache_req_credits_full_i(dcache_req_credits_full_li)
     ,.dcache_req_credits_empty_i(dcache_req_credits_empty_li)

     ,.dcache_tag_mem_pkt_i(dcache_tag_mem_pkt_li)
     ,.dcache_tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_li)
     ,.dcache_tag_mem_pkt_yumi_o(dcache_tag_mem_pkt_yumi_lo)
     ,.dcache_tag_mem_o(dcache_tag_mem_lo)

     ,.dcache_data_mem_pkt_i(dcache_data_mem_pkt_li)
     ,.dcache_data_mem_pkt_v_i(dcache_data_mem_pkt_v_li)
     ,.dcache_data_mem_pkt_yumi_o(dcache_data_mem_pkt_yumi_lo)
     ,.dcache_data_mem_o(dcache_data_mem_lo)

     ,.dcache_stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_li)
     ,.dcache_stat_mem_pkt_i(dcache_stat_mem_pkt_li)
     ,.dcache_stat_mem_pkt_yumi_o(dcache_stat_mem_pkt_yumi_lo)
     ,.dcache_stat_mem_o(dcache_stat_mem_lo)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     );

  bp_lce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     ,.timeout_max_limit_p(4)
     ,.credits_p(coh_noc_max_credits_p)
     ,.non_excl_reads_p(1)
     ,.metadata_latency_p(1)
     )
   fe_lce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(cfg_bus_cast_i.icache_id)
     ,.lce_mode_i(cfg_bus_cast_i.icache_mode)

     ,.cache_req_i(icache_req_lo)
     ,.cache_req_v_i(icache_req_v_lo)
     ,.cache_req_yumi_o(icache_req_yumi_li)
     ,.cache_req_busy_o(icache_req_busy_li)
     ,.cache_req_metadata_i(icache_req_metadata_lo)
     ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
     ,.cache_req_critical_o(icache_req_critical_li)
     ,.cache_req_complete_o(icache_req_complete_li)
     ,.cache_req_credits_full_o(icache_req_credits_full_li)
     ,.cache_req_credits_empty_o(icache_req_credits_empty_li)

     ,.tag_mem_pkt_o(icache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_i(icache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_i(icache_tag_mem_lo)

     ,.data_mem_pkt_o(icache_data_mem_pkt_li)
     ,.data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_i(icache_data_mem_pkt_yumi_lo)
     ,.data_mem_i(icache_data_mem_lo)

     ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
     ,.stat_mem_pkt_yumi_i(icache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(icache_stat_mem_lo)

     ,.lce_req_o(lce_req_o[0])
     ,.lce_req_v_o(lce_req_v_o[0])
     ,.lce_req_ready_i(lce_req_ready_i[0])

     ,.lce_resp_o(lce_resp_o[0])
     ,.lce_resp_v_o(lce_resp_v_o[0])
     ,.lce_resp_ready_i(lce_resp_ready_i[0])

     ,.lce_cmd_i(lce_cmd_i[0])
     ,.lce_cmd_v_i(lce_cmd_v_i[0])
     ,.lce_cmd_yumi_o(lce_cmd_yumi_o[0])

     ,.lce_cmd_o(lce_cmd_o[0])
     ,.lce_cmd_v_o(lce_cmd_v_o[0])
     ,.lce_cmd_ready_i(lce_cmd_ready_i[0])
     );

  bp_lce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p)
     ,.fill_width_p(dcache_fill_width_p)
     ,.timeout_max_limit_p(4)
     ,.credits_p(coh_noc_max_credits_p)
     ,.data_mem_invert_clk_p(1)
     ,.tag_mem_invert_clk_p(1)
     ,.metadata_latency_p(1)
     )
   be_lce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(cfg_bus_cast_i.dcache_id)
     ,.lce_mode_i(cfg_bus_cast_i.dcache_mode)

     ,.cache_req_i(dcache_req_lo)
     ,.cache_req_v_i(dcache_req_v_lo)
     ,.cache_req_yumi_o(dcache_req_yumi_li)
     ,.cache_req_busy_o(dcache_req_busy_li)
     ,.cache_req_metadata_i(dcache_req_metadata_lo)
     ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
     ,.cache_req_critical_o(dcache_req_critical_li)
     ,.cache_req_complete_o(dcache_req_complete_li)
     ,.cache_req_credits_full_o(dcache_req_credits_full_li)
     ,.cache_req_credits_empty_o(dcache_req_credits_empty_li)

     ,.tag_mem_pkt_o(dcache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_i(dcache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_i(dcache_tag_mem_lo)

     ,.data_mem_pkt_o(dcache_data_mem_pkt_li)
     ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_i(dcache_data_mem_pkt_yumi_lo)
     ,.data_mem_i(dcache_data_mem_lo)

     ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
     ,.stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(dcache_stat_mem_lo)

     ,.lce_req_o(lce_req_o[1])
     ,.lce_req_v_o(lce_req_v_o[1])
     ,.lce_req_ready_i(lce_req_ready_i[1])

     ,.lce_resp_o(lce_resp_o[1])
     ,.lce_resp_v_o(lce_resp_v_o[1])
     ,.lce_resp_ready_i(lce_resp_ready_i[1])

     ,.lce_cmd_i(lce_cmd_i[1])
     ,.lce_cmd_v_i(lce_cmd_v_i[1])
     ,.lce_cmd_yumi_o(lce_cmd_yumi_o[1])

     ,.lce_cmd_o(lce_cmd_o[1])
     ,.lce_cmd_v_o(lce_cmd_v_o[1])
     ,.lce_cmd_ready_i(lce_cmd_ready_i[1])
     );

endmodule


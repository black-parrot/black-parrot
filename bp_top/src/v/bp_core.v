/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

module bp_core
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache)
    `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    , localparam way_id_width_lp = `BSG_SAFE_CLOG2(lce_assoc_p)

    , localparam icache_stat_info_width_lp = `bp_cache_stat_info_width(icache_assoc_p)
    , localparam dcache_stat_info_width_lp = `bp_cache_stat_info_width(dcache_assoc_p)
   )
   (
    input                                          clk_i
    , input                                        reset_i

    , input [cfg_bus_width_lp-1:0]                 cfg_bus_i
    , output [vaddr_width_p-1:0]                   cfg_npc_data_o
    , output [dword_width_p-1:0]                   cfg_irf_data_o
    , output [dword_width_p-1:0]                   cfg_csr_data_o
    , output [1:0]                                 cfg_priv_data_o

    // LCE-CCE interface
    , output [1:0][lce_cce_req_width_lp-1:0]       lce_req_o
    , output [1:0]                                 lce_req_v_o
    , input [1:0]                                  lce_req_ready_i

    , output [1:0][lce_cce_resp_width_lp-1:0]      lce_resp_o
    , output [1:0]                                 lce_resp_v_o
    , input [1:0]                                  lce_resp_ready_i

    // CCE-LCE interface
    , input [1:0][lce_cmd_width_lp-1:0]            lce_cmd_i
    , input [1:0]                                  lce_cmd_v_i
    , output [1:0]                                 lce_cmd_yumi_o

    , output [1:0][lce_cmd_width_lp-1:0]           lce_cmd_o
    , output [1:0]                                 lce_cmd_v_o
    , input [1:0]                                  lce_cmd_ready_i

    , input                                        timer_irq_i
    , input                                        software_irq_i
    , input                                        external_irq_i
    );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);

  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  bp_icache_req_s icache_req_cast_lo;
  logic icache_req_ready_li, icache_req_v_lo;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic icache_req_metadata_v_lo;

  bp_dcache_req_s dcache_req_cast_lo;
  logic dcache_req_ready_li, dcache_req_v_lo;
  bp_dcache_req_metadata_s dcache_req_metadata_lo;
  logic dcache_req_metadata_v_lo;

  logic icache_req_complete_lo, dcache_req_complete_lo;
  logic credits_full_lo, credits_empty_lo;

  logic [1:0] lr_hit_lo;
  logic [1:0] cache_v_lo;

  // response side - Interface from I$ LCE
  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic icache_data_mem_pkt_v_li;
  logic icache_data_mem_pkt_ready_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic icache_tag_mem_pkt_v_li;
  logic icache_tag_mem_pkt_ready_lo;
  logic [ptag_width_p-1:0] icache_tag_mem_lo;

  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic icache_stat_mem_pkt_v_li;
  logic icache_stat_mem_pkt_ready_lo;
  logic [icache_stat_info_width_lp-1:0] icache_stat_mem_lo;

  // response side - Interface from D$ LCE
  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li;
  logic dcache_data_mem_pkt_ready_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li;
  logic dcache_tag_mem_pkt_ready_lo;
  logic [ptag_width_p-1:0] dcache_tag_mem_lo;

  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li;
  logic dcache_stat_mem_pkt_ready_lo;
  logic [dcache_stat_info_width_lp-1:0] dcache_stat_mem_lo;

  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core_minimal
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // Config info
     ,.cfg_bus_i(cfg_bus_i)
     ,.cfg_npc_data_o(cfg_npc_data_o)
     ,.cfg_irf_data_o(cfg_irf_data_o)
     ,.cfg_csr_data_o(cfg_csr_data_o)
     ,.cfg_priv_data_o(cfg_priv_data_o)

     // BP request side - Interface to LCE
     ,.credits_full_i(credits_full_lo)
     ,.credits_empty_i(credits_empty_lo)

     ,.dcache_req_o(dcache_req_cast_lo)
     ,.dcache_req_v_o(dcache_req_v_lo)
     ,.dcache_req_ready_i(dcache_req_ready_li)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)

     ,.dcache_req_complete_i(dcache_req_complete_lo)

     ,.icache_req_o(icache_req_cast_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_ready_i(icache_req_ready_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)

     ,.icache_req_complete_i(icache_req_complete_lo)

     // response side - Interface from D$ LCE
     ,.dcache_data_mem_pkt_i(dcache_data_mem_pkt_li)
     ,.dcache_data_mem_pkt_v_i(dcache_data_mem_pkt_v_li)
     ,.dcache_data_mem_pkt_ready_o(dcache_data_mem_pkt_ready_lo)
     ,.dcache_data_mem_o(dcache_data_mem_lo)

     ,.dcache_tag_mem_pkt_i(dcache_tag_mem_pkt_li)
     ,.dcache_tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_li)
     ,.dcache_tag_mem_pkt_ready_o(dcache_tag_mem_pkt_ready_lo)
     ,.dcache_tag_mem_o(dcache_tag_mem_lo)

     ,.dcache_stat_mem_pkt_i(dcache_stat_mem_pkt_li)
     ,.dcache_stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_li)
     ,.dcache_stat_mem_pkt_ready_o(dcache_stat_mem_pkt_ready_lo)
     ,.dcache_stat_mem_o(dcache_stat_mem_lo)

     // response side - Interface from I$ LCE
     ,.icache_data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.icache_data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.icache_data_mem_pkt_ready_o(icache_data_mem_pkt_ready_lo)
     ,.icache_data_mem_o(icache_data_mem_lo)

     ,.icache_tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.icache_tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.icache_tag_mem_pkt_ready_o(icache_tag_mem_pkt_ready_lo)
     ,.icache_tag_mem_o(icache_tag_mem_lo)

     ,.icache_stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.icache_stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.icache_stat_mem_pkt_ready_o(icache_stat_mem_pkt_ready_lo)
     ,.icache_stat_mem_o(icache_stat_mem_lo)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)

     );

  bp_fe_lce
    #(.bp_params_p(bp_params_p))
  fe_lce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.cache_req_i(icache_req_cast_lo)
     ,.cache_req_v_i(icache_req_v_lo)
     ,.cache_req_ready_o(icache_req_ready_li)
     ,.cache_req_metadata_i(icache_req_metadata_lo)
     ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
     ,.cache_req_complete_o(icache_req_complete_lo)

     ,.data_mem_pkt_o(icache_data_mem_pkt_li)
     ,.data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
     ,.data_mem_pkt_ready_i(icache_data_mem_pkt_ready_lo)
     ,.data_mem_i(icache_data_mem_lo)

     ,.tag_mem_pkt_o(icache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_ready_i(icache_tag_mem_pkt_ready_lo)
     ,.tag_mem_i(icache_tag_mem_lo)

     ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
     ,.stat_mem_pkt_ready_i(icache_stat_mem_pkt_ready_lo)
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

  bp_be_dcache_lce
    #(.bp_params_p(bp_params_p))
  be_lce
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(cfg_bus_cast_i.dcache_id)

     ,.cache_req_i(dcache_req_cast_lo)
    ,.cache_req_v_i(dcache_req_v_lo)
    ,.cache_req_ready_o(dcache_req_ready_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lo)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)

    ,.cache_req_complete_o(dcache_req_complete_lo)

    ,.data_mem_pkt_o(dcache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
    ,.data_mem_pkt_ready_i(dcache_data_mem_pkt_ready_lo)
    ,.data_mem_i(dcache_data_mem_lo)

    ,.tag_mem_pkt_o(dcache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_ready_i(dcache_tag_mem_pkt_ready_lo)
    ,.tag_mem_i(dcache_tag_mem_lo)

    ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
    ,.stat_mem_pkt_ready_i(dcache_stat_mem_pkt_ready_lo)
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

    ,.credits_full_o(credits_full_lo)
    ,.credits_empty_o(credits_empty_lo)
    );

endmodule


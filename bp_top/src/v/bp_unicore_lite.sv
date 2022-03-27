
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_unicore_lite
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   // Outgoing BP Stream Mem Buses from I$ and D$
   , output logic [1:0][mem_header_width_lp-1:0]       mem_cmd_header_o
   , output logic [1:0][uce_fill_width_p-1:0]          mem_cmd_data_o
   , output logic [1:0]                                mem_cmd_v_o
   , input [1:0]                                       mem_cmd_ready_and_i
   , output logic [1:0]                                mem_cmd_last_o

   , input [1:0][mem_header_width_lp-1:0]              mem_resp_header_i
   , input [1:0][uce_fill_width_p-1:0]                 mem_resp_data_i
   , input [1:0]                                       mem_resp_v_i
   , output logic [1:0]                                mem_resp_ready_and_o
   , input [1:0]                                       mem_resp_last_i

   , input                                             unfreeze_irq_i
   , input                                             debug_irq_i
   , input                                             timer_irq_i
   , input                                             software_irq_i
   , input                                             m_external_irq_i
   , input                                             s_external_irq_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  bp_icache_req_s icache_req_lo;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_busy_li, icache_req_metadata_v_lo;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic icache_req_critical_tag_li, icache_req_critical_data_li, icache_req_complete_li;
  logic icache_req_credits_full_li, icache_req_credits_empty_li;

  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_yumi_lo;
  bp_icache_tag_info_s icache_tag_mem_lo;
  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_yumi_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;
  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_yumi_lo;
  bp_icache_stat_info_s icache_stat_mem_lo;

  bp_dcache_req_s dcache_req_lo;
  logic dcache_req_v_lo, dcache_req_yumi_li, dcache_req_busy_li, dcache_req_metadata_v_lo;
  bp_dcache_req_metadata_s dcache_req_metadata_lo;
  logic dcache_req_critical_tag_li, dcache_req_critical_data_li, dcache_req_complete_li;
  logic dcache_req_credits_full_li, dcache_req_credits_empty_li;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_yumi_lo;
  bp_dcache_tag_info_s dcache_tag_mem_lo;
  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;
  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_yumi_lo;
  bp_dcache_stat_info_s dcache_stat_mem_lo;

  wire [1:0][lce_id_width_p-1:0] lce_id_li = {cfg_bus_cast_i.dcache_id, cfg_bus_cast_i.icache_id};
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
     ,.icache_req_critical_tag_i(icache_req_critical_tag_li)
     ,.icache_req_critical_data_i(icache_req_critical_data_li)
     ,.icache_req_complete_i(icache_req_complete_li)
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
     ,.dcache_req_critical_tag_i(dcache_req_critical_tag_li)
     ,.dcache_req_critical_data_i(dcache_req_critical_data_li)
     ,.dcache_req_complete_i(dcache_req_complete_li)
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

     ,.unfreeze_irq_i(unfreeze_irq_i)
     ,.debug_irq_i(debug_irq_i)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     );

  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.mem_data_width_p(uce_fill_width_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     ,.metadata_latency_p(1)
     )
   icache_uce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_li[0])

     ,.cache_req_i(icache_req_lo)
     ,.cache_req_v_i(icache_req_v_lo)
     ,.cache_req_yumi_o(icache_req_yumi_li)
     ,.cache_req_busy_o(icache_req_busy_li)
     ,.cache_req_metadata_i(icache_req_metadata_lo)
     ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
     ,.cache_req_critical_tag_o(icache_req_critical_tag_li)
     ,.cache_req_critical_data_o(icache_req_critical_data_li)
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

     ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
     ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_yumi_i(icache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(icache_stat_mem_lo)

     ,.mem_cmd_header_o(mem_cmd_header_o[0])
     ,.mem_cmd_data_o(mem_cmd_data_o[0])
     ,.mem_cmd_v_o(mem_cmd_v_o[0])
     ,.mem_cmd_ready_and_i(mem_cmd_ready_and_i[0])
     ,.mem_cmd_last_o(mem_cmd_last_o[0])

     ,.mem_resp_header_i(mem_resp_header_i[0])
     ,.mem_resp_data_i(mem_resp_data_i[0])
     ,.mem_resp_v_i(mem_resp_v_i[0])
     ,.mem_resp_ready_and_o(mem_resp_ready_and_o[0])
     ,.mem_resp_last_i(mem_resp_last_i[0])
     );

  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.mem_data_width_p(uce_fill_width_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p)
     ,.fill_width_p(uce_fill_width_p)
     ,.req_invert_clk_p(1)
     ,.data_mem_invert_clk_p(1)
     ,.tag_mem_invert_clk_p(1)
     ,.metadata_latency_p(1)
     )
   dcache_uce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_li[1])

     ,.cache_req_i(dcache_req_lo)
     ,.cache_req_v_i(dcache_req_v_lo)
     ,.cache_req_yumi_o(dcache_req_yumi_li)
     ,.cache_req_busy_o(dcache_req_busy_li)
     ,.cache_req_metadata_i(dcache_req_metadata_lo)
     ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
     ,.cache_req_critical_tag_o(dcache_req_critical_tag_li)
     ,.cache_req_critical_data_o(dcache_req_critical_data_li)
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

     ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
     ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(dcache_stat_mem_lo)

     ,.mem_cmd_header_o(mem_cmd_header_o[1])
     ,.mem_cmd_data_o(mem_cmd_data_o[1])
     ,.mem_cmd_v_o(mem_cmd_v_o[1])
     ,.mem_cmd_ready_and_i(mem_cmd_ready_and_i[1])
     ,.mem_cmd_last_o(mem_cmd_last_o[1])
     ,.mem_resp_header_i(mem_resp_header_i[1])
     ,.mem_resp_data_i(mem_resp_data_i[1])
     ,.mem_resp_v_i(mem_resp_v_i[1])
     ,.mem_resp_ready_and_o(mem_resp_ready_and_o[1])
     ,.mem_resp_last_i(mem_resp_last_i[1])
     );

endmodule



`include "bp_common_defines.svh"
`include "bp_top_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"

module bp_unicore_lite
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   // Outgoing BP Stream Mem Buses from I$ and D$
   , output logic [1:0][mem_fwd_header_width_lp-1:0]   mem_fwd_header_o
   , output logic [1:0][bedrock_fill_width_p-1:0]      mem_fwd_data_o
   , output logic [1:0]                                mem_fwd_v_o
   , input [1:0]                                       mem_fwd_ready_and_i

   , input [1:0][mem_rev_header_width_lp-1:0]          mem_rev_header_i
   , input [1:0][bedrock_fill_width_p-1:0]             mem_rev_data_i
   , input [1:0]                                       mem_rev_v_i
   , output logic [1:0]                                mem_rev_ready_and_o

   , input                                             debug_irq_i
   , input                                             timer_irq_i
   , input                                             software_irq_i
   , input                                             m_external_irq_i
   , input                                             s_external_irq_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_fe_icache_engine_if(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, icache_data_width_p, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p);
  `declare_bp_be_dcache_engine_if(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dcache_data_width_p, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  bp_fe_icache_req_s icache_req_lo;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_lock_li, icache_req_metadata_v_lo;
  bp_fe_icache_req_metadata_s icache_req_metadata_lo;
  logic [icache_req_id_width_p-1:0] icache_req_id_li;
  logic icache_req_critical_li, icache_req_last_li;
  logic icache_req_credits_full_li, icache_req_credits_empty_li;

  bp_fe_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_yumi_lo;
  bp_fe_icache_tag_info_s icache_tag_mem_lo;
  bp_fe_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_yumi_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;
  bp_fe_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_yumi_lo;
  bp_fe_icache_stat_info_s icache_stat_mem_lo;

  bp_be_dcache_req_s dcache_req_lo;
  logic dcache_req_v_lo, dcache_req_yumi_li, dcache_req_lock_li, dcache_req_metadata_v_lo;
  bp_be_dcache_req_metadata_s dcache_req_metadata_lo;
  logic [dcache_req_id_width_p-1:0] dcache_req_id_li;
  logic dcache_req_critical_li, dcache_req_last_li;
  logic dcache_req_credits_full_li, dcache_req_credits_empty_li;

  bp_be_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_yumi_lo;
  bp_be_dcache_tag_info_s dcache_tag_mem_lo;
  bp_be_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;
  bp_be_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_yumi_lo;
  bp_be_dcache_stat_info_s dcache_stat_mem_lo;

  wire posedge_clk = clk_i;
  wire negedge_clk = ~clk_i;

  wire [did_width_p-1:0] did_li = cfg_bus_cast_i.did;
  wire [1:0][lce_id_width_p-1:0] lce_id_li = {cfg_bus_cast_i.dcache_id, cfg_bus_cast_i.icache_id};
  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core_minimal
    (.clk_i(posedge_clk)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_cast_i)

     ,.icache_req_o(icache_req_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_yumi_i(icache_req_yumi_li)
     ,.icache_req_lock_i(icache_req_lock_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.icache_req_id_i(icache_req_id_li)
     ,.icache_req_critical_i(icache_req_critical_li)
     ,.icache_req_last_i(icache_req_last_li)
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
     ,.dcache_req_lock_i(dcache_req_lock_li)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)
     ,.dcache_req_id_i(dcache_req_id_li)
     ,.dcache_req_critical_i(dcache_req_critical_li)
     ,.dcache_req_last_i(dcache_req_last_li)
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

     ,.debug_irq_i(debug_irq_i)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     );

  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     ,.data_width_p(icache_data_width_p)
     ,.tag_width_p(icache_tag_width_p)
     ,.id_width_p(icache_req_id_width_p)
     ,.writeback_p(icache_features_p[e_cfg_writeback])
     )
   icache_uce
    (.clk_i(posedge_clk)
     ,.reset_i(reset_i)

     ,.did_i(did_li)
     ,.lce_id_i(lce_id_li[0])

     ,.cache_req_i(icache_req_lo)
     ,.cache_req_v_i(icache_req_v_lo)
     ,.cache_req_yumi_o(icache_req_yumi_li)
     ,.cache_req_lock_o(icache_req_lock_li)
     ,.cache_req_metadata_i(icache_req_metadata_lo)
     ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
     ,.cache_req_id_o(icache_req_id_li)
     ,.cache_req_critical_o(icache_req_critical_li)
     ,.cache_req_last_o(icache_req_last_li)
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

     ,.mem_fwd_header_o(mem_fwd_header_o[0])
     ,.mem_fwd_data_o(mem_fwd_data_o[0])
     ,.mem_fwd_v_o(mem_fwd_v_o[0])
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i[0])

     ,.mem_rev_header_i(mem_rev_header_i[0])
     ,.mem_rev_data_i(mem_rev_data_i[0])
     ,.mem_rev_v_i(mem_rev_v_i[0])
     ,.mem_rev_ready_and_o(mem_rev_ready_and_o[0])
     );

  bp_bedrock_mem_fwd_header_s [1:1] _mem_fwd_header_o;
  logic [1:1][bedrock_fill_width_p-1:0] _mem_fwd_data_o;
  logic [1:1] _mem_fwd_v_o, _mem_fwd_ready_and_i;
  bp_bedrock_mem_rev_header_s [1:1] _mem_rev_header_i;
  logic [1:1][bedrock_fill_width_p-1:0] _mem_rev_data_i;
  logic [1:1] _mem_rev_v_i, _mem_rev_ready_and_o;
  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p)
     ,.fill_width_p(dcache_fill_width_p)
     ,.data_width_p(dcache_data_width_p)
     ,.tag_width_p(dcache_tag_width_p)
     ,.id_width_p(dcache_req_id_width_p)
     ,.writeback_p(dcache_features_p[e_cfg_writeback])
     )
   dcache_uce
    (.clk_i(negedge_clk)
     ,.reset_i(reset_i)

     ,.did_i(did_li)
     ,.lce_id_i(lce_id_li[1])

     ,.cache_req_i(dcache_req_lo)
     ,.cache_req_v_i(dcache_req_v_lo)
     ,.cache_req_yumi_o(dcache_req_yumi_li)
     ,.cache_req_lock_o(dcache_req_lock_li)
     ,.cache_req_metadata_i(dcache_req_metadata_lo)
     ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
     ,.cache_req_id_o(dcache_req_id_li)
     ,.cache_req_critical_o(dcache_req_critical_li)
     ,.cache_req_last_o(dcache_req_last_li)
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

     ,.mem_fwd_header_o(_mem_fwd_header_o[1])
     ,.mem_fwd_data_o(_mem_fwd_data_o[1])
     ,.mem_fwd_v_o(_mem_fwd_v_o[1])
     ,.mem_fwd_ready_and_i(_mem_fwd_ready_and_i[1])

     ,.mem_rev_header_i(_mem_rev_header_i[1])
     ,.mem_rev_data_i(_mem_rev_data_i[1])
     ,.mem_rev_v_i(_mem_rev_v_i[1])
     ,.mem_rev_ready_and_o(_mem_rev_ready_and_o[1])
     );

  bsg_fifo_1r1w_edge
   #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p))
   mem_fwd
    (.clk_i(negedge_clk)
     ,.reset_i(reset_i)

     ,.data_i({_mem_fwd_header_o[1], _mem_fwd_data_o[1]})
     ,.v_i(_mem_fwd_v_o[1])
     ,.ready_and_o(_mem_fwd_ready_and_i[1])

     ,.data_o({mem_fwd_header_o[1], mem_fwd_data_o[1]})
     ,.v_o(mem_fwd_v_o[1])
     ,.ready_and_i(mem_fwd_ready_and_i[1])
     );

  bsg_fifo_1r1w_edge
   #(.width_p($bits(bp_bedrock_mem_rev_header_s)+bedrock_fill_width_p))
   mem_rev
    (.clk_i(posedge_clk)
     ,.reset_i(reset_i)

     ,.data_i({mem_rev_header_i[1], mem_rev_data_i[1]})
     ,.v_i(mem_rev_v_i[1])
     ,.ready_and_o(mem_rev_ready_and_o[1])

     ,.data_o({_mem_rev_header_i[1], _mem_rev_data_i[1]})
     ,.v_o(_mem_rev_v_i[1])
     ,.ready_and_i(_mem_rev_ready_and_o[1])
     );

endmodule


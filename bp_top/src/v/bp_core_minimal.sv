/**
 *  bp_core_minimal.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_top_defines.svh"

module bp_core_minimal
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_icache_engine_if_widths(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, icache_data_width_p, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p)
   `declare_bp_be_dcache_engine_if_widths(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dcache_data_width_p, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                             clk_i
   , input                                           reset_i

   , input [cfg_bus_width_lp-1:0]                    cfg_bus_i

   , output logic [icache_req_width_lp-1:0]          icache_req_o
   , output logic                                    icache_req_v_o
   , input                                           icache_req_yumi_i
   , input                                           icache_req_lock_i
   , output logic [icache_req_metadata_width_lp-1:0] icache_req_metadata_o
   , output logic                                    icache_req_metadata_v_o
   , input [icache_req_id_width_p-1:0]               icache_req_id_i
   , input                                           icache_req_critical_i
   , input                                           icache_req_last_i
   , input                                           icache_req_credits_full_i
   , input                                           icache_req_credits_empty_i

   , input [icache_tag_mem_pkt_width_lp-1:0]         icache_tag_mem_pkt_i
   , input                                           icache_tag_mem_pkt_v_i
   , output logic                                    icache_tag_mem_pkt_yumi_o
   , output logic [icache_tag_info_width_lp-1:0]     icache_tag_mem_o

   , input [icache_data_mem_pkt_width_lp-1:0]        icache_data_mem_pkt_i
   , input                                           icache_data_mem_pkt_v_i
   , output logic                                    icache_data_mem_pkt_yumi_o
   , output logic [icache_block_width_p-1:0]         icache_data_mem_o

   , input [icache_stat_mem_pkt_width_lp-1:0]        icache_stat_mem_pkt_i
   , input                                           icache_stat_mem_pkt_v_i
   , output logic                                    icache_stat_mem_pkt_yumi_o
   , output logic [icache_stat_info_width_lp-1:0]    icache_stat_mem_o

   // D$ Engine Interface is clocked on the negedge of the clock. Must be attached to
   //   a negative-edge cache engine and synchronized before getting to the memory system
   , output logic [dcache_req_width_lp-1:0]          dcache_req_o
   , output logic                                    dcache_req_v_o
   , input                                           dcache_req_yumi_i
   , input                                           dcache_req_lock_i
   , output logic [dcache_req_metadata_width_lp-1:0] dcache_req_metadata_o
   , output logic                                    dcache_req_metadata_v_o
   , input [dcache_req_id_width_p-1:0]               dcache_req_id_i
   , input                                           dcache_req_critical_i
   , input                                           dcache_req_last_i
   , input                                           dcache_req_credits_full_i
   , input                                           dcache_req_credits_empty_i

   , input [dcache_tag_mem_pkt_width_lp-1:0]         dcache_tag_mem_pkt_i
   , input                                           dcache_tag_mem_pkt_v_i
   , output logic                                    dcache_tag_mem_pkt_yumi_o
   , output logic [dcache_tag_info_width_lp-1:0]     dcache_tag_mem_o

   , input [dcache_data_mem_pkt_width_lp-1:0]        dcache_data_mem_pkt_i
   , input                                           dcache_data_mem_pkt_v_i
   , output logic                                    dcache_data_mem_pkt_yumi_o
   , output logic [dcache_block_width_p-1:0]         dcache_data_mem_o

   , input [dcache_stat_mem_pkt_width_lp-1:0]        dcache_stat_mem_pkt_i
   , input                                           dcache_stat_mem_pkt_v_i
   , output logic                                    dcache_stat_mem_pkt_yumi_o
   , output logic [dcache_stat_info_width_lp-1:0]    dcache_stat_mem_o

   , input                                           debug_irq_i
   , input                                           timer_irq_i
   , input                                           software_irq_i
   , input                                           m_external_irq_i
   , input                                           s_external_irq_i
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);

  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  bp_fe_queue_s fe_queue_li, fe_queue_lo;
  logic fe_queue_v_li, fe_queue_ready_and_lo;
  bp_fe_cmd_s fe_cmd_lo;
  logic fe_cmd_v_lo, fe_cmd_yumi_li;

  bp_fe_top
   #(.bp_params_p(bp_params_p))
   fe
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_cast_i)

     ,.fe_queue_o(fe_queue_li)
     ,.fe_queue_v_o(fe_queue_v_li)
     ,.fe_queue_ready_and_i(fe_queue_ready_and_lo)

     ,.fe_cmd_i(fe_cmd_lo)
     ,.fe_cmd_v_i(fe_cmd_v_lo)
     ,.fe_cmd_yumi_o(fe_cmd_yumi_li)

     ,.cache_req_o(icache_req_o)
     ,.cache_req_v_o(icache_req_v_o)
     ,.cache_req_yumi_i(icache_req_yumi_i)
     ,.cache_req_lock_i(icache_req_lock_i)
     ,.cache_req_metadata_o(icache_req_metadata_o)
     ,.cache_req_metadata_v_o(icache_req_metadata_v_o)
     ,.cache_req_id_i(icache_req_id_i)
     ,.cache_req_critical_i(icache_req_critical_i)
     ,.cache_req_last_i(icache_req_last_i)
     ,.cache_req_credits_full_i(icache_req_credits_full_i)
     ,.cache_req_credits_empty_i(icache_req_credits_empty_i)

     ,.tag_mem_pkt_i(icache_tag_mem_pkt_i)
     ,.tag_mem_pkt_v_i(icache_tag_mem_pkt_v_i)
     ,.tag_mem_pkt_yumi_o(icache_tag_mem_pkt_yumi_o)
     ,.tag_mem_o(icache_tag_mem_o)

     ,.data_mem_pkt_i(icache_data_mem_pkt_i)
     ,.data_mem_pkt_v_i(icache_data_mem_pkt_v_i)
     ,.data_mem_pkt_yumi_o(icache_data_mem_pkt_yumi_o)
     ,.data_mem_o(icache_data_mem_o)

     ,.stat_mem_pkt_v_i(icache_stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(icache_stat_mem_pkt_i)
     ,.stat_mem_pkt_yumi_o(icache_stat_mem_pkt_yumi_o)
     ,.stat_mem_o(icache_stat_mem_o)
     );

  bp_be_top
   #(.bp_params_p(bp_params_p))
   be
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_cast_i)

     ,.fe_queue_i(fe_queue_li)
     ,.fe_queue_v_i(fe_queue_v_li)
     ,.fe_queue_ready_and_o(fe_queue_ready_and_lo)

     ,.fe_cmd_o(fe_cmd_lo)
     ,.fe_cmd_v_o(fe_cmd_v_lo)
     ,.fe_cmd_yumi_i(fe_cmd_yumi_li)

     ,.cache_req_o(dcache_req_o)
     ,.cache_req_v_o(dcache_req_v_o)
     ,.cache_req_yumi_i(dcache_req_yumi_i)
     ,.cache_req_lock_i(dcache_req_lock_i)
     ,.cache_req_metadata_o(dcache_req_metadata_o)
     ,.cache_req_metadata_v_o(dcache_req_metadata_v_o)
     ,.cache_req_id_i(dcache_req_id_i)
     ,.cache_req_critical_i(dcache_req_critical_i)
     ,.cache_req_last_i(dcache_req_last_i)
     ,.cache_req_credits_full_i(dcache_req_credits_full_i)
     ,.cache_req_credits_empty_i(dcache_req_credits_empty_i)

     ,.data_mem_pkt_i(dcache_data_mem_pkt_i)
     ,.data_mem_pkt_v_i(dcache_data_mem_pkt_v_i)
     ,.data_mem_pkt_yumi_o(dcache_data_mem_pkt_yumi_o)
     ,.data_mem_o(dcache_data_mem_o)

     ,.tag_mem_pkt_i(dcache_tag_mem_pkt_i)
     ,.tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_i)
     ,.tag_mem_pkt_yumi_o(dcache_tag_mem_pkt_yumi_o)
     ,.tag_mem_o(dcache_tag_mem_o)

     ,.stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(dcache_stat_mem_pkt_i)
     ,.stat_mem_pkt_yumi_o(dcache_stat_mem_pkt_yumi_o)
     ,.stat_mem_o(dcache_stat_mem_o)

     ,.debug_irq_i(debug_irq_i)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     );

endmodule


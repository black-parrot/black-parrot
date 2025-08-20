/**
 *
 *  Name:
 *    bp_be_top.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_top
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)
   `declare_bp_be_dcache_engine_if_widths(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p)

   // Default parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
  )
  (input                                             clk_i
   , input                                           reset_i

   // Processor configuration
   , input [cfg_bus_width_lp-1:0]                    cfg_bus_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]                   fe_queue_i
   , input                                           fe_queue_v_i
   , output logic                                    fe_queue_ready_and_o

   // FE cmd interface
   , output logic [fe_cmd_width_lp-1:0]              fe_cmd_o
   , output logic                                    fe_cmd_v_o
   , input                                           fe_cmd_yumi_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_lock_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input [dcache_req_id_width_p-1:0]               cache_req_id_i
   , input                                           cache_req_critical_i
   , input                                           cache_req_last_i
   , input                                           cache_req_credits_full_i
   , input                                           cache_req_credits_empty_i

   // tag_mem
   , input                                           tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0]         tag_mem_pkt_i
   , output logic [dcache_tag_info_width_lp-1:0]     tag_mem_o
   , output logic                                    tag_mem_pkt_yumi_o

   // data_mem
   , input                                           data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
   , output logic [dcache_block_width_p-1:0]         data_mem_o
   , output logic                                    data_mem_pkt_yumi_o

   // stat_mem
   , input                                           stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0]        stat_mem_pkt_i
   , output logic [dcache_stat_info_width_lp-1:0]    stat_mem_o
   , output logic                                    stat_mem_pkt_yumi_o

   , input                                           debug_irq_i
   , input                                           timer_irq_i
   , input                                           software_irq_i
   , input                                           m_external_irq_i
   , input                                           s_external_irq_i
   );

  // Declare parameterized structures
  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  // Top-level interface connections
  bp_be_dispatch_pkt_s dispatch_pkt;
  bp_be_branch_pkt_s   br_pkt;

  logic ordered_v, hazard_v, ispec_v;
  logic irq_pending_lo, irq_waiting_lo;

  bp_be_commit_pkt_s commit_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_decode_info_s decode_info_lo;
  bp_be_trans_info_s trans_info_lo;

  logic [wb_pkt_width_lp-1:0] late_wb_pkt;
  logic late_wb_v_lo, late_wb_force_lo, late_wb_yumi_li;

  bp_be_issue_pkt_s issue_pkt;
  logic [vaddr_width_p-1:0] expected_npc_lo;
  logic npc_mismatch_lo, poison_isd_lo, clear_iss_lo, suppress_iss_lo, resume_lo;

  logic cmd_full_n_lo, cmd_full_r_lo, cmd_empty_n_lo, cmd_empty_r_lo;
  logic mem_ordered_lo, mem_busy_lo, idiv_busy_lo, fdiv_busy_lo;

  bp_be_director
   #(.bp_params_p(bp_params_p))
   director
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_i)

     ,.issue_pkt_i(issue_pkt)
     ,.expected_npc_o(expected_npc_lo)

     ,.fe_cmd_o(fe_cmd_o)
     ,.fe_cmd_v_o(fe_cmd_v_o)
     ,.fe_cmd_yumi_i(fe_cmd_yumi_i)

     ,.resume_o(resume_lo)
     ,.poison_isd_o(poison_isd_lo)
     ,.clear_iss_o(clear_iss_lo)
     ,.suppress_iss_o(suppress_iss_lo)
     ,.irq_waiting_i(irq_waiting_lo)
     ,.mem_busy_i(mem_busy_lo)
     ,.cmd_full_n_o(cmd_full_n_lo)
     ,.cmd_full_r_o(cmd_full_r_lo)

     ,.br_pkt_i(br_pkt)
     ,.commit_pkt_i(commit_pkt)
     );

  bp_be_detector
   #(.bp_params_p(bp_params_p))
   detector
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.issue_pkt_i(issue_pkt)
     ,.cmd_full_i(cmd_full_r_lo)
     ,.credits_full_i(cache_req_credits_full_i)
     ,.credits_empty_i(cache_req_credits_empty_i)
     ,.mem_busy_i(mem_busy_lo)
     ,.mem_ordered_i(mem_ordered_lo)
     ,.fdiv_busy_i(fdiv_busy_lo)
     ,.idiv_busy_i(idiv_busy_lo)
     ,.ispec_v_o(ispec_v)
     ,.hazard_v_o(hazard_v)
     ,.ordered_v_o(ordered_v)
     ,.dispatch_pkt_i(dispatch_pkt)
     ,.commit_pkt_i(commit_pkt)

     ,.late_wb_pkt_i(late_wb_pkt)
     ,.late_wb_yumi_i(late_wb_yumi_li)
     );

  bp_be_scheduler
   #(.bp_params_p(bp_params_p))
   scheduler
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.poison_isd_i(poison_isd_lo)
     ,.resume_i(resume_lo)
     ,.decode_info_i(decode_info_lo)
     ,.trans_info_i(trans_info_lo)
     ,.issue_pkt_o(issue_pkt)
     ,.suppress_iss_i(suppress_iss_lo)
     ,.clear_iss_i(clear_iss_lo)
     ,.expected_npc_i(expected_npc_lo)
     ,.hazard_v_i(hazard_v)
     ,.ispec_v_i(ispec_v)
     ,.irq_pending_i(irq_pending_lo)
     ,.ordered_v_i(ordered_v)

     ,.fe_queue_i(fe_queue_i)
     ,.fe_queue_v_i(fe_queue_v_i)
     ,.fe_queue_ready_and_o(fe_queue_ready_and_o)

     ,.dispatch_pkt_o(dispatch_pkt)
     ,.commit_pkt_i(commit_pkt)
     ,.iwb_pkt_i(iwb_pkt)
     ,.fwb_pkt_i(fwb_pkt)

     ,.late_wb_pkt_i(late_wb_pkt)
     ,.late_wb_v_i(late_wb_v_lo)
     ,.late_wb_force_i(late_wb_force_lo)
     ,.late_wb_yumi_o(late_wb_yumi_li)
     );

  bp_be_calculator_top
   #(.bp_params_p(bp_params_p))
   calculator
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_i)

     ,.decode_info_o(decode_info_lo)
     ,.trans_info_o(trans_info_lo)
     ,.mem_busy_o(mem_busy_lo)
     ,.mem_ordered_o(mem_ordered_lo)
     ,.idiv_busy_o(idiv_busy_lo)
     ,.fdiv_busy_o(fdiv_busy_lo)

     ,.dispatch_pkt_i(dispatch_pkt)
     ,.br_pkt_o(br_pkt)
     ,.commit_pkt_o(commit_pkt)
     ,.iwb_pkt_o(iwb_pkt)
     ,.fwb_pkt_o(fwb_pkt)

     ,.late_wb_pkt_o(late_wb_pkt)
     ,.late_wb_v_o(late_wb_v_lo)
     ,.late_wb_force_o(late_wb_force_lo)
     ,.late_wb_yumi_i(late_wb_yumi_li)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_lock_i(cache_req_lock_i)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_id_i(cache_req_id_i)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_last_i(cache_req_last_i)
     ,.cache_req_credits_full_i(cache_req_credits_full_i)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_i)

     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
     ,.tag_mem_pkt_i(tag_mem_pkt_i)
     ,.tag_mem_o(tag_mem_o)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)

     ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
     ,.data_mem_pkt_i(data_mem_pkt_i)
     ,.data_mem_o(data_mem_o)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)

     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(stat_mem_pkt_i)
     ,.stat_mem_o(stat_mem_o)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)

     ,.debug_irq_i(debug_irq_i)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     ,.irq_pending_o(irq_pending_lo)
     ,.irq_waiting_o(irq_waiting_lo)
     ,.cmd_full_n_i(cmd_full_n_lo)
     );

endmodule


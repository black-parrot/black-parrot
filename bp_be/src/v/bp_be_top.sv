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
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache)

   // Default parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
  )
  (input                                             clk_i
   , input                                           reset_i

   // Processor configuration
   , input [cfg_bus_width_lp-1:0]                    cfg_bus_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]                   fe_queue_i
   , input                                           fe_queue_v_i
   , output                                          fe_queue_ready_o

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]                    fe_cmd_o
   , output                                          fe_cmd_v_o
   , input                                           fe_cmd_yumi_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_busy_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input                                           cache_req_critical_i
   , input                                           cache_req_complete_i
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

   , input                                           timer_irq_i
   , input                                           software_irq_i
   , input                                           external_irq_i
   );

  // Declare parameterized structures
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Top-level interface connections
  bp_be_dispatch_pkt_s dispatch_pkt;
  bp_be_branch_pkt_s   br_pkt;
  bp_be_ptw_miss_pkt_s ptw_miss_pkt;

  logic dispatch_v, interrupt_v;
  logic irq_pending_lo, irq_waiting_lo, replay_pending_lo;

  bp_be_commit_pkt_s commit_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_decode_info_s decode_info_lo;

  bp_be_isd_status_s isd_status;
  logic [vaddr_width_p-1:0] expected_npc_lo;
  logic poison_isd_lo, suppress_iss_lo;
  logic waiting_for_irq_lo;

  logic cmd_full_n_lo, cmd_full_r_lo, cmd_empty_lo;
  logic mem_ready_lo, long_ready_lo, ptw_busy_lo;

  bp_be_director
   #(.bp_params_p(bp_params_p))
   director
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.isd_status_i(isd_status)
     ,.expected_npc_o(expected_npc_lo)

     ,.fe_cmd_o(fe_cmd_o)
     ,.fe_cmd_v_o(fe_cmd_v_o)
     ,.fe_cmd_yumi_i(fe_cmd_yumi_i)

     ,.suppress_iss_o(suppress_iss_lo)
     ,.poison_isd_o(poison_isd_lo)
     ,.irq_waiting_i(irq_waiting_lo)
     ,.cmd_empty_o()
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

     ,.cfg_bus_i(cfg_bus_i)

     ,.isd_status_i(isd_status)
     ,.cmd_full_i(cmd_full_r_lo)
     ,.credits_full_i(cache_req_credits_full_i)
     ,.credits_empty_i(cache_req_credits_empty_i)
     ,.mem_ready_i(mem_ready_lo)
     ,.long_ready_i(long_ready_lo)
     ,.ptw_busy_i(ptw_busy_lo)
     ,.irq_pending_i(irq_pending_lo)
     ,.replay_pending_i(replay_pending_lo)

     ,.dispatch_v_o(dispatch_v)
     ,.interrupt_v_o(interrupt_v)
     ,.dispatch_pkt_i(dispatch_pkt)
     ,.commit_pkt_i(commit_pkt)
     ,.iwb_pkt_i(iwb_pkt)
     ,.fwb_pkt_i(fwb_pkt)
     );

  bp_be_scheduler
   #(.bp_params_p(bp_params_p))
   scheduler
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.isd_status_o(isd_status)
     ,.expected_npc_i(expected_npc_lo)
     ,.poison_isd_i(poison_isd_lo)
     ,.dispatch_v_i(dispatch_v)
     ,.interrupt_v_i(interrupt_v)
     ,.suppress_iss_i(suppress_iss_lo)
     ,.decode_info_i(decode_info_lo)

     ,.fe_queue_i(fe_queue_i)
     ,.fe_queue_v_i(fe_queue_v_i)
     ,.fe_queue_ready_o(fe_queue_ready_o)

     ,.dispatch_pkt_o(dispatch_pkt)

     ,.commit_pkt_i(commit_pkt)
     ,.ptw_fill_pkt_i(ptw_fill_pkt)
     ,.iwb_pkt_i(iwb_pkt)
     ,.fwb_pkt_i(fwb_pkt)
     );

  bp_be_calculator_top
   #(.bp_params_p(bp_params_p))
   calculator
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.dispatch_pkt_i(dispatch_pkt)

     ,.decode_info_o(decode_info_lo)
     ,.mem_ready_o(mem_ready_lo)
     ,.long_ready_o(long_ready_lo)
     ,.ptw_busy_o(ptw_busy_lo)

     ,.br_pkt_o(br_pkt)
     ,.commit_pkt_o(commit_pkt)
     ,.ptw_fill_pkt_o(ptw_fill_pkt)
     ,.iwb_pkt_o(iwb_pkt)
     ,.fwb_pkt_o(fwb_pkt)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_busy_i(cache_req_busy_i)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_complete_i(cache_req_complete_i)
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

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     ,.irq_pending_o(irq_pending_lo)
     ,.irq_waiting_o(irq_waiting_lo)
     ,.replay_pending_o(replay_pending_lo)
     ,.cmd_full_n_i(cmd_full_n_lo)
     );

endmodule


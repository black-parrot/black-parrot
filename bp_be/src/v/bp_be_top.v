/**
 *
 *  Name:
 *    bp_be_top.v
 *
 */


module bp_be_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache)

   // Default parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

   // VM parameters
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
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
   , input                                           cache_req_ready_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input                                           cache_req_critical_i
   , input                                           cache_req_complete_i

   // data_mem
   , input                                           data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
   , output logic [dcache_block_width_p-1:0]         data_mem_o
   , output logic                                    data_mem_pkt_yumi_o

   // tag_mem
   , input                                           tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0]         tag_mem_pkt_i
   , output logic [dcache_tag_info_width_lp-1:0]     tag_mem_o
   , output logic                                    tag_mem_pkt_yumi_o

   // stat_mem
   , input                                           stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0]        stat_mem_pkt_i
   , output logic [dcache_stat_info_width_lp-1:0]    stat_mem_o
   , output logic                                    stat_mem_pkt_yumi_o

   , input                                           credits_full_i
   , input                                           credits_empty_i

   , input                                           timer_irq_i
   , input                                           software_irq_i
   , input                                           external_irq_i
   );

  // Declare parameterized structures
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_mem_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dcache_block_width_p)
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Top-level interface connections
  bp_be_dispatch_pkt_s dispatch_pkt;
  bp_be_branch_pkt_s   br_pkt;
  bp_be_ptw_miss_pkt_s ptw_miss_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;

  logic chk_dispatch_v;

  bp_be_commit_pkt_s commit_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;

  bp_be_isd_status_s isd_status;
  logic [vaddr_width_p-1:0] expected_npc_lo;
  logic poison_isd_lo, suppress_iss_lo;

  logic fpu_en_lo;
  logic fe_cmd_full_lo;
  logic mem_ready_lo, long_ready_lo, sys_ready_lo;


  logic flush;
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
     ,.fe_cmd_full_o(fe_cmd_full_lo)

     ,.suppress_iss_o(suppress_iss_lo)
     ,.poison_isd_o(poison_isd_lo)
     ,.flush_o(flush)

     ,.br_pkt_i(br_pkt)
     ,.commit_pkt_i(commit_pkt)
     ,.ptw_fill_pkt_i(ptw_fill_pkt)
     );

  bp_be_detector
   #(.bp_params_p(bp_params_p))
   detector
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.isd_status_i(isd_status)
     ,.fe_cmd_full_i(fe_cmd_full_lo)
     ,.credits_full_i(credits_full_i)
     ,.credits_empty_i(credits_empty_i)
     ,.mem_ready_i(mem_ready_lo)
     ,.long_ready_i(long_ready_lo)
     ,.sys_ready_i(sys_ready_lo)

     ,.chk_dispatch_v_o(chk_dispatch_v)
     ,.dispatch_pkt_i(dispatch_pkt)
     );

  bp_be_scheduler
   #(.bp_params_p(bp_params_p))
   scheduler
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.isd_status_o(isd_status)
     ,.expected_npc_i(expected_npc_lo)
     ,.poison_isd_i(poison_isd_lo)
     ,.dispatch_v_i(chk_dispatch_v)
     ,.suppress_iss_i(suppress_iss_lo)
     ,.fpu_en_i(fpu_en_lo)

     ,.fe_queue_i(fe_queue_i)
     ,.fe_queue_v_i(fe_queue_v_i)
     ,.fe_queue_ready_o(fe_queue_ready_o)

     ,.dispatch_pkt_o(dispatch_pkt)

     ,.commit_pkt_i(commit_pkt)
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

     ,.flush_i(flush)

     ,.fpu_en_o(fpu_en_lo)
     ,.mem_ready_o(mem_ready_lo)
     ,.long_ready_o(long_ready_lo)
     ,.sys_ready_o(sys_ready_lo)

     ,.ptw_fill_pkt_o(ptw_fill_pkt)

     ,.br_pkt_o(br_pkt)
     ,.commit_pkt_o(commit_pkt)
     ,.iwb_pkt_o(iwb_pkt)
     ,.fwb_pkt_o(fwb_pkt)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_ready_i(cache_req_ready_i)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_complete_i(cache_req_complete_i)

     ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
     ,.data_mem_pkt_i(data_mem_pkt_i)
     ,.data_mem_o(data_mem_o)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)

     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
     ,.tag_mem_pkt_i(tag_mem_pkt_i)
     ,.tag_mem_o(tag_mem_o)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)

     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(stat_mem_pkt_i)
     ,.stat_mem_o(stat_mem_o)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     );

endmodule

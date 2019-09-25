/**
 *
 * Name:
 *   bp_be_checker_top.v
 * 
 * Description:
 *   This is a wrapper for the Checker, which is responsible for scheduling instruction
 *     execution and protecting architectural state from the effects of speculation. It 
 *     contains 3 main components: the Scheduler, the Director and the Detector. 
 *   The Scheduler accepts PC/instruction pairs from the FE and issues them to the Calculator. 
 *   The Detector detects structural, control and data hazards and generates control signals 
 *     for the Calculator to flush or inserts bubbles into the execution pipeline.
 *   The Director maintains the true PC, as well as sending redirection commands to the FE.
 *
 * Notes:
 *
 */

module bp_be_checker_top 
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // Generated parameters
   , localparam isd_status_width_lp = `bp_be_isd_status_width
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp   = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)

   // VM parameters
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                              clk_i
   , input                            reset_i
   , input                            freeze_i

   // Config channel
   , input                            cfg_w_v_i
   , input [cfg_addr_width_p-1:0]     cfg_addr_i
   , input [cfg_data_width_p-1:0]     cfg_data_i

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i

   // FE queue interface
   , output                           fe_queue_roll_o
   , output                           fe_queue_deq_o

   , input [fe_queue_width_lp-1:0]    fe_queue_i
   , input                            fe_queue_v_i
   , output                           fe_queue_yumi_o

   // Instruction issue interface
   , output [issue_pkt_width_lp-1:0]  issue_pkt_o
   , output                           issue_pkt_v_o
   , input                            issue_pkt_ready_i

   // Dependency information
   , input [isd_status_width_lp-1:0]  isd_status_i
   , input [calc_status_width_lp-1:0] calc_status_i
   , input                            mmu_cmd_ready_i
   , input                            credits_full_i
   , input                            credits_empty_i

   // Checker pipeline control information
   , output                           chk_dispatch_v_o
   , output                           chk_roll_o
   , output                           chk_poison_iss_o
   , output                           chk_poison_isd_o
   , output                           chk_poison_ex1_o
   , output                           chk_poison_ex2_o

   // CSR interface
   , input                            trap_v_i
   , input                            ret_v_i
   , output [vaddr_width_p-1:0]       pc_o
   , input [vaddr_width_p-1:0]        tvec_i
   , input [vaddr_width_p-1:0]        epc_i
   , input                            tlb_fence_i
   
   //iTLB fill interface
    , input                           itlb_fill_v_i
    , input [vaddr_width_p-1:0]       itlb_fill_vaddr_i
    , input [tlb_entry_width_lp-1:0]  itlb_fill_entry_i
   );

// Declare parameterizable structures
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p); 

bp_be_calc_status_s calc_status_cast_i;
assign calc_status_cast_i = calc_status_i;

// Intermediate connections
logic [vaddr_width_p-1:0] expected_npc_lo;
logic flush;

// Datapath
bp_be_director 
 #(.cfg_p(cfg_p))
 director
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i(freeze_i)

   ,.cfg_w_v_i(cfg_w_v_i)
   ,.cfg_addr_i(cfg_addr_i)
   ,.cfg_data_i(cfg_data_i)

   ,.calc_status_i(calc_status_i) 
   ,.expected_npc_o(expected_npc_lo)
   ,.flush_o(flush)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)

   ,.trap_v_i(trap_v_i)
   ,.ret_v_i(ret_v_i)
   ,.pc_o(pc_o)
   ,.tvec_i(tvec_i)
   ,.epc_i(epc_i)
   ,.tlb_fence_i(tlb_fence_i)

   ,.itlb_fill_v_i(itlb_fill_v_i)
   ,.itlb_fill_vaddr_i(itlb_fill_vaddr_i)
   ,.itlb_fill_entry_i(itlb_fill_entry_i)
   );

bp_be_detector 
 #(.cfg_p(cfg_p))
 detector
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.isd_status_i(isd_status_i)
   ,.calc_status_i(calc_status_i)
   ,.expected_npc_i(expected_npc_lo)
   ,.mmu_cmd_ready_i(mmu_cmd_ready_i)
   ,.credits_full_i(credits_full_i)
   ,.credits_empty_i(credits_empty_i)

   ,.flush_i(flush)

   ,.chk_dispatch_v_o(chk_dispatch_v_o)
   ,.chk_roll_o(chk_roll_o)
   ,.chk_poison_iss_o(chk_poison_iss_o)
   ,.chk_poison_isd_o(chk_poison_isd_o)
   ,.chk_poison_ex1_o(chk_poison_ex1_o)
   ,.chk_poison_ex2_o(chk_poison_ex2_o)
   );

bp_be_scheduler 
 #(.cfg_p(cfg_p))
 scheduler
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cache_miss_v_i(calc_status_cast_i.mem3_miss_v)
   ,.cmt_v_i(calc_status_cast_i.mem3_cmt_v)

   ,.fe_queue_deq_o(fe_queue_deq_o)
   ,.fe_queue_roll_o(fe_queue_roll_o)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_yumi_o(fe_queue_yumi_o)

   ,.issue_pkt_o(issue_pkt_o)
   ,.issue_pkt_v_o(issue_pkt_v_o)
   ,.issue_pkt_ready_i(issue_pkt_ready_i)
   );

endmodule


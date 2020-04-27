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
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // Generated parameters
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p)
   , localparam dispatch_pkt_width_lp   = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam trap_pkt_width_lp = `bp_be_trap_pkt_width(vaddr_width_p)
   , localparam wb_pkt_width_lp = `bp_be_wb_pkt_width(vaddr_width_p)

   // VM parameters
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                              clk_i
   , input                            reset_i

   , input [cfg_bus_width_lp-1:0]     cfg_bus_i
   , output [vaddr_width_p-1:0]       cfg_npc_data_o
   , output [dword_width_p-1:0]       cfg_irf_data_o

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i
   , input                            fe_cmd_fence_i

   // FE queue interface
   , output                           fe_queue_clr_o
   , output                           fe_queue_roll_o
   , output                           fe_queue_deq_o

   , input [fe_queue_width_lp-1:0]    fe_queue_i
   , input                            fe_queue_v_i
   , output                           fe_queue_yumi_o

   // Instruction issue interface
   , output [dispatch_pkt_width_lp-1:0]  dispatch_pkt_o

   // Dependency information
   , input [calc_status_width_lp-1:0] calc_status_i
   , input                            mmu_cmd_ready_i
   , input                            credits_full_i
   , input                            credits_empty_i

   // Checker pipeline control information
   , output                           chk_dispatch_v_o
   , output                           flush_o

   , input                            accept_irq_i
   , input                            debug_mode_i
   , input                            single_step_i
   
   //iTLB fill interface
    , input                           itlb_fill_v_i
    , input [vaddr_width_p-1:0]       itlb_fill_vaddr_i
    , input [tlb_entry_width_lp-1:0]  itlb_fill_entry_i

    , input [commit_pkt_width_lp-1:0] commit_pkt_i
    , input [trap_pkt_width_lp-1:0]   trap_pkt_i
    , input [wb_pkt_width_lp-1:0]     wb_pkt_i
    );

// Declare parameterizable structures
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p); 

bp_be_commit_pkt_s commit_pkt;
bp_be_calc_status_s calc_status_cast_i;

assign commit_pkt = commit_pkt_i;
assign calc_status_cast_i = calc_status_i;

// Intermediate connections
bp_be_isd_status_s isd_status;
logic [vaddr_width_p-1:0] expected_npc_lo;
logic poison_isd_lo, suppress_iss_lo;

// Datapath
bp_be_director 
 #(.bp_params_p(bp_params_p))
 director
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)
   ,.cfg_npc_data_o(cfg_npc_data_o)

   ,.isd_status_i(isd_status)
   ,.calc_status_i(calc_status_i) 
   ,.expected_npc_o(expected_npc_lo)
   ,.flush_o(flush_o)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)
   ,.fe_cmd_fence_i(fe_cmd_fence_i)

   ,.suppress_iss_o(suppress_iss_lo)
   ,.poison_isd_o(poison_isd_lo)

   ,.commit_pkt_i(commit_pkt_i)
   ,.trap_pkt_i(trap_pkt_i)

   ,.itlb_fill_v_i(itlb_fill_v_i)
   ,.itlb_fill_vaddr_i(itlb_fill_vaddr_i)
   ,.itlb_fill_entry_i(itlb_fill_entry_i)
   );

bp_be_detector 
 #(.bp_params_p(bp_params_p))
 detector
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)

   ,.isd_status_i(isd_status)
   ,.calc_status_i(calc_status_i)
   ,.expected_npc_i(expected_npc_lo)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)
   ,.mmu_cmd_ready_i(mmu_cmd_ready_i)
   ,.credits_full_i(credits_full_i)
   ,.credits_empty_i(credits_empty_i)
   ,.debug_mode_i(debug_mode_i)
   ,.single_step_i(single_step_i)

   ,.chk_dispatch_v_o(chk_dispatch_v_o)
   );

bp_be_scheduler 
 #(.bp_params_p(bp_params_p))
 scheduler
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)
   ,.cfg_irf_data_o(cfg_irf_data_o)

   ,.accept_irq_i(accept_irq_i)
   ,.isd_status_o(isd_status)
   ,.expected_npc_i(expected_npc_lo)
   ,.poison_iss_i(flush_o)
   ,.poison_isd_i(poison_isd_lo)
   ,.dispatch_v_i(chk_dispatch_v_o)
   ,.cache_miss_v_i(commit_pkt.cache_miss | commit_pkt.tlb_miss)
   ,.cmt_v_i(commit_pkt.queue_v)
   ,.debug_mode_i(debug_mode_i)
   ,.suppress_iss_i(suppress_iss_lo)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_yumi_o(fe_queue_yumi_o)
   ,.fe_queue_clr_o(fe_queue_clr_o)
   ,.fe_queue_roll_o(fe_queue_roll_o)
   ,.fe_queue_deq_o(fe_queue_deq_o)


   ,.dispatch_pkt_o(dispatch_pkt_o)
   
   ,.wb_pkt_i(wb_pkt_i)
   );

endmodule


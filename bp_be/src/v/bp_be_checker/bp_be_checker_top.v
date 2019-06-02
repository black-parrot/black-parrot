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
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *
 *   fe_queue_i                  - Structure from FE, either an instruction/PC pair or exception
 *   fe_queue_v_i                - "valid-then-ready" interface
 *   fe_queue_ready_o            -
 *
 *   calc_status_i               - Instruction dependency information from the calculator
 *   mmu_cmd_ready_i             - MMU ready, used as structural hazard detection for mem instrs
 *   
 * Outputs:
 *   fe_cmd_o                    - Command to FE, used for PC redirection among other things
 *   fe_cmd_v_o                  - "ready-then-valid" interface
 *   fe_cmd_ready_i              -
 *    
 *   chk_roll_fe_o               - Command to rollback the FE queue to the last checkpoint 
 *   chk_flush_fe_o              - Command to flush the FE queue (e.g. on a mispredict)
 *   chk_dequeue_fe_o            - An instruction has committed in the BE
 *
 *   issue_pkt_o                 - Issuing instruction with pre-decode information
 *   issue_pkt_v_o               - "ready-then-valid" interface
 *   issue_pkt_ready_i           - 
 * 
 *   chk_dispatch_v_o            - Dispatch signal to the calculator. Since the pipes are 
 *                                   non-blocking, this signal indicates that there will be no
 *                                   hazards from this point on
 *   chk_roll_o                  - Roll back all the instructions in the pipe
 *   chk_poison_iss_o            - Poison the instruction currently in issue stage
 *   chk_poison_isd_o            - Poison the instruction currently in ISD stage
 *   chk_poison_ex_o             - Poison all instructions currently in the pipe 
 *                                   prior to the commit point
 *
 * Keywords:
 *   Checker, speculation, dependencies, interface
 * 
 * Notes:
 *
 */

module bp_be_checker_top 
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p
                                ,paddr_width_p
                                ,asid_width_p
                                ,branch_metadata_fwd_width_p
                                )

   // Generated parameters
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp   = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)

   // VM parameters
   , localparam vtag_width_lp     = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp     = (paddr_width_p-bp_page_offset_width_gp)
   , localparam tlb_entry_width_lp = `bp_be_tlb_entry_width(ptag_width_lp)

   // CSRs
   , localparam mepc_width_lp  = `bp_mepc_width
   , localparam mtvec_width_lp = `bp_mtvec_width
   )
  (input                              clk_i
   , input                            reset_i
   , input                            freeze_i

   // Config channel
   , input                                   cfg_w_v_i
   , input [bp_cfg_link_addr_width_gp-1:0]   cfg_addr_i
   , input [bp_cfg_link_data_width_gp-1:0]   cfg_data_i

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]    fe_queue_i
   , input                            fe_queue_v_i
   , output                           fe_queue_ready_o

   , output                           chk_roll_fe_o
   , output                           chk_flush_fe_o
   , output                           chk_dequeue_fe_o

   // Instruction issue interface
   , output [issue_pkt_width_lp-1:0]  issue_pkt_o
   , output                           issue_pkt_v_o
   , input                            issue_pkt_ready_i

   // Dependency information
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
   , input [mtvec_width_lp-1:0]       mtvec_i
   , input [mepc_width_lp-1:0]        mepc_i
   , input                            tlb_fence_i
   
   //iTLB fill interface
    , input                           itlb_fill_v_i
    , input [vaddr_width_p-1:0]       itlb_fill_vaddr_i
    , input [tlb_entry_width_lp-1:0]  itlb_fill_entry_i
   );

// Declare parameterizable structures
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   ); 

// Intermediate connections
logic [vaddr_width_p-1:0] expected_npc;
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
   ,.expected_npc_o(expected_npc)
   ,.flush_o(flush)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)

   ,.chk_dequeue_fe_o(chk_dequeue_fe_o)
   ,.chk_roll_fe_o(chk_roll_fe_o)
   ,.chk_flush_fe_o(chk_flush_fe_o)

   ,.trap_v_i(trap_v_i)
   ,.ret_v_i(ret_v_i)
   ,.pc_o(pc_o)
   ,.mtvec_i(mtvec_i)
   ,.mepc_i(mepc_i)
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

   ,.expected_npc_i(expected_npc)
   ,.calc_status_i(calc_status_i)
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

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_ready_o(fe_queue_ready_o)

   ,.issue_pkt_o(issue_pkt_o)
   ,.issue_pkt_v_o(issue_pkt_v_o)
   ,.issue_pkt_ready_i(issue_pkt_ready_i)
   );

endmodule : bp_be_checker_top

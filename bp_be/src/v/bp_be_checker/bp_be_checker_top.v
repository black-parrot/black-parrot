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
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   , parameter load_to_use_forwarding_p = 1

   // Generated parameters
   , localparam calc_status_width_lp = `bp_be_calc_status_width(branch_metadata_fwd_width_p)
   , localparam fe_queue_width_lp    = `bp_fe_queue_width(vaddr_width_p
                                                          , branch_metadata_fwd_width_p
                                                          )
   , localparam fe_cmd_width_lp      = `bp_fe_cmd_width(vaddr_width_p
                                                        , paddr_width_p
                                                        , asid_width_p
                                                        , branch_metadata_fwd_width_p
                                                        )
   , localparam issue_pkt_width_lp   = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)

   // From BE specifications
   , localparam pc_entry_point_lp = bp_pc_entry_point_gp
   // From RISC-V specification
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp
   )
  (input                              clk_i
   , input                            reset_i

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

   // Checker pipeline control information
   , output                           chk_dispatch_v_o
   , output                           chk_roll_o
   , output                           chk_poison_isd_o
   , output                           chk_poison_ex1_o
   , output                           chk_poison_ex2_o
   , output                           chk_poison_ex3_o

   // CSR interface
   , input [reg_data_width_lp-1:0]    mtvec_i
   , input [reg_data_width_lp-1:0]    mepc_i

   , input cache_miss_mem3_i
   );

// Declare parameterizable structures
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   ); 

// Intermediate connections
logic [eaddr_width_lp-1:0] expected_npc;

logic                   pc_redirect_o;
   
// Datapath
bp_be_director 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   ) 
 director
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.calc_status_i(calc_status_i) 
   ,.expected_npc_o(expected_npc)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)

   ,.chk_dequeue_fe_o(chk_dequeue_fe_o)
   ,.chk_roll_fe_o(chk_roll_fe_o)
   ,.chk_flush_fe_o(chk_flush_fe_o)

   ,.mtvec_i(mtvec_i)
   ,.mepc_i(mepc_i)

   ,.pc_redirect_o(pc_redirect_o)
   );

bp_be_detector 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   ,.load_to_use_forwarding_p(load_to_use_forwarding_p)
   ) 
 detector
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.calc_status_i(calc_status_i)
   ,.mmu_cmd_ready_i(mmu_cmd_ready_i)
   ,.expected_npc_i(expected_npc)

   ,.chk_dispatch_v_o(chk_dispatch_v_o)
   ,.chk_roll_o(chk_roll_o)
   ,.chk_poison_isd_o(chk_poison_isd_o)
   ,.chk_poison_ex1_o(chk_poison_ex1_o)
   ,.chk_poison_ex2_o(chk_poison_ex2_o)
   ,.chk_poison_ex3_o(chk_poison_ex3_o)
   );

    
bp_be_scheduler 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   )
 scheduler
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_ready_o(fe_queue_ready_o)

   ,.pc_redirect_i(pc_redirect_o)
   
   ,.issue_pkt_o(issue_pkt_o)
   ,.issue_pkt_v_o(issue_pkt_v_o)
   ,.issue_pkt_ready_i(issue_pkt_ready_i)

   ,.cache_miss_mem3_i(cache_miss_mem3_i)
   );

endmodule : bp_be_checker_top

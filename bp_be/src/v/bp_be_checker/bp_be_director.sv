/**
 *
 * Name:
 *   bp_be_director.v
 *
 * Description:
 *   Directs the PC for the FE and the calculator. Keeps track of the next PC
 *     and sends redirect signals to the FE when a misprediction is detected.
 *
 * Notes:
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_director
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cfg_bus_width_lp-1:0]       cfg_bus_i

   // Dependency information
   , input [issue_pkt_width_lp-1:0]     issue_pkt_i
   , output logic [vaddr_width_p-1:0]   expected_npc_o
   , output logic                       poison_isd_o
   , output logic                       clear_iss_o
   , output logic                       suppress_iss_o
   , output logic                       resume_o
   , input                              irq_waiting_i
   , input                              mem_busy_i
   , output logic                       cmd_full_n_o
   , output logic                       cmd_full_r_o

   // FE-BE interface
   , output logic [fe_cmd_width_lp-1:0] fe_cmd_o
   , output logic                       fe_cmd_v_o
   , input                              fe_cmd_yumi_i

   , input [branch_pkt_width_lp-1:0]    br_pkt_i
   , input [commit_pkt_width_lp-1:0]    commit_pkt_i
   );

  // Declare parameterized structures
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);

  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  `bp_cast_i(bp_be_issue_pkt_s, issue_pkt);
  `bp_cast_i(bp_be_branch_pkt_s, br_pkt);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);

  bp_fe_cmd_s fe_cmd_li;
  bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
  logic fe_cmd_v_li;
  logic cmd_empty_n_lo, cmd_empty_r_lo;
  logic cmd_full_n_lo, cmd_full_r_lo;

  // Declare intermediate signals
  enum logic [3:0] {e_freeze, e_fencei, e_run, e_cmd_fence, e_wait} state_n, state_r;
  wire is_freeze    = (state_r == e_freeze);
  wire is_fencei    = (state_r == e_fencei);
  wire is_run       = (state_r == e_run);
  wire is_cmd_fence = (state_r == e_cmd_fence);
  wire is_wait      = (state_r == e_wait);

  // Module instantiations
  // Update the NPC on a valid instruction in ex1 or upon commit
  logic [vaddr_width_p-1:0] npc_n, npc_r;
  wire npc_w_v = commit_pkt_cast_i.npc_w_v | br_pkt_cast_i.v;

  assign npc_n = commit_pkt_cast_i.npc_w_v ? commit_pkt_cast_i.npc : br_pkt_cast_i.bspec ? issue_pkt_cast_i.pc : br_pkt_cast_i.npc;
  bsg_dff_reset_en_bypass
   #(.width_p(vaddr_width_p))
   npc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(npc_w_v)

     ,.data_i(npc_n)
     ,.data_o(npc_r)
     );
  assign expected_npc_o = npc_r;

  wire npc_mismatch_v = issue_pkt_cast_i.v & (expected_npc_o != issue_pkt_cast_i.pc);
  wire npc_match_v    = issue_pkt_cast_i.v & (expected_npc_o == issue_pkt_cast_i.pc);
  assign poison_isd_o = npc_mismatch_v;

  logic btaken_pending, attaboy_pending;
  bsg_dff_reset_set_clear
   #(.width_p(2), .clear_over_set_p(1))
   attaboy_pending_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({br_pkt_cast_i.btaken, br_pkt_cast_i.branch})
     ,.clear_i({fe_cmd_v_li, fe_cmd_v_li})
     ,.data_o({btaken_pending, attaboy_pending})
     );
  wire last_instr_was_branch = attaboy_pending | br_pkt_cast_i.branch;
  wire last_instr_was_btaken = btaken_pending  | br_pkt_cast_i.btaken;

  wire fe_cmd_nonattaboy_v = fe_cmd_v_li & (fe_cmd_li.opcode != e_op_attaboy);

  // Boot logic
  wire freeze_li = cfg_bus_cast_i.freeze | reset_i;
  always_comb
    begin
      unique casez (state_r)
        e_run   : state_n = freeze_li
                            ? e_freeze
                            : commit_pkt_cast_i.wfi
                              ? e_wait
                              : commit_pkt_cast_i.fencei
                                ? e_fencei
                                : fe_cmd_nonattaboy_v
                                  ? e_cmd_fence
                                  : state_r;
        e_freeze
        ,e_fencei
        ,e_wait : state_n = commit_pkt_cast_i.resume ? e_cmd_fence : state_r;
        // e_cmd_fence:
        default : state_n = cmd_empty_r_lo ? e_run : state_r;
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_freeze;
    else
      state_r <= state_n;

  assign suppress_iss_o = !is_run || cmd_full_r_lo || commit_pkt_cast_i.npc_w_v;
  assign clear_iss_o    = is_cmd_fence & cmd_empty_r_lo;
  assign resume_o       = (is_freeze & ~freeze_li)
                          || (is_wait & irq_waiting_i)
                          || (is_fencei & ~mem_busy_i);

  always_comb
    begin
      fe_cmd_li = 'b0;
      fe_cmd_v_li = 1'b0;
      fe_cmd_pc_redirect_operands = '0;

      if (commit_pkt_cast_i.resume)
        begin
          fe_cmd_li.opcode = is_freeze ? e_op_state_reset : is_fencei ? e_op_icache_fence : e_op_pc_redirection;
          fe_cmd_li.npc = npc_n;

          fe_cmd_pc_redirect_operands.priv           = commit_pkt_cast_i.priv_n;
          fe_cmd_pc_redirect_operands.translation_en = commit_pkt_cast_i.translation_en_n;
          fe_cmd_pc_redirect_operands.subopcode      = e_subop_resume;
          fe_cmd_li.operands.pc_redirect_operands    = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.itlb_fill_v)
        begin
          fe_cmd_li.opcode                               = e_op_itlb_fill_response;
          fe_cmd_li.npc                                  = commit_pkt_cast_i.vaddr;
          fe_cmd_li.operands.itlb_fill_response.pte_leaf = commit_pkt_cast_i.pte_leaf;
          fe_cmd_li.operands.itlb_fill_response.instr    = commit_pkt_cast_i.instr;
          fe_cmd_li.operands.itlb_fill_response.count    = commit_pkt_cast_i.count;

          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.sfence)
        begin
          fe_cmd_li.opcode = e_op_itlb_fence;
          fe_cmd_li.npc = commit_pkt_cast_i.npc;

          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.csrw)
        begin
          fe_cmd_li.opcode                            = e_op_pc_redirection;
          fe_cmd_li.npc                               = commit_pkt_cast_i.npc;
          fe_cmd_pc_redirect_operands.subopcode       = e_subop_translation_switch;
          fe_cmd_pc_redirect_operands.translation_en  = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands     = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.wfi)
        begin
          fe_cmd_li.opcode = e_op_wait;
          fe_cmd_li.npc = commit_pkt_cast_i.npc;

          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.icache_miss)
        begin
          fe_cmd_li.opcode                              = e_op_icache_fill_response;
          fe_cmd_li.npc                                 = commit_pkt_cast_i.vaddr;
          fe_cmd_li.operands.icache_fill_response.instr = commit_pkt_cast_i.instr;
          fe_cmd_li.operands.icache_fill_response.count = commit_pkt_cast_i.count;


          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.eret)
        begin
          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.npc                                    = commit_pkt_cast_i.npc;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_eret;
          fe_cmd_pc_redirect_operands.priv                 = commit_pkt_cast_i.priv_n;
          fe_cmd_pc_redirect_operands.translation_en       = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = 1'b1;
        end
      else if (commit_pkt_cast_i.exception | commit_pkt_cast_i._interrupt)
        begin
          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.npc                                    = commit_pkt_cast_i.npc;
          fe_cmd_pc_redirect_operands.subopcode            = commit_pkt_cast_i.exception ? e_subop_trap : e_subop_interrupt;
          fe_cmd_pc_redirect_operands.priv                 = commit_pkt_cast_i.priv_n;
          fe_cmd_pc_redirect_operands.translation_en       = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = 1'b1;
        end
      else if (npc_mismatch_v)
        begin
          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.npc                                    = expected_npc_o;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
          fe_cmd_pc_redirect_operands.branch_metadata_fwd  = issue_pkt_cast_i.branch_metadata_fwd;
          fe_cmd_pc_redirect_operands.misprediction_reason = last_instr_was_branch
                                                             ? last_instr_was_btaken
                                                               ? e_incorrect_pred_taken
                                                               : e_incorrect_pred_ntaken
                                                             : e_not_a_branch;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = 1'b1;
        end
      // Send an attaboy if there's a correct prediction
      else if (npc_match_v & last_instr_was_branch)
        begin
          fe_cmd_li.opcode                               = e_op_attaboy;
          fe_cmd_li.npc                                  = expected_npc_o;
          fe_cmd_li.operands.attaboy.taken               = last_instr_was_btaken;
          fe_cmd_li.operands.attaboy.branch_metadata_fwd = issue_pkt_cast_i.branch_metadata_fwd;

          fe_cmd_v_li = 1'b1;
        end
    end

  bp_be_cmd_queue
   #(.bp_params_p(bp_params_p))
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fe_cmd_i(fe_cmd_li)
     ,.fe_cmd_v_i(fe_cmd_v_li)

     ,.fe_cmd_o(fe_cmd_o)
     ,.fe_cmd_v_o(fe_cmd_v_o)
     ,.fe_cmd_yumi_i(fe_cmd_yumi_i)

     ,.empty_n_o(cmd_empty_n_lo)
     ,.empty_r_o(cmd_empty_r_lo)
     ,.full_n_o(cmd_full_n_lo)
     ,.full_r_o(cmd_full_r_lo)
     );
  assign cmd_full_n_o = cmd_full_n_lo;
  assign cmd_full_r_o = cmd_full_r_lo;

endmodule


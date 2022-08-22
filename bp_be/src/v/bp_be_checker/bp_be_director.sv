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

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam branch_pkt_width_lp = `bp_be_branch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cfg_bus_width_lp-1:0]       cfg_bus_i

   // Dependency information
   , input [isd_status_width_lp-1:0]    isd_status_i
   , output logic [vaddr_width_p-1:0]   expected_npc_o
   , output logic                       poison_isd_o
   , output logic                       suppress_iss_o
   , output logic                       unfreeze_o
   , input                              irq_waiting_i
   , output logic                       cmd_empty_n_o
   , output logic                       cmd_empty_r_o
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
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  `bp_cast_i(bp_be_isd_status_s, isd_status);
  `bp_cast_i(bp_be_branch_pkt_s, br_pkt);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);

  // Cast input and output ports
  bp_fe_cmd_s                      fe_cmd_li;
  logic                            fe_cmd_v_li, fe_cmd_ready_lo;
  bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;

  // Declare intermediate signals
  logic [vaddr_width_p-1:0]               npc_plus4;
  logic [vaddr_width_p-1:0]               npc_n, npc_r, pc_r;
  logic                                   npc_mismatch_v;

  enum logic [2:0] {e_freeze, e_run, e_fence, e_wait} state_n, state_r;
  wire is_freeze = (state_r == e_freeze);
  wire is_run    = (state_r == e_run);
  wire is_fence  = (state_r == e_fence);
  wire is_wait   = (state_r == e_wait);

  // Module instantiations
  // Update the NPC on a valid instruction in ex1 or upon commit
  wire npc_w_v = commit_pkt_cast_i.npc_w_v | br_pkt_cast_i.v;
  assign npc_n = commit_pkt_cast_i.npc_w_v ? commit_pkt_cast_i.npc : br_pkt_cast_i.npc;
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p))
   npc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(npc_w_v)

     ,.data_i(npc_n)
     ,.data_o(npc_r)
     );
  assign expected_npc_o = npc_w_v ? npc_n : npc_r;

  assign npc_mismatch_v = isd_status_cast_i.v & (expected_npc_o != isd_status_cast_i.pc);
  assign poison_isd_o = commit_pkt_cast_i.npc_w_v | npc_mismatch_v;

  logic btaken_pending, attaboy_pending;
  bsg_dff_reset_set_clear
   #(.width_p(2), .clear_over_set_p(1))
   attaboy_pending_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({br_pkt_cast_i.btaken, br_pkt_cast_i.branch})
     ,.clear_i({isd_status_cast_i.v, isd_status_cast_i.v})
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
        e_wait  : state_n = fe_cmd_nonattaboy_v ? e_fence : e_wait;
        e_run   : state_n = commit_pkt_cast_i.wfi ? e_wait : fe_cmd_nonattaboy_v ? e_fence : e_run;
        e_fence : state_n = cmd_empty_n_o ? e_run : e_fence;
        // e_freeze:
        default : state_n = freeze_li ? e_freeze : e_wait;
      endcase
    end

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
        state_r <= e_freeze;
    else
      begin
        state_r <= state_n;
      end

  assign suppress_iss_o  = (state_r != e_run);
  assign unfreeze_o      = (state_r == e_freeze) & ~freeze_li;

  always_comb
    begin
      fe_cmd_li = 'b0;
      fe_cmd_v_li = 1'b0;
      fe_cmd_pc_redirect_operands = '0;

      if (commit_pkt_cast_i.unfreeze)
        begin
          fe_cmd_li.opcode = e_op_state_reset;
          fe_cmd_li.npc = npc_r;

          fe_cmd_pc_redirect_operands.priv           = commit_pkt_cast_i.priv_n;
          fe_cmd_pc_redirect_operands.translation_en = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands    = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.itlb_fill_v)
        begin
          // TODO: restart vs resume
          fe_cmd_li.opcode                               = e_op_itlb_fill_restart;
          fe_cmd_li.npc                                  = commit_pkt_cast_i.npc;
          fe_cmd_li.operands.itlb_fill_response.pte_leaf = commit_pkt_cast_i.pte_leaf;
          fe_cmd_li.operands.itlb_fill_response.instr    = commit_pkt_cast_i.instr;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.sfence)
        begin
          fe_cmd_li.opcode = e_op_itlb_fence;
          fe_cmd_li.npc = commit_pkt_cast_i.npc;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.csrw)
        begin
          fe_cmd_li.opcode                            = e_op_pc_redirection;
          fe_cmd_li.npc                               = commit_pkt_cast_i.npc;
          fe_cmd_pc_redirect_operands.subopcode       = e_subop_translation_switch;
          fe_cmd_pc_redirect_operands.translation_en  = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands     = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.wfi)
        begin
          fe_cmd_li.opcode = e_op_wait;
          fe_cmd_li.npc = commit_pkt_cast_i.npc;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.fencei)
        begin
          fe_cmd_li.opcode = e_op_icache_fence;
          fe_cmd_li.npc = commit_pkt_cast_i.npc;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.icache_miss)
        begin
          // TODO: restart vs resume
          fe_cmd_li.opcode = e_op_icache_fill_restart;
          fe_cmd_li.npc = commit_pkt_cast_i.npc;
          fe_cmd_li.operands.icache_fill_response.instr = commit_pkt_cast_i.instr;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.eret)
        begin
          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.npc                                    = commit_pkt_cast_i.npc;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_eret;
          fe_cmd_pc_redirect_operands.priv                 = commit_pkt_cast_i.priv_n;
          fe_cmd_pc_redirect_operands.translation_en       = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (commit_pkt_cast_i.exception | commit_pkt_cast_i._interrupt | (is_wait & irq_waiting_i))
        begin
          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.npc                                    = commit_pkt_cast_i.npc;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_trap;
          fe_cmd_pc_redirect_operands.priv                 = commit_pkt_cast_i.priv_n;
          fe_cmd_pc_redirect_operands.translation_en       = commit_pkt_cast_i.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (isd_status_cast_i.v & npc_mismatch_v)
        begin
          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.npc                                    = expected_npc_o;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
          fe_cmd_pc_redirect_operands.branch_metadata_fwd  = isd_status_cast_i.branch_metadata_fwd;
          fe_cmd_pc_redirect_operands.misprediction_reason = last_instr_was_branch
                                                             ? last_instr_was_btaken
                                                               ? e_incorrect_pred_taken
                                                               : e_incorrect_pred_ntaken
                                                             : e_not_a_branch;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      // Send an attaboy if there's a correct prediction
      else if (isd_status_cast_i.v & ~npc_mismatch_v & last_instr_was_branch)
        begin
          fe_cmd_li.opcode                               = e_op_attaboy;
          fe_cmd_li.npc                                  = expected_npc_o;
          fe_cmd_li.operands.attaboy.taken               = last_instr_was_btaken;
          fe_cmd_li.operands.attaboy.branch_metadata_fwd = isd_status_cast_i.branch_metadata_fwd;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
    end

  bp_be_cmd_queue
   #(.bp_params_p(bp_params_p))
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fe_cmd_i(fe_cmd_li)
     ,.fe_cmd_v_i(fe_cmd_v_li)
     ,.fe_cmd_ready_o(fe_cmd_ready_lo)

     ,.fe_cmd_o(fe_cmd_o)
     ,.fe_cmd_v_o(fe_cmd_v_o)
     ,.fe_cmd_yumi_i(fe_cmd_yumi_i)

     ,.empty_n_o(cmd_empty_n_o)
     ,.empty_r_o(cmd_empty_r_o)
     ,.full_n_o(cmd_full_n_o)
     ,.full_r_o(cmd_full_r_o)
     );

endmodule


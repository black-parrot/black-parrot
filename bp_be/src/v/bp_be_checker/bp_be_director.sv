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
 *   Branch_metadata should come from the target instruction, not the branch instruction,
 *     eliminating the need to store this in the BE
 *   We don't currently support MTVAL or EPC, so error muxes are disconnected
 *   FE cmd adapter could be split into a separate module
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
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam branch_pkt_width_lp = `bp_be_branch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p)

   , localparam debug_lp = 0
   )
  (input                              clk_i
   , input                            reset_i

   , input [cfg_bus_width_lp-1:0]     cfg_bus_i

   // Dependency information
   , input [isd_status_width_lp-1:0]  isd_status_i
   , output [vaddr_width_p-1:0]       expected_npc_o
   , output                           poison_isd_o
   , output                           suppress_iss_o

   , output logic                     flush_o

   // FE-BE interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_yumi_i
   , output                           fe_cmd_full_o

   , input [branch_pkt_width_lp-1:0]   br_pkt_i
   , input [commit_pkt_width_lp-1:0]   commit_pkt_i

   , input [ptw_fill_pkt_width_lp-1:0] ptw_fill_pkt_i
  );

  // Declare parameterized structures
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Cast input and output ports
  bp_cfg_bus_s                     cfg_bus_cast_i;
  bp_be_isd_status_s               isd_status_cast_i;
  bp_fe_cmd_s                      fe_cmd_li;
  logic                            fe_cmd_v_li, fe_cmd_ready_lo;
  bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
  bp_be_branch_pkt_s               br_pkt;
  bp_be_commit_pkt_s               commit_pkt;
  bp_be_ptw_fill_pkt_s             ptw_fill_pkt;

  assign cfg_bus_cast_i = cfg_bus_i;
  assign isd_status_cast_i = isd_status_i;
  assign commit_pkt = commit_pkt_i;
  assign br_pkt       = br_pkt_i;
  assign ptw_fill_pkt = ptw_fill_pkt_i;

  // Declare intermediate signals
  logic [vaddr_width_p-1:0]               npc_plus4;
  logic [vaddr_width_p-1:0]               npc_n, npc_r, pc_r;
  logic                                   npc_mismatch_v;

  // Logic for handling coming out of reset
  enum logic [1:0] {e_reset, e_boot, e_run, e_fence} state_n, state_r;

  // Module instantiations
  // Update the NPC on a valid instruction in ex1 or a cache miss or a tlb miss
  wire npc_w_v = br_pkt.v | commit_pkt.v | ptw_fill_pkt.itlb_fill_v;
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p), .reset_val_p($unsigned(boot_pc_p)))
   npc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(npc_w_v)

     ,.data_i(npc_n)
     ,.data_o(npc_r)
     );
  assign npc_n = ptw_fill_pkt.itlb_fill_v ? ptw_fill_pkt.vaddr : commit_pkt.v ? commit_pkt.npc : br_pkt.npc;

  assign npc_mismatch_v = isd_status_cast_i.v & (expected_npc_o != isd_status_cast_i.pc);
  assign poison_isd_o = npc_mismatch_v | flush_o;

  logic btaken_pending, attaboy_pending;
  bsg_dff_reset_set_clear
   #(.width_p(2), .clear_over_set_p(1))
   attaboy_pending_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({br_pkt.btaken, br_pkt.branch})
     ,.clear_i({isd_status_cast_i.v, isd_status_cast_i.v})
     ,.data_o({btaken_pending, attaboy_pending})
     );
  wire last_instr_was_branch = attaboy_pending | br_pkt.branch;
  wire last_instr_was_btaken = btaken_pending  | br_pkt.btaken;

  // Generate control signals
  // On a cache miss, this is actually the generated pc in ex1. We could use this to redirect during
  //   mispredict-under-cache-miss. However, there's a critical path vs extra speculation argument.
  //   Currently, we just don't send pc redirects under a cache miss.
  wire fe_cmd_nonattaboy_v = fe_cmd_v_li & (fe_cmd_li.opcode != e_op_attaboy);
  assign expected_npc_o = npc_w_v ? npc_n : npc_r;

  // Boot logic
  always_comb
    begin
      unique casez (state_r)
        e_reset : state_n = cfg_bus_cast_i.freeze ? e_reset : e_boot;
        e_boot  : state_n = fe_cmd_v_li ? e_run : e_boot;
        e_run   : state_n = cfg_bus_cast_i.freeze ? e_reset : fe_cmd_nonattaboy_v ? e_fence : e_run;
        e_fence : state_n = suppress_iss_o ? e_fence : e_run;
        default : state_n = e_reset;
      endcase
    end

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
        state_r <= e_reset;
    else
      begin
        state_r <= state_n;
      end

  assign suppress_iss_o  = (state_r == e_fence) & fe_cmd_v_o;

  // Flush on FE cmds which are not attaboys.  Also don't flush the entire pipeline on a mispredict.
  always_comb
    begin : fe_cmd_adapter
      fe_cmd_li = 'b0;
      fe_cmd_v_li = 1'b0;
      flush_o = 1'b0;

      // Do not send anything on reset
      if (state_r == e_reset)
        begin
          fe_cmd_v_li = 1'b0;
        end
      // Send one reset cmd on boot
      else if (state_r == e_boot)
        begin
          fe_cmd_li.opcode = e_op_state_reset;
          fe_cmd_li.vaddr  = npc_r;

          fe_cmd_pc_redirect_operands = '0;
          fe_cmd_pc_redirect_operands.priv                = commit_pkt.priv_n;
          fe_cmd_pc_redirect_operands.translation_enabled = commit_pkt.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
      else if (ptw_fill_pkt.itlb_fill_v)
        begin
          fe_cmd_li.opcode                                     = e_op_itlb_fill_response;
          fe_cmd_li.vaddr                                      = ptw_fill_pkt.vaddr;
          fe_cmd_li.operands.itlb_fill_response.pte_entry_leaf = ptw_fill_pkt.entry;

          fe_cmd_v_li = fe_cmd_ready_lo;

          flush_o = 1'b1;
        end
      else if (commit_pkt.sfence)
        begin
          fe_cmd_li.opcode = e_op_itlb_fence;
          fe_cmd_li.vaddr  = commit_pkt.npc;

          fe_cmd_v_li = fe_cmd_ready_lo;

          flush_o = 1'b1;
        end
      else if (commit_pkt.satp)
        begin
          fe_cmd_pc_redirect_operands = '0;

          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.vaddr                                  = commit_pkt.npc;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_translation_switch;
          fe_cmd_pc_redirect_operands.translation_enabled  = commit_pkt.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;

          flush_o = 1'b1;
        end
      else if (commit_pkt.fencei)
        begin
          fe_cmd_li.opcode = e_op_icache_fence;
          fe_cmd_li.vaddr  = commit_pkt.npc;

          fe_cmd_v_li = fe_cmd_ready_lo;

          flush_o = 1'b1;
        end
      else if (commit_pkt.icache_miss)
        begin
          fe_cmd_li.opcode = e_op_icache_fill_response;
          fe_cmd_li.vaddr  = commit_pkt.npc;

          fe_cmd_v_li = fe_cmd_ready_lo;

          flush_o = 1'b1;
        end
      // Redirect the pc if there's an NPC mismatch
      // Should not lump trap and ret into branch misprediction
      else if (commit_pkt.exception | commit_pkt._interrupt | commit_pkt.eret)
        begin
          fe_cmd_pc_redirect_operands = '0;

          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.vaddr                                  = npc_n;
          // TODO: Fill in missing subopcodes.  They're not used by FE yet...
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_trap;
          fe_cmd_pc_redirect_operands.branch_metadata_fwd  = '0;
          fe_cmd_pc_redirect_operands.misprediction_reason = e_not_a_branch;
          fe_cmd_pc_redirect_operands.priv                 = commit_pkt.priv_n;
          fe_cmd_pc_redirect_operands.translation_enabled  = commit_pkt.translation_en_n;
          fe_cmd_li.operands.pc_redirect_operands          = fe_cmd_pc_redirect_operands;

          fe_cmd_v_li = fe_cmd_ready_lo;

          flush_o = 1'b1;
        end
      else if (commit_pkt.rollback)
        begin
          flush_o = 1'b1;
        end
      else if (isd_status_cast_i.v & npc_mismatch_v)
        begin
          fe_cmd_pc_redirect_operands = '0;

          fe_cmd_li.opcode                                 = e_op_pc_redirection;
          fe_cmd_li.vaddr                                  = expected_npc_o;
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
          fe_cmd_li.vaddr                                = expected_npc_o;
          fe_cmd_li.operands.attaboy.taken               = last_instr_was_btaken;
          fe_cmd_li.operands.attaboy.branch_metadata_fwd = isd_status_cast_i.branch_metadata_fwd;

          fe_cmd_v_li = fe_cmd_ready_lo;
        end
    end

  bsg_fifo_1r1w_small
   #(.width_p(fe_cmd_width_lp)
     ,.els_p(fe_cmd_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(fe_cmd_li)
     ,.v_i(fe_cmd_v_li)
     ,.ready_o(fe_cmd_ready_lo)

     ,.data_o(fe_cmd_o)
     ,.v_o(fe_cmd_v_o)
     ,.yumi_i(fe_cmd_yumi_i)
     );
  assign fe_cmd_full_o = ~fe_cmd_ready_lo;

endmodule


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
 *   We don't need the entirety of the calc_status structure here, but for simplicity
 *     we pass it all. If the compiler doesn't flatten and optimize, we can do it ourselves.
 *   Branch_metadata should come from the target instruction, not the branch instruction,
 *     eliminating the need to store this in the BE
 *   We don't currently support MTVAL or EPC, so error muxes are disconnected
 *   FE cmd adapter could be split into a separate module
 */

module bp_be_director
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p)
   , localparam trap_pkt_width_lp    = `bp_be_trap_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p)

   , localparam debug_lp = 0
   )
  (input                              clk_i
   , input                            reset_i

   , input [cfg_bus_width_lp-1:0]     cfg_bus_i

   // Dependency information
   , input [isd_status_width_lp-1:0]  isd_status_i
   , input [calc_status_width_lp-1:0] calc_status_i
   , output [vaddr_width_p-1:0]       expected_npc_o
   , output                           poison_isd_o
   , output logic                     flush_o

   // FE-BE interface
   , output [fe_cmd_width_lp-1:0]     fe_cmd_o
   , output                           fe_cmd_v_o
   , input                            fe_cmd_ready_i
   , input                            fe_cmd_fence_i

   , output                           suppress_iss_o

   , input [trap_pkt_width_lp-1:0]    trap_pkt_i

   , input [ptw_fill_pkt_width_lp-1:0] ptw_fill_pkt_i
  );

  // Declare parameterized structures
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Cast input and output ports
  bp_cfg_bus_s                     cfg_bus_cast_i;
  bp_be_isd_status_s               isd_status;
  bp_be_calc_status_s              calc_status;
  bp_fe_cmd_s                      fe_cmd;
  logic                            fe_cmd_v;
  bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
  bp_be_trap_pkt_s                 trap_pkt;
  bp_be_ptw_fill_pkt_s             ptw_fill_pkt;

  assign cfg_bus_cast_i = cfg_bus_i;
  assign isd_status = isd_status_i;
  assign calc_status = calc_status_i;
  assign fe_cmd_o    = fe_cmd;
  assign fe_cmd_v_o  = fe_cmd_v;
  assign trap_pkt    = trap_pkt_i;
  assign ptw_fill_pkt = ptw_fill_pkt_i;

  // Declare intermediate signals
  logic [vaddr_width_p-1:0]               npc_plus4;
  logic [vaddr_width_p-1:0]               npc_n, npc_r, pc_r;
  logic                                   npc_mismatch_v;

  // Logic for handling coming out of reset
  enum logic [1:0] {e_reset, e_boot, e_run, e_fence} state_n, state_r;

  // Control signals
  logic npc_w_v, btaken_pending, attaboy_pending;

  // Module instantiations
  // Update the NPC on a valid instruction in ex1 or a cache miss or a tlb miss
  assign npc_w_v = calc_status.ex1_instr_v
                   | (trap_pkt.rollback | trap_pkt.exception | trap_pkt._interrupt | trap_pkt.eret | trap_pkt.fencei);
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p), .reset_val_p($unsigned(boot_pc_p)))
   npc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(npc_w_v)

     ,.data_i(npc_n)
     ,.data_o(npc_r)
     );

  bsg_mux
   #(.width_p(vaddr_width_p)
     ,.els_p(2)
     )
   trap_mux
    (.data_i({trap_pkt.npc, calc_status.ex1_npc})
     ,.sel_i(trap_pkt.rollback | trap_pkt.exception | trap_pkt._interrupt | trap_pkt.eret | trap_pkt.fencei)
     ,.data_o(npc_n)
     );

  assign npc_mismatch_v = isd_status.isd_v & (expected_npc_o != isd_status.isd_pc);
  assign poison_isd_o = npc_mismatch_v | flush_o;

  // Last operation was branch. Was it successful? Let's find out
  // TODO: I think this is wrong, may send extra attaboys
  bsg_dff_reset_en
   #(.width_p(2))
   attaboy_pending_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(calc_status.ex1_v || isd_status.isd_v)

     ,.data_i({(calc_status.ex1_v & calc_status.ex1_btaken) & ~isd_status.isd_v, (calc_status.ex1_v & calc_status.ex1_br_or_jmp) & ~isd_status.isd_v})
     ,.data_o({btaken_pending, attaboy_pending})
     );
  wire last_instr_was_branch = attaboy_pending | (calc_status.ex1_v & calc_status.ex1_br_or_jmp);
  wire last_instr_was_btaken = btaken_pending | (calc_status.ex1_v & calc_status.ex1_btaken);

  // Generate control signals
  // On a cache miss, this is actually the generated pc in ex1. We could use this to redirect during
  //   mispredict-under-cache-miss. However, there's a critical path vs extra speculation argument.
  //   Currently, we just don't send pc redirects under a cache miss.
  assign expected_npc_o = npc_w_v ? npc_n : npc_r;

  wire fe_cmd_nonattaboy_v = fe_cmd_v_o & (fe_cmd.opcode != e_op_attaboy);
  // Boot logic
  always_comb
    begin
      unique casez (state_r)
        e_reset : state_n = cfg_bus_cast_i.freeze ? e_reset : e_boot;
        e_boot  : state_n = fe_cmd_v ? e_run : e_boot;
        e_run   : state_n = cfg_bus_cast_i.freeze ? e_reset : fe_cmd_nonattaboy_v ? e_fence : e_run;
        e_fence : state_n = fe_cmd_fence_i ? e_fence : e_run;
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

  assign suppress_iss_o = (state_r == e_fence) & fe_cmd_fence_i;

  // Flush on FE cmds which are not attaboys.  Also don't flush the entire pipeline on a mispredict.
  always_comb
    begin : fe_cmd_adapter
      fe_cmd = 'b0;
      fe_cmd_v = 1'b0;
      flush_o = 1'b0;

      // Do not send anything on reset
      if (state_r == e_reset)
        begin
          fe_cmd_v = 1'b0;
        end
      // Send one reset cmd on boot
      else if (state_r == e_boot)
        begin
          fe_cmd.opcode = e_op_state_reset;
          fe_cmd.vaddr  = npc_r;

          fe_cmd_pc_redirect_operands = '0;
          fe_cmd_pc_redirect_operands.priv                = trap_pkt.priv_n;
          fe_cmd_pc_redirect_operands.translation_enabled = trap_pkt.translation_en_n;
          fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;

          fe_cmd_v = fe_cmd_ready_i;
        end
      else if (ptw_fill_pkt.itlb_fill_v)
        begin
          fe_cmd.opcode                                     = e_op_itlb_fill_response;
          fe_cmd.vaddr                                      = ptw_fill_pkt.vaddr;
          fe_cmd.operands.itlb_fill_response.pte_entry_leaf = ptw_fill_pkt.entry;

          fe_cmd_v = fe_cmd_ready_i;

          flush_o = 1'b1;
        end
      // TODO: This is compliant but suboptimal, since satp is not required to flush TLBs
      //   Should add message to fe-be interface
      else if (trap_pkt.sfence)
        begin
          fe_cmd.opcode = e_op_itlb_fence;
          fe_cmd.vaddr  = trap_pkt.npc;

          fe_cmd_pc_redirect_operands = '0;
          fe_cmd_pc_redirect_operands.translation_enabled = trap_pkt.translation_en_n;
          fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;

          fe_cmd_v      = fe_cmd_ready_i;

          flush_o = 1'b1;
        end
      else if (trap_pkt.satp)
        begin
          fe_cmd_pc_redirect_operands = '0;

          fe_cmd.opcode                                    = e_op_pc_redirection;
          fe_cmd.vaddr                                     = trap_pkt.npc;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_translation_switch;
          fe_cmd_pc_redirect_operands.translation_enabled  = trap_pkt.translation_en_n;
          fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

          fe_cmd_v = fe_cmd_ready_i;

          flush_o = 1'b1;
        end
      else if (trap_pkt.fencei)
        begin
          fe_cmd.opcode = e_op_icache_fence;
          fe_cmd.vaddr  = trap_pkt.npc;

          fe_cmd_v = fe_cmd_ready_i;

          flush_o = 1'b1;
        end
      // Redirect the pc if there's an NPC mismatch
      // Should not lump trap and ret into branch misprediction
      else if (trap_pkt.exception | trap_pkt._interrupt | trap_pkt.eret)
        begin
          fe_cmd_pc_redirect_operands = '0;

          fe_cmd.opcode                                    = e_op_pc_redirection;
          fe_cmd.vaddr                                     = npc_n;
          // TODO: Fill in missing subopcodes.  They're not used by FE yet...
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_trap;
          fe_cmd_pc_redirect_operands.branch_metadata_fwd  = '0;
          fe_cmd_pc_redirect_operands.misprediction_reason = e_not_a_branch;
          fe_cmd_pc_redirect_operands.priv                 = trap_pkt.priv_n;
          fe_cmd_pc_redirect_operands.translation_enabled  = trap_pkt.translation_en_n;
          fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

          fe_cmd_v = fe_cmd_ready_i;

          flush_o = 1'b1;
        end
      else if (trap_pkt.rollback)
        begin
          flush_o = 1'b1;
        end
      else if (isd_status.isd_v & npc_mismatch_v)
        begin
          fe_cmd_pc_redirect_operands = '0;

          fe_cmd.opcode                                    = e_op_pc_redirection;
          fe_cmd.vaddr                                     = expected_npc_o;
          fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
          fe_cmd_pc_redirect_operands.branch_metadata_fwd  = isd_status.isd_branch_metadata_fwd;
          // TODO: Add not a branch case
          fe_cmd_pc_redirect_operands.misprediction_reason = last_instr_was_branch
                                                             ? last_instr_was_btaken
                                                               ? e_incorrect_pred_taken
                                                               : e_incorrect_pred_ntaken
                                                             : e_not_a_branch;
          fe_cmd.operands.pc_redirect_operands             = fe_cmd_pc_redirect_operands;

          fe_cmd_v = fe_cmd_ready_i;
        end
      // Send an attaboy if there's a correct prediction
      else if (isd_status.isd_v & ~npc_mismatch_v & last_instr_was_branch)
        begin
          fe_cmd.opcode                      = e_op_attaboy;
          fe_cmd.vaddr                       = expected_npc_o;
          fe_cmd.operands.attaboy.taken               = last_instr_was_btaken;
          fe_cmd.operands.attaboy.branch_metadata_fwd = isd_status.isd_branch_metadata_fwd;

          fe_cmd_v = fe_cmd_ready_i;
        end
    end

  //synopsys translate_off
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p);
  bp_fe_branch_metadata_fwd_s attaboy_md;
  bp_fe_branch_metadata_fwd_s redir_md;

  assign attaboy_md = fe_cmd.operands.attaboy.branch_metadata_fwd;
  assign redir_md = fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd;

  always_ff @(negedge clk_i)
    if (debug_lp) begin
      if (fe_cmd_v_o & (fe_cmd.opcode == e_op_pc_redirection))
        $display("[REDIR  ] %x->%x %p", isd_status.isd_pc, fe_cmd.vaddr, redir_md);
      else if (fe_cmd_v_o & (fe_cmd.opcode == e_op_attaboy))
        $display("[ATTABOY] %x %p", fe_cmd.vaddr, attaboy_md);
      else if (isd_status.isd_v)
        $display("[FETCH  ] %x   ", isd_status.isd_pc);
    end
  //synopsys translate_on

endmodule


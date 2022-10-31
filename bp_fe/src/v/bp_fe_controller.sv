/*
 * bp_fe_controller.v
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_controller
 import bp_fe_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache)

   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output logic                                     fe_cmd_yumi_o

   , output logic                                     redirect_v_o
   , output logic [vaddr_width_p-1:0]                 redirect_pc_o
   , output logic                                     redirect_br_v_o
   , output logic                                     redirect_br_taken_o
   , output logic                                     redirect_br_ntaken_o
   , output logic                                     redirect_br_nonbr_o
   , output logic [branch_metadata_fwd_width_p-1:0]   redirect_br_metadata_fwd_o
   , output logic                                     redirect_resume_v_o
   , output logic [instr_half_width_gp-1:0]           redirect_resume_instr_o

   , output logic [vaddr_width_p-1:0]                 attaboy_pc_o
   , output logic                                     attaboy_taken_o
   , output logic                                     attaboy_ntaken_o
   , output logic [branch_metadata_fwd_width_p-1:0]   attaboy_br_metadata_fwd_o
   , output logic                                     attaboy_v_o
   , input                                            attaboy_yumi_i

   , input                                            pc_gen_init_done_i
   , input [vaddr_width_p-1:0]                        next_pc_i
   , input                                            ovr_i
   , input                                            icache_tv_we_i
   , output logic                                     if1_we_o
   , output logic                                     if2_we_o
   , output logic                                     poison_if1_o
   , output logic                                     poison_if2_o
   , input                                            fetch_exception_yumi_i

   , output logic                                     itlb_r_v_o
   , output logic                                     itlb_w_v_o
   , output logic                                     itlb_flush_v_o
   , output logic                                     icache_v_o
   , output logic                                     icache_force_o
   , output logic [icache_pkt_width_lp-1:0]           icache_pkt_o
   , input                                            icache_yumi_i

   , output logic                                     shadow_priv_w_o
   , output logic [rv64_priv_width_gp-1:0]            shadow_priv_o

   , output logic                                     shadow_translation_en_w_o
   , output logic                                     shadow_translation_en_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  `bp_cast_i(bp_fe_cmd_s, fe_cmd);
  `bp_cast_o(bp_fe_icache_pkt_s, icache_pkt);

  // FSM
  enum logic [2:0] {e_reset, e_wait, e_run, e_fence, e_resume} state_n, state_r;

  // Decoded state signals
  wire is_reset    = (state_r == e_reset);
  wire is_wait     = (state_r == e_wait);
  wire is_run      = (state_r == e_run);
  wire is_fence    = (state_r == e_fence);
  wire is_resume   = (state_r == e_resume);

  wire state_reset_v          = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_state_reset);
  wire pc_redirect_v          = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_pc_redirection);
  wire icache_fill_response_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode inside {e_op_icache_fill_restart, e_op_icache_fill_resume});
  wire icache_fill_resume_v   = compressed_support_p & fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fill_resume);
  wire wait_v                 = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_wait);

  wire itlb_fill_response_v   = fe_cmd_v_i & (fe_cmd_cast_i.opcode inside {e_op_itlb_fill_restart, e_op_itlb_fill_resume});
  wire itlb_fill_resume_v     = compressed_support_p & fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fill_resume);
  wire icache_fence_v         = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fence);
  wire itlb_fence_v           = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fence);

  wire br_miss_v     = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_branch_mispredict);
  wire eret_v        = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_eret);
  wire interrupt_v   = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_interrupt);
  wire trap_v        = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_trap);
  wire translation_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_translation_switch);
  // Unsupported
  //wire context_v     = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_context_swi

  wire br_miss_taken = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_pred_taken);
  wire br_miss_ntaken = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_pred_ntaken);
  wire br_miss_nonbr = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_not_a_branch);

  wire attaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_attaboy);

  wire cmd_nonreset_v   = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_state_reset);
  wire cmd_nonattaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_attaboy);
  wire cmd_immediate_v  = fe_cmd_v_i & (pc_redirect_v | icache_fill_response_v | wait_v);
  wire cmd_complex_v    = fe_cmd_v_i & ~cmd_immediate_v & cmd_nonattaboy_v;

  assign redirect_v_o               = ~attaboy_v & fe_cmd_yumi_o;
  assign redirect_pc_o              = fe_cmd_cast_i.npc;
  assign redirect_br_v_o            = br_miss_v;
  assign redirect_br_taken_o        = br_miss_taken;
  assign redirect_br_ntaken_o       = br_miss_ntaken;
  assign redirect_br_nonbr_o        = br_miss_nonbr;
  assign redirect_br_metadata_fwd_o = fe_cmd_cast_i.operands.pc_redirect_operands.branch_metadata_fwd;

  assign attaboy_v_o               = attaboy_v;
  assign attaboy_pc_o              = fe_cmd_cast_i.npc;
  assign attaboy_taken_o           = attaboy_v &  fe_cmd_cast_i.operands.attaboy.taken;
  assign attaboy_ntaken_o          = attaboy_v & ~fe_cmd_cast_i.operands.attaboy.taken;
  assign attaboy_br_metadata_fwd_o = fe_cmd_cast_i.operands.attaboy.branch_metadata_fwd;

  assign fe_cmd_yumi_o = (cmd_nonattaboy_v & if1_we_o) || attaboy_yumi_i || (is_reset && cmd_nonreset_v);

  assign shadow_priv_w_o = state_reset_v | trap_v | interrupt_v | eret_v;
  assign shadow_priv_o = fe_cmd_cast_i.operands.pc_redirect_operands.priv;

  assign shadow_translation_en_w_o = state_reset_v | trap_v | interrupt_v | eret_v | translation_v;
  assign shadow_translation_en_o = fe_cmd_cast_i.operands.pc_redirect_operands.translation_en;

  assign icache_pkt_cast_o =
    '{vaddr: next_pc_i
      ,op  : is_fence ? e_icache_fencei : e_icache_fetch
      ,spec: !icache_fill_response_v && !is_fence
      };
  assign icache_force_o = cmd_nonattaboy_v;
  assign poison_if1_o = fetch_exception_yumi_i;
  assign poison_if2_o = fetch_exception_yumi_i
    | ovr_i
    | cmd_immediate_v
    | (~is_resume & cmd_complex_v);

  assign redirect_resume_v_o = itlb_fill_resume_v | icache_fill_resume_v;
  assign redirect_resume_instr_o = itlb_fill_response_v ? fe_cmd_cast_i.operands.itlb_fill_response.instr : fe_cmd_cast_i.operands.icache_fill_response.instr;

  always_comb
    begin
      state_n = state_r;
      if1_we_o = 1'b0;
      if2_we_o = icache_tv_we_i;
      icache_v_o = 1'b0;
      itlb_r_v_o = 1'b0;
      itlb_w_v_o = 1'b0;
      itlb_flush_v_o = 1'b0;

      case (state_r)
        e_reset:
          begin
            state_n = (state_reset_v && pc_gen_init_done_i) ? e_resume : e_reset;
          end
        e_wait, e_run:
          begin
            icache_v_o = (is_run & ~cmd_complex_v) || (is_wait && cmd_immediate_v);
            if1_we_o = icache_yumi_i & ~cmd_complex_v;
            itlb_r_v_o = icache_yumi_i;
            itlb_w_v_o = itlb_fill_response_v;
            itlb_flush_v_o = itlb_fence_v;
            state_n = wait_v
                      ? e_wait
                      : icache_fence_v
                        ? e_fence
                        : cmd_complex_v
                          ? e_resume
                          : fetch_exception_yumi_i
                            ? e_wait
                            : if1_we_o
                              ? e_run
                              : state_r;
          end
        e_resume:
          begin
            icache_v_o = fe_cmd_v_i;
            if1_we_o = icache_yumi_i;
            itlb_r_v_o = icache_yumi_i;
            state_n = if1_we_o ? e_run : e_resume;
          end
        e_fence:
          begin
            icache_v_o = fe_cmd_v_i;
            state_n = icache_yumi_i ? e_resume : e_fence;
          end
        default: begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
        state_r <= e_reset;
    else
      begin
        state_r <= state_n;
      end

endmodule


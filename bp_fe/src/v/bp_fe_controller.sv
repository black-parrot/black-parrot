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

   , localparam pte_leaf_width_lp = `bp_pte_leaf_width(paddr_width_p)
   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input                                            pc_gen_init_done_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output logic                                     fe_cmd_yumi_o

   , output logic [fe_queue_width_lp-1:0]             fe_queue_o
   , output logic                                     fe_queue_v_o
   , input                                            fe_queue_ready_and_i

   , output logic                                     redirect_v_o
   , output logic [vaddr_width_p-1:0]                 redirect_pc_o
   , output logic [vaddr_width_p-1:0]                 redirect_npc_o
   , output logic [cinstr_width_gp-1:0]               redirect_instr_o
   , output logic                                     redirect_resume_o
   , output logic                                     redirect_br_v_o
   , output logic                                     redirect_br_taken_o
   , output logic                                     redirect_br_ntaken_o
   , output logic                                     redirect_br_nonbr_o
   , output logic [branch_metadata_fwd_width_p-1:0]   redirect_br_metadata_fwd_o

   , output logic                                     attaboy_v_o
   , output logic                                     attaboy_force_o
   , output logic [vaddr_width_p-1:0]                 attaboy_pc_o
   , output logic                                     attaboy_taken_o
   , output logic                                     attaboy_ntaken_o
   , output logic [branch_metadata_fwd_width_p-1:0]   attaboy_br_metadata_fwd_o
   , input                                            attaboy_yumi_i

   , input [vaddr_width_p-1:0]                        next_pc_i

   , input                                            ovr_i
   , output logic                                     tl_flush_o

   , input                                            tv_we_i
   , input                                            itlb_miss_tl_i
   , input                                            instr_page_fault_tl_i
   , input                                            instr_access_fault_tl_i
   , input                                            icache_miss_tv_i
   , output logic                                     tv_flush_o

   , input                                            fetch_v_i
   , input [vaddr_width_p-1:0]                        fetch_pc_i
   , input [fetch_width_p-1:0]                        fetch_instr_i
   , input [fetch_ptr_p-1:0]                          fetch_count_i
   , input                                            fetch_partial_i
   , input [branch_metadata_fwd_width_p-1:0]          fetch_br_metadata_fwd_i
   , output logic                                     fetch_yumi_o

   , output logic                                     itlb_r_v_o
   , output logic                                     itlb_w_v_o
   , output logic [vtag_width_p-1:0]                  itlb_w_vtag_o
   , output logic [pte_leaf_width_lp-1:0]             itlb_w_entry_o
   , output logic                                     itlb_fence_v_o

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
  `bp_cast_o(bp_fe_queue_s, fe_queue);
  `bp_cast_o(bp_fe_icache_pkt_s, icache_pkt);

  // FSM
  enum logic [1:0] {e_reset, e_wait, e_run, e_resume} state_n, state_r;

  // Decoded state signals
  wire is_reset    = (state_r == e_reset);
  wire is_run      = (state_r == e_run);
  wire is_wait     = (state_r == e_wait);
  wire is_resume   = (state_r == e_resume);

  wire pc_redirect_v          = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_pc_redirection);
  wire icache_fill_response_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fill_response);
  wire icache_fence_v         = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fence);

  wire state_reset_v          = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_state_reset);
  wire itlb_fill_response_v   = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fill_response);
  wire itlb_fence_v           = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fence);
  wire wait_v                 = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_wait);

  wire br_miss_v     = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_branch_mispredict);
  wire eret_v        = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_eret);
  wire interrupt_v   = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_interrupt);
  wire trap_v        = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_trap);
  wire translation_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_translation_switch);
  // Unsupported
  //wire context_v     = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_context_switch);

  wire br_miss_taken = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_pred_taken);
  wire br_miss_ntaken = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_pred_ntaken);
  wire br_miss_nonbr = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_not_a_branch);

  wire attaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_attaboy);
  wire cmd_nonattaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_attaboy);
  wire cmd_immediate_v  = fe_cmd_v_i & (pc_redirect_v | icache_fill_response_v | wait_v);
  wire cmd_complex_v    = fe_cmd_v_i & (state_reset_v | itlb_fill_response_v | icache_fence_v | itlb_fence_v);

  assign redirect_v_o               = !is_wait & cmd_nonattaboy_v;
  assign redirect_pc_o              = fe_cmd_cast_i.npc - (redirect_resume_o << 1'b1);
  assign redirect_npc_o             = fe_cmd_cast_i.npc;
  assign redirect_br_v_o            = !is_wait & br_miss_v;
  assign redirect_br_taken_o        = br_miss_taken;
  assign redirect_br_ntaken_o       = br_miss_ntaken;
  assign redirect_br_nonbr_o        = br_miss_nonbr;
  assign redirect_br_metadata_fwd_o = fe_cmd_cast_i.operands.pc_redirect_operands.branch_metadata_fwd;

  assign attaboy_v_o               = attaboy_v;
  assign attaboy_force_o           = ~fe_queue_ready_and_i;
  assign attaboy_pc_o              = fe_cmd_cast_i.npc;
  assign attaboy_taken_o           = attaboy_v &  fe_cmd_cast_i.operands.attaboy.taken;
  assign attaboy_ntaken_o          = attaboy_v & ~fe_cmd_cast_i.operands.attaboy.taken;
  assign attaboy_br_metadata_fwd_o = fe_cmd_cast_i.operands.attaboy.branch_metadata_fwd;

  assign shadow_priv_w_o = state_reset_v | trap_v | interrupt_v | eret_v;
  assign shadow_priv_o = fe_cmd_cast_i.operands.pc_redirect_operands.priv;

  assign shadow_translation_en_w_o = state_reset_v | trap_v | interrupt_v | eret_v | translation_v;
  assign shadow_translation_en_o = fe_cmd_cast_i.operands.pc_redirect_operands.translation_en;

  assign itlb_w_vtag_o = fe_cmd_cast_i.npc[vaddr_width_p-1-:vtag_width_p];
  assign itlb_w_entry_o = fe_cmd_cast_i.operands.itlb_fill_response.pte_leaf;

  assign icache_pkt_cast_o =
    '{vaddr: next_pc_i
      ,op  : (is_run & icache_fence_v) ? e_icache_inval : e_icache_fetch
      ,spec: !icache_fill_response_v
      };

  assign redirect_instr_o = itlb_fill_response_v
    ? fe_cmd_cast_i.operands.itlb_fill_response.instr
    : fe_cmd_cast_i.operands.icache_fill_response.instr;
  assign redirect_resume_o =
    itlb_fill_response_v
    ? (fe_cmd_cast_i.operands.itlb_fill_response.count > '0)
    : icache_fill_response_v
      ? (fe_cmd_cast_i.operands.icache_fill_response.count > '0)
      : '0;

  logic itlb_miss_tv_r, instr_page_fault_tv_r, instr_access_fault_tv_r;
  bsg_dff_reset_en
   #(.width_p(3))
   exception_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i || tv_flush_o)
     ,.en_i(tv_we_i)
     ,.data_i({itlb_miss_tl_i, instr_page_fault_tl_i, instr_access_fault_tl_i})
     ,.data_o({itlb_miss_tv_r, instr_page_fault_tv_r, instr_access_fault_tv_r})
     );
  wire if2_exception_v = |{itlb_miss_tv_r, instr_page_fault_tv_r, instr_access_fault_tv_r, icache_miss_tv_i};

  wire fetch_instr_v     = is_run && fe_queue_ready_and_i && fetch_v_i && (fetch_count_i > '0);
  wire fetch_exception_v = is_run && fe_queue_ready_and_i && if2_exception_v && ~fetch_instr_v;

  assign fetch_yumi_o    = is_run && fe_queue_ready_and_i && fetch_v_i;
  always_comb
    begin
      fe_queue_v_o = (fetch_instr_v | fetch_exception_v);

      fe_queue_cast_o = '0;
      fe_queue_cast_o.pc = fetch_pc_i;
      fe_queue_cast_o.instr = fetch_instr_i;
      fe_queue_cast_o.msg_type = fetch_instr_v
                                 ? e_instr_fetch
                                 : itlb_miss_tv_r
                                   ? e_itlb_miss
                                   : instr_page_fault_tv_r
                                     ? e_instr_page_fault
                                     : instr_access_fault_tv_r
                                       ? e_instr_access_fault
                                       : e_icache_miss;
      fe_queue_cast_o.branch_metadata_fwd = fetch_br_metadata_fwd_i;
      fe_queue_cast_o.count = fetch_instr_v ? fetch_count_i : fetch_partial_i;
    end

  always_comb
    begin
      icache_v_o = 1'b0;
      icache_force_o = 1'b0;

      itlb_r_v_o = 1'b0;
      itlb_w_v_o = 1'b0;
      itlb_fence_v_o = 1'b0;

      tl_flush_o = 1'b0;
      tv_flush_o = 1'b0;

      fe_cmd_yumi_o = 1'b0;

      state_n = state_r;

      case (state_r)
        e_reset:
          begin
            // Drain non-reset requests
            fe_cmd_yumi_o = fe_cmd_v_i & !state_reset_v;

            state_n = (state_reset_v && pc_gen_init_done_i) ? e_resume : state_r;
          end
        e_wait:
          begin
            fe_cmd_yumi_o = attaboy_v && attaboy_yumi_i;

            tl_flush_o = 1'b1;
            tv_flush_o = 1'b1;

            state_n = cmd_nonattaboy_v ? e_run : state_r;
          end
        e_resume:
          begin
            icache_v_o = fe_cmd_v_i;
            itlb_r_v_o = icache_yumi_i;

            fe_cmd_yumi_o = icache_yumi_i;

            state_n = fe_cmd_yumi_o ? e_run : state_r;
          end
        e_run:
          begin
            if (cmd_immediate_v)
              begin
                icache_v_o = 1'b1;
                icache_force_o = 1'b1;
                itlb_r_v_o = icache_yumi_i;

                tv_flush_o = 1'b1;

                fe_cmd_yumi_o = icache_yumi_i;
              end
            else if (cmd_complex_v)
              begin
                icache_v_o = icache_fence_v && !icache_features_p[e_cfg_coherent];
                icache_force_o = 1'b1;

                itlb_w_v_o = itlb_fill_response_v;
                itlb_fence_v_o = itlb_fence_v;

                tl_flush_o = itlb_fill_response_v | itlb_fence_v;
                tv_flush_o = 1'b1;

                state_n = e_resume;
              end
            else
              begin
                icache_v_o = 1'b1;
                icache_force_o = ovr_i;
                itlb_r_v_o = icache_yumi_i;

                tv_flush_o = ovr_i;

                fe_cmd_yumi_o = attaboy_v && attaboy_yumi_i;

                state_n = fetch_exception_v ? e_wait : state_r;
              end
          end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
        state_r <= e_reset;
    else
        state_r <= state_n;

endmodule


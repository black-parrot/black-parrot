/*
 * bp_fe_top.v
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_top
 import bp_fe_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output                                           fe_cmd_yumi_o

   , output [fe_queue_width_lp-1:0]                   fe_queue_o
   , output                                           fe_queue_v_o
   , input                                            fe_queue_ready_i

   , output logic [icache_req_width_lp-1:0]           cache_req_o
   , output logic                                     cache_req_v_o
   , input                                            cache_req_yumi_i
   , input                                            cache_req_busy_i
   , output logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o
   , output logic                                     cache_req_metadata_v_o
   , input                                            cache_req_critical_i
   , input                                            cache_req_complete_i
   , input                                            cache_req_credits_full_i
   , input                                            cache_req_credits_empty_i

   , input [icache_data_mem_pkt_width_lp-1:0]         data_mem_pkt_i
   , input                                            data_mem_pkt_v_i
   , output logic                                     data_mem_pkt_yumi_o
   , output logic [icache_block_width_p-1:0]          data_mem_o

   , input [icache_tag_mem_pkt_width_lp-1:0]          tag_mem_pkt_i
   , input                                            tag_mem_pkt_v_i
   , output logic                                     tag_mem_pkt_yumi_o
   , output logic [icache_tag_info_width_lp-1:0]      tag_mem_o

   , input [icache_stat_mem_pkt_width_lp-1:0]         stat_mem_pkt_i
   , input                                            stat_mem_pkt_v_i
   , output logic                                     stat_mem_pkt_yumi_o
   , output logic [icache_stat_info_width_lp-1:0]     stat_mem_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  `bp_cast_i(bp_fe_cmd_s, fe_cmd);
  `bp_cast_o(bp_fe_queue_s, fe_queue);

  // FSM
  enum logic [1:0] {e_wait=2'd0, e_run, e_redirect} state_n, state_r;

  // Decoded state signals
  wire is_wait     = (state_r == e_wait);
  wire is_run      = (state_r == e_run);
  wire is_redirect = (state_r == e_redirect);

  // Complex commands
  wire state_reset_v     = ~is_redirect & fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_state_reset);
  wire itlb_fill_v       = ~is_redirect & fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fill_response);
  wire icache_fence_v    = ~is_redirect & fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fence);
  wire itlb_fence_v      = ~is_redirect & fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fence);
  wire cmd_complex_v     = (state_reset_v | itlb_fill_v | icache_fence_v | itlb_fence_v);

  // Immediate commands
  wire pc_redirect_v     = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_pc_redirection);
  wire icache_fill_v     = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fill_response);
  wire cmd_immediate_v   = pc_redirect_v | icache_fill_v;

  // Attaboy
  wire attaboy_v         = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_attaboy);
  wire cmd_nonattaboy_v  = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_attaboy);

  wire br_miss_v = pc_redirect_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_branch_mispredict);
  wire br_miss_taken = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_pred_taken);
  wire br_miss_ntaken = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_incorrect_pred_ntaken);
  wire br_miss_nonbr = br_miss_v
    & (fe_cmd_cast_i.operands.pc_redirect_operands.misprediction_reason == e_not_a_branch);

  wire trap_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_trap);
  wire translation_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_translation_switch);

  logic [rv64_priv_width_gp-1:0] shadow_priv_n, shadow_priv_r;
  wire shadow_priv_w = state_reset_v | trap_v;
  assign shadow_priv_n = fe_cmd_cast_i.operands.pc_redirect_operands.priv;
  bsg_dff_reset_en_bypass
   #(.width_p(rv64_priv_width_gp))
   shadow_priv_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(shadow_priv_w)

     ,.data_i(shadow_priv_n)
     ,.data_o(shadow_priv_r)
     );

  logic shadow_translation_en_n, shadow_translation_en_r;
  wire shadow_translation_en_w = state_reset_v | trap_v | translation_v;
  assign shadow_translation_en_n = fe_cmd_cast_i.operands.pc_redirect_operands.translation_enabled;
  bsg_dff_reset_en_bypass
   #(.width_p(1))
   shadow_translation_en_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(shadow_translation_en_w)

     ,.data_i(shadow_translation_en_n)
     ,.data_o(shadow_translation_en_r)
     );

  bp_fe_branch_metadata_fwd_s redirect_br_metadata_fwd_li;
  wire                      redirect_v_li = (cmd_immediate_v | is_redirect);
  wire [vaddr_width_p-1:0] redirect_pc_li = fe_cmd_cast_i.vaddr;
  wire                   redirect_br_v_li = redirect_v_li & br_miss_v;
  wire               redirect_br_taken_li = br_miss_taken;
  wire              redirect_br_ntaken_li = br_miss_ntaken;
  wire               redirect_br_nonbr_li = br_miss_nonbr;
  assign      redirect_br_metadata_fwd_li = fe_cmd_cast_i.operands.pc_redirect_operands.branch_metadata_fwd;

  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd_li;
  logic attaboy_yumi_lo;
  wire                  attaboy_taken_li = attaboy_v &  fe_cmd_cast_i.operands.attaboy.taken;
  wire                 attaboy_ntaken_li = attaboy_v & ~fe_cmd_cast_i.operands.attaboy.taken;
  wire                      attaboy_v_li = attaboy_v;
  wire [vaddr_width_p-1:0] attaboy_pc_li = fe_cmd_cast_i.vaddr;
  assign      attaboy_br_metadata_fwd_li = fe_cmd_cast_i.operands.attaboy.branch_metadata_fwd;

  logic [instr_width_gp-1:0] fetch_li;
  logic [vaddr_width_p-1:0] fetch_pc_lo;
  logic fetch_instr_v_li, fetch_exception_v_li;
  bp_fe_branch_metadata_fwd_s fetch_br_metadata_fwd_lo;
  logic [vaddr_width_p-1:0] next_pc_lo;
  logic next_pc_ovr_lo;
  logic recover_lo, tl_we_lo, tv_we_lo;
  logic [vaddr_width_p-1:0] tl_vaddr_lo, tv_vaddr_lo;
  bp_fe_pc_gen
   #(.bp_params_p(bp_params_p))
   pc_gen
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.redirect_v_i(redirect_v_li)
     ,.redirect_pc_i(redirect_pc_li)
     ,.redirect_br_v_i(redirect_br_v_li)
     ,.redirect_br_metadata_fwd_i(redirect_br_metadata_fwd_li)
     ,.redirect_br_taken_i(redirect_br_taken_li)
     ,.redirect_br_ntaken_i(redirect_br_ntaken_li)
     ,.redirect_br_nonbr_i(redirect_br_nonbr_li)
     ,.next_pc_o(next_pc_lo)
     ,.next_pc_ovr_o(next_pc_ovr_lo)

     ,.en_if1_i(tl_we_lo)
     ,.pc_if1_i(tl_vaddr_lo)
     ,.en_if2_i(tv_we_lo)
     ,.pc_if2_i(tv_vaddr_lo)

     ,.fetch_i(fetch_li)
     ,.fetch_instr_v_i(fetch_instr_v_li)
     ,.fetch_exception_v_i(fetch_exception_v_li)
     ,.fetch_br_metadata_fwd_o(fetch_br_metadata_fwd_lo)
     ,.fetch_pc_o(fetch_pc_lo)

     ,.attaboy_pc_i(attaboy_pc_li)
     ,.attaboy_br_metadata_fwd_i(attaboy_br_metadata_fwd_li)
     ,.attaboy_taken_i(attaboy_taken_li)
     ,.attaboy_ntaken_i(attaboy_ntaken_li)
     ,.attaboy_v_i(attaboy_v_li)
     ,.attaboy_yumi_o(attaboy_yumi_lo)
     );

  logic instr_access_fault_v, instr_page_fault_v;
  logic ptag_v_li, ptag_uncached_li, ptag_miss_li;
  logic [ptag_width_p-1:0] ptag_li;

  bp_pte_entry_leaf_s w_tlb_entry_li;
  wire [vtag_width_p-1:0] w_vtag_li = fe_cmd_cast_i.vaddr[vaddr_width_p-1-:vtag_width_p];
  assign w_tlb_entry_li = fe_cmd_cast_i.operands.itlb_fill_response.pte_entry_leaf;
  wire w_gigapage_li = fe_cmd_cast_i.operands.itlb_fill_response.gigapage;

  // The MMU is synchronous read, so we need to read if there's a new cache request,
  //   or if we're recovering from a fill
  wire r_v_li = tl_we_lo | recover_lo;
  wire [dword_width_gp-1:0] r_eaddr_li =
    recover_lo ? dword_width_gp'($signed(tl_vaddr_lo)) : dword_width_gp'($signed(next_pc_lo));
  bp_mmu
   #(.bp_params_p(bp_params_p)
     ,.tlb_els_4k_p(itlb_els_4k_p)
     ,.tlb_els_1g_p(itlb_els_1g_p)
     )
   immu
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.flush_i(itlb_fence_v)
     ,.priv_mode_i(shadow_priv_r)
     ,.trans_en_i(shadow_translation_en_r)
     // Supervisor use of user memory is always disabled for immu
     ,.sum_i('0)
     ,.uncached_mode_i((cfg_bus_cast_i.icache_mode == e_lce_mode_uncached))
     ,.domain_mask_i(cfg_bus_cast_i.domain_mask)

     ,.w_v_i(itlb_fill_v)
     ,.w_vtag_i(w_vtag_li)
     ,.w_entry_i(w_tlb_entry_li)
     ,.w_gigapage_i(w_gigapage_li)

     ,.r_v_i(r_v_li)
     ,.r_instr_i(1'b1)
     ,.r_load_i('0)
     ,.r_store_i('0)
     ,.r_eaddr_i(r_eaddr_li)

     ,.r_v_o(ptag_v_li)
     ,.r_ptag_o(ptag_li)
     ,.r_miss_o(ptag_miss_li)
     ,.r_uncached_o(ptag_uncached_li)
     ,.r_instr_access_fault_o(instr_access_fault_v)
     ,.r_load_access_fault_o()
     ,.r_store_access_fault_o()
     ,.r_instr_page_fault_o(instr_page_fault_v)
     ,.r_load_page_fault_o()
     ,.r_store_page_fault_o()
     );

  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt;
  assign icache_pkt = '{vaddr: next_pc_lo
                        // TODO: Add "performance mode", always fill configuration
                        ,op  : icache_fence_v ? e_icache_fencei : icache_fill_v ? e_icache_fill : e_icache_fetch
                        };
  wire icache_v_li = ~is_wait | cmd_immediate_v;
  logic [instr_width_gp-1:0] icache_data_lo;
  logic icache_miss_not_data_lo;
  logic icache_v_lo, icache_yumi_li;
  logic icache_yumi_lo;
  bp_fe_icache
   #(.bp_params_p(bp_params_p))
   icache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.icache_pkt_i(icache_pkt)
     ,.v_i(icache_v_li)
     ,.force_i(cmd_nonattaboy_v)
     ,.yumi_o(icache_yumi_lo)
     ,.tl_we_o(tl_we_lo)
     ,.tl_vaddr_o(tl_vaddr_lo)

     ,.ptag_i(ptag_li)
     ,.ptag_v_i(ptag_v_li)
     ,.ptag_uncached_i(ptag_uncached_li)
     ,.tv_we_o(tv_we_lo)
     ,.tv_vaddr_o(tv_vaddr_lo)

     ,.data_o(icache_data_lo)
     ,.miss_not_data_o(icache_miss_not_data_lo)
     ,.v_o(icache_v_lo)
     ,.data_yumi_i(icache_yumi_li)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_busy_i(cache_req_busy_i)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_complete_i(cache_req_complete_i)
     ,.cache_req_credits_full_i(cache_req_credits_full_i)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_i)

     ,.data_mem_pkt_i(data_mem_pkt_i)
     ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)
     ,.data_mem_o(data_mem_o)

     ,.tag_mem_pkt_i(tag_mem_pkt_i)
     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)
     ,.tag_mem_o(tag_mem_o)

     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(stat_mem_pkt_i)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
     ,.stat_mem_o(stat_mem_o)
     );
  assign icache_yumi_li = icache_v_lo & fe_queue_ready_i;

  logic itlb_miss_r, instr_access_fault_r, instr_page_fault_r;
  bsg_dff_reset_en
   #(.width_p(3))
   fault_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tv_we_lo)

     ,.data_i({ptag_miss_li, instr_access_fault_v, instr_page_fault_v})
     ,.data_o({itlb_miss_r, instr_access_fault_r, instr_page_fault_r})
     );

  logic v_if1_r;
  bsg_dff_reset_set_clear
   #(.width_p(1), .clear_over_set_p(0))
   v_if1_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(icache_yumi_lo)
     ,.clear_i(fetch_exception_v_li | redirect_v_li)
     ,.data_o(v_if1_r)
     );
  assign recover_lo = v_if1_r & ~tv_we_lo & ~cmd_nonattaboy_v;

  logic v_if2_r;
  bsg_dff_reset_set_clear
   #(.width_p(1), .clear_over_set_p(1))
   v_if2_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(v_if1_r & tv_we_lo)
     ,.clear_i(next_pc_ovr_lo | fetch_exception_v_li | cmd_nonattaboy_v)
     ,.data_o(v_if2_r)
     );

  wire icache_miss    = v_if2_r & icache_yumi_li & icache_miss_not_data_lo;
  wire fe_exception_v = v_if2_r & (instr_access_fault_r | instr_page_fault_r | itlb_miss_r | icache_miss);
  wire fe_instr_v     = v_if2_r & icache_yumi_li;
  assign fe_queue_v_o = fe_queue_ready_i & (fe_instr_v | fe_exception_v) & ~cmd_nonattaboy_v;

  // All non-immediate commands are currently single cycle
  assign fe_cmd_yumi_o = ((is_redirect | cmd_immediate_v) & icache_yumi_lo) | attaboy_yumi_lo;

  assign fetch_instr_v_li     = fe_queue_v_o & fe_instr_v;
  assign fetch_exception_v_li = fe_queue_v_o & fe_exception_v;
  assign fetch_li             = icache_data_lo;

  always_comb
    if (fe_exception_v)
      begin
        fe_queue_cast_o = '0;
        fe_queue_cast_o.msg_type                     = e_fe_exception;
        fe_queue_cast_o.msg.exception.vaddr          = fetch_pc_lo;
        fe_queue_cast_o.msg.exception.exception_code = itlb_miss_r
                                                       ? e_itlb_miss
                                                       : instr_page_fault_r
                                                         ? e_instr_page_fault
                                                         : instr_access_fault_r
                                                           ? e_instr_access_fault
                                                           : e_icache_miss;
      end
    else
      begin
        fe_queue_cast_o = '0;
        fe_queue_cast_o.msg_type                      = e_fe_fetch;
        fe_queue_cast_o.msg.fetch.pc                  = fetch_pc_lo;
        fe_queue_cast_o.msg.fetch.instr               = fetch_li;
        fe_queue_cast_o.msg.fetch.branch_metadata_fwd = fetch_br_metadata_fwd_lo;
      end

  /////////////////////////////////////////////////////////////////////////////
  // State machine
  //   e_wait    : Stay in quiescient state until a front end command comes in
  //   e_redirect: Redirect fetch after updating structures with a FE cmd
  //   e_run     : Fast path; continually fetch new instructions
  /////////////////////////////////////////////////////////////////////////////
  always_comb
    case (state_r)
      // Wait for FE exception to be serviced by BE
      e_wait: state_n = cmd_immediate_v ? e_run : cmd_nonattaboy_v ? e_redirect : e_wait;
      // Wait for FE cmd to complete, then redirect
      e_redirect: state_n = icache_yumi_lo ? e_run : e_redirect;
      // Stay in run if there's an incoming cmd, the next pc will automatically be valid
      // Take care of a complex command if we receive one
      // Halt and wait for BE to handle exceptions
      // Otherwise, keep chugging along
      e_run: state_n = cmd_immediate_v
                        ? e_run
                        : cmd_complex_v
                          ? e_redirect
                          : fetch_exception_v_li
                            ? e_wait
                            : e_run;
      default: state_n = e_wait;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
        state_r <= e_wait;
    else
      begin
        state_r <= state_n;
      end

endmodule


/*
 * bp_fe_top.v
 */

module bp_fe_top
 import bp_fe_pkg::*;
 import bp_fe_icache_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache_fill_width_p, icache)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
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

   // Interface to LCE

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
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p);
  bp_fe_cmd_s fe_cmd_cast_i;
  assign fe_cmd_cast_i = fe_cmd_i;

  bp_fe_queue_s fe_queue_cast_o;
  assign fe_queue_o = fe_queue_cast_o;

  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  logic ovr_lo, mem_poison_lo;

  logic [vaddr_width_p-1:0] next_pc_lo;
  logic next_pc_v_lo, next_pc_yumi_li;

  logic itlb_miss_r;
  logic instr_access_fault_r, instr_page_fault_r;
  logic [vaddr_width_p-1:0] vaddr_r, vaddr_rr;

  // FSM
  enum logic [1:0] {e_wait=2'd0, e_run, e_stall} state_n, state_r;

  // Decoded state signals
  wire is_wait  = (state_r == e_wait);
  wire is_run   = (state_r == e_run);
  wire is_stall = (state_r == e_stall);

  logic resume_v_li;
  logic [vaddr_width_p-1:0] resume_pc_li;
  logic [instr_width_p-1:0] fetch_li;
  logic fetch_instr_v_li, fetch_exception_v_li, fetch_fail_v_li;
  bp_fe_branch_metadata_fwd_s fetch_br_metadata_fwd_lo;


  wire state_reset_v    = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_state_reset);
  wire pc_redirect_v    = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_pc_redirection);
  wire itlb_fill_v      = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fill_response);
  wire icache_fence_v   = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_icache_fence);
  wire itlb_fence_v     = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_itlb_fence);
  wire attaboy_v        = fe_cmd_v_i & (fe_cmd_cast_i.opcode == e_op_attaboy);
  wire cmd_nonattaboy_v = fe_cmd_v_i & (fe_cmd_cast_i.opcode != e_op_attaboy);

  wire trap_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_trap);
  wire translation_v = pc_redirect_v & (fe_cmd_cast_i.operands.pc_redirect_operands.subopcode == e_subop_translation_switch);

  logic [rv64_priv_width_gp-1:0] shadow_priv_n, shadow_priv_r;

  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd_li;
  logic attaboy_v_li, attaboy_yumi_lo, attaboy_taken_li, attaboy_ntaken_li;
  logic [vaddr_width_p-1:0] attaboy_pc_li;
  assign attaboy_br_metadata_fwd_li = fe_cmd_cast_i.operands.attaboy.branch_metadata_fwd;
  assign attaboy_taken_li           = attaboy_v &  fe_cmd_cast_i.operands.attaboy.taken;
  assign attaboy_ntaken_li          = attaboy_v & ~fe_cmd_cast_i.operands.attaboy.taken;
  assign attaboy_v_li               = attaboy_v;
  assign attaboy_pc_li              = fe_cmd_cast_i.vaddr;
  bp_fe_pc_gen
   #(.bp_params_p(bp_params_p))
   pc_gen
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.resume_v_i(resume_v_li)
     ,.resume_pc_i(resume_pc_li)

     ,.next_pc_o(next_pc_lo)
     ,.next_pc_yumi_i(next_pc_yumi_li)

     ,.mem_poison_o(ovr_lo)

     ,.fetch_i(fetch_li)
     ,.fetch_instr_v_i(fetch_instr_v_li)
     ,.fetch_exception_v_i(fetch_exception_v_li)
     ,.fetch_fail_v_i(fetch_fail_v_li)
     ,.fetch_br_metadata_fwd_o(fetch_br_metadata_fwd_lo)

     ,.fe_cmd_i(fe_cmd_i)
     ,.fe_cmd_v_i(fe_cmd_v_i)
     ,.fe_cmd_yumi_o(fe_cmd_yumi_o)

     ,.attaboy_pc_i(attaboy_pc_li)
     ,.attaboy_br_metadata_fwd_i(attaboy_br_metadata_fwd_li)
     ,.attaboy_taken_i(attaboy_taken_li)
     ,.attaboy_ntaken_i(attaboy_ntaken_li)
     ,.attaboy_v_i(attaboy_v_li)
     ,.attaboy_yumi_o(/* TODO: */)
     );

  logic instr_page_fault_lo, instr_access_fault_lo, itlb_miss_lo;

  logic icache_ready;
  // TODO: comment about energy

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

  // Change the resume pc on redirect command, else save the PC in IF2 while running
  logic [vaddr_width_p-1:0] pc_resume_n, pc_resume_r;
  assign pc_resume_n = cmd_nonattaboy_v ? fe_cmd_cast_i.vaddr : vaddr_rr;
  bsg_dff_reset_en_bypass
   #(.width_p(vaddr_width_p))
   pc_resume_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(cmd_nonattaboy_v | fetch_instr_v_li | fetch_exception_v_li | fetch_fail_v_li)
  
     ,.data_i(pc_resume_n)
     ,.data_o(pc_resume_r)
     );
  assign resume_pc_li = pc_resume_r;
  // TODO: Replay logic here is wonky
  assign resume_v_li = (is_stall & next_pc_yumi_li) | cmd_nonattaboy_v;

  //assign next_pc_yumi_li = ~is_wait & icache_ready & (fe_queue_ready_i | cmd_nonattaboy_v);
  assign next_pc_yumi_li = cmd_nonattaboy_v | (~is_wait & icache_ready & fe_queue_ready_i);

  logic fetch_v_r, fetch_v_rr;
  bp_pte_entry_leaf_s itlb_r_entry, entry_lo, passthrough_entry;
  logic itlb_r_v_lo, itlb_v_lo, passthrough_v_lo;
  bp_tlb
   #(.bp_params_p(bp_params_p), .tlb_els_p(itlb_els_p))
   itlb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.flush_i(itlb_fence_v)

     ,.v_i((next_pc_yumi_li | itlb_fill_v) & shadow_translation_en_r)
     ,.w_i(itlb_fill_v)
     ,.vtag_i(itlb_fill_v
              ? fe_cmd_cast_i.vaddr[vaddr_width_p-1-:vtag_width_p]
              : next_pc_lo[vaddr_width_p-1-:vtag_width_p]
              )
     ,.entry_i(fe_cmd_cast_i.operands.itlb_fill_response.pte_entry_leaf)

     ,.v_o(itlb_v_lo)
     ,.miss_v_o(itlb_miss_lo)
     ,.entry_o(entry_lo)
     );

  logic [vtag_width_p-1:0] vtag_r;
  bsg_dff_reset_en
   #(.width_p(vtag_width_p))
   vtag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(next_pc_yumi_li)

     ,.data_i(next_pc_lo[vaddr_width_p-1-:vtag_width_p])
     ,.data_o(vtag_r)
    );

  assign passthrough_entry = '{ptag: vtag_r, default: '0};
  assign passthrough_v_lo  = fetch_v_r;
  assign itlb_r_entry      = shadow_translation_en_r ? entry_lo : passthrough_entry;
  assign itlb_r_v_lo       = shadow_translation_en_r ? itlb_v_lo : passthrough_v_lo;

  wire [ptag_width_p-1:0] ptag_li     = itlb_r_entry.ptag;
  wire                    ptag_v_li   = itlb_r_v_lo;

  logic uncached_li;

  bp_pma
   #(.bp_params_p(bp_params_p))
   pma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.ptag_v_i(ptag_v_li)
     ,.ptag_i(ptag_li)

     ,.uncached_o(uncached_li)
     );

  logic [instr_width_p-1:0] icache_data_lo;
  logic                     icache_data_v_lo;

  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt;
  assign icache_pkt = '{vaddr: next_pc_lo
                        ,op  : icache_fence_v ? e_icache_fencei : e_icache_fetch
                        };
  logic instr_access_fault_v, instr_page_fault_v;
  bp_fe_icache
   #(.bp_params_p(bp_params_p))
   icache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.icache_pkt_i(icache_pkt)
     ,.v_i((icache_ready & next_pc_yumi_li) | icache_fence_v)
     ,.ready_o(icache_ready)

     ,.ptag_i(ptag_li)
     ,.ptag_v_i(ptag_v_li)
     ,.uncached_i(uncached_li)
     ,.poison_i(mem_poison_lo | instr_access_fault_v | instr_page_fault_v)

     ,.data_o(icache_data_lo)
     ,.data_v_o(icache_data_v_lo)

     // LCE Interface

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

  always_ff @(posedge clk_i)
    begin
      if(reset_i) begin
        vaddr_r  <= '0;
        vaddr_rr <= '0;

        itlb_miss_r <= '0;
        fetch_v_r   <= '0;
        fetch_v_rr  <= '0;

        instr_access_fault_r <= '0;
        instr_page_fault_r   <= '0;
      end
      else begin
        vaddr_r <= next_pc_lo;
        vaddr_rr <= vaddr_r;

        fetch_v_r   <= next_pc_yumi_li;
        fetch_v_rr  <= fetch_v_r & ~mem_poison_lo;
        itlb_miss_r <= itlb_miss_lo & ~mem_poison_lo;

        instr_access_fault_r <= instr_access_fault_v & ~mem_poison_lo;
        instr_page_fault_r   <= instr_page_fault_v & ~mem_poison_lo;
      end
    end

  wire instr_priv_page_fault = ((shadow_priv_r == `PRIV_MODE_S) & itlb_r_entry.u)
                                 | ((shadow_priv_r == `PRIV_MODE_U) & ~itlb_r_entry.u);
  wire instr_exe_page_fault = ~itlb_r_entry.x;

  // Fault if in uncached mode but access is not for an uncached address
  wire is_uncached_mode = (cfg_bus_cast_i.icache_mode == e_lce_mode_uncached);
  wire mode_fault_v = (is_uncached_mode & ~uncached_li);
  // Fault if domain is not zero (top <io_noc_did_width_p> bits) and SAC bit is not zero (next bit)
  wire did_fault_v = (ptag_li[ptag_width_p-1-:io_noc_did_width_p+1] != '0);

  // Until we support C, must be aligned to 4 bytes
  // There's also an interesting question about physical alignment (I/O devices, etc)
  //   But let's punt that for now...
  assign instr_access_fault_v = fetch_v_r & (mode_fault_v | did_fault_v);
  assign instr_page_fault_v   = fetch_v_r & itlb_r_v_lo & shadow_translation_en_r & (instr_priv_page_fault | instr_exe_page_fault);

  wire icache_miss    = fetch_v_rr & ~icache_data_v_lo;
  wire queue_miss     = fetch_v_rr & ~fe_queue_ready_i;
  wire fe_exception_v = fetch_v_rr & (instr_access_fault_r | instr_page_fault_r | itlb_miss_r);
  wire flush          = icache_miss | queue_miss | fe_exception_v | cmd_nonattaboy_v;
  wire fe_instr_v     = fetch_v_rr & icache_data_v_lo & ~flush;
  assign fe_queue_v_o = fe_queue_ready_i & (fe_instr_v | fe_exception_v);
  assign mem_poison_lo = ovr_lo | flush;

  assign fetch_instr_v_li     = fe_queue_v_o & fe_instr_v;
  assign fetch_exception_v_li = fe_queue_v_o & fe_exception_v;
  assign fetch_fail_v_li      = fetch_v_rr & ~fe_queue_v_o;
  assign fetch_li             = icache_data_lo;
  always_comb
    begin
      // Set padding to 0
      fe_queue_cast_o = '0;

      if (fe_exception_v)
        begin
          fe_queue_cast_o.msg_type                     = e_fe_exception;
          fe_queue_cast_o.msg.exception.vaddr          = vaddr_rr;
          // TODO: gate with fetch_v_rr?
          fe_queue_cast_o.msg.exception.exception_code = itlb_miss_r
                                                         ? e_itlb_miss
                                                         : instr_page_fault_r
                                                           ? e_instr_page_fault
                                                           : e_instr_access_fault;
        end
      else
        begin
          fe_queue_cast_o.msg_type                      = e_fe_fetch;
          fe_queue_cast_o.msg.fetch.pc                  = vaddr_rr;
          fe_queue_cast_o.msg.fetch.instr               = fetch_li;
          fe_queue_cast_o.msg.fetch.branch_metadata_fwd = fetch_br_metadata_fwd_lo;
        end
    end

  // Controlling state machine
  always_comb
    case (state_r)
      // Wait for FE cmd
      e_wait : state_n = cmd_nonattaboy_v ? e_stall : e_wait;
      // Stall until we can start valid fetch
      e_stall: state_n = next_pc_yumi_li ? e_run : e_stall;
      // Run state -- PCs are actually being fetched
      // Stay in run if there's an incoming cmd, the next pc will automatically be valid
      // Transition to wait if there's a TLB miss while we wait for fill
      // Transition to stall if we don't successfully complete the fetch for whatever reason
      e_run  : state_n = cmd_nonattaboy_v
                         ? e_run
                         : fetch_fail_v_li
                           ? e_stall
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


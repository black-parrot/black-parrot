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
   `declare_bp_fe_icache_engine_if_widths(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output logic                                     fe_cmd_yumi_o

   , output logic [fe_queue_width_lp-1:0]             fe_queue_o
   , output logic                                     fe_queue_v_o
   , input                                            fe_queue_ready_and_i

   , output logic [icache_req_width_lp-1:0]           cache_req_o
   , output logic                                     cache_req_v_o
   , input                                            cache_req_yumi_i
   , input                                            cache_req_lock_i
   , output logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o
   , output logic                                     cache_req_metadata_v_o
   , input [icache_req_id_width_p-1:0]                cache_req_id_i
   , input                                            cache_req_critical_i
   , input                                            cache_req_last_i
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
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(ras_idx_width_p, btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_els_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  logic [rv64_priv_width_gp-1:0] shadow_priv_n, shadow_priv_r;
  logic shadow_priv_w;
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
  logic shadow_translation_en_w;
  bsg_dff_reset_en_bypass
   #(.width_p(1))
   shadow_translation_en_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(shadow_translation_en_w)
     ,.data_i(shadow_translation_en_n)
     ,.data_o(shadow_translation_en_r)
     );

  logic pc_gen_init_done_lo;
  logic attaboy_v_li, attaboy_force_li, attaboy_yumi_lo, attaboy_taken_li, attaboy_ntaken_li;
  logic [vaddr_width_p-1:0] attaboy_pc_li;
  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd_li;
  logic redirect_v_li, redirect_resume_li;
  logic [vaddr_width_p-1:0] redirect_pc_li, redirect_npc_li;
  logic redirect_br_v_li, redirect_br_taken_li, redirect_br_ntaken_li, redirect_br_nonbr_li;
  logic [cinstr_width_gp-1:0] redirect_instr_li;
  bp_fe_branch_metadata_fwd_s redirect_br_metadata_fwd_li;
  logic [vaddr_width_p-1:0] next_pc_lo;
  logic if1_we;
  logic ovr_lo, if2_we;
  logic [vaddr_width_p-1:0] if2_pc_lo;
  bp_fe_branch_metadata_fwd_s if2_br_metadata_fwd_lo;
  logic if2_taken_branch_site_lo;
  logic if2_yumi_lo;
  logic fetch_instr_v_lo, fetch_exception_v_lo;
  logic [vaddr_width_p-1:0] fetch_pc_lo;
  logic [instr_width_gp-1:0] fetch_instr_lo;
  bp_fe_instr_scan_s fetch_instr_scan_lo;
  logic fetch_partial_lo, fetch_linear_lo, fetch_eager_lo, fetch_scan_lo, fetch_rebase_lo;
  bp_fe_pc_gen
   #(.bp_params_p(bp_params_p))
   pc_gen
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.init_done_o(pc_gen_init_done_lo)

     ,.attaboy_v_i(attaboy_v_li)
     ,.attaboy_force_i(attaboy_force_li)
     ,.attaboy_pc_i(attaboy_pc_li)
     ,.attaboy_br_metadata_fwd_i(attaboy_br_metadata_fwd_li)
     ,.attaboy_taken_i(attaboy_taken_li)
     ,.attaboy_ntaken_i(attaboy_ntaken_li)
     ,.attaboy_yumi_o(attaboy_yumi_lo)

     ,.redirect_v_i(redirect_v_li)
     ,.redirect_resume_i(redirect_resume_li)
     ,.redirect_pc_i(redirect_pc_li)
     ,.redirect_npc_i(redirect_npc_li)
     ,.redirect_br_v_i(redirect_br_v_li)
     ,.redirect_br_metadata_fwd_i(redirect_br_metadata_fwd_li)
     ,.redirect_br_taken_i(redirect_br_taken_li)
     ,.redirect_br_ntaken_i(redirect_br_ntaken_li)
     ,.redirect_br_nonbr_i(redirect_br_nonbr_li)

     ,.next_pc_o(next_pc_lo)
     ,.if1_we_i(if1_we)

     ,.ovr_o(ovr_lo)
     ,.if2_we_i(if2_we)

     ,.if2_pc_o(if2_pc_lo)
     ,.if2_br_metadata_fwd_o(if2_br_metadata_fwd_lo)
     ,.if2_taken_branch_site_o(if2_taken_branch_site_lo)

     ,.fetch_instr_v_i(fetch_instr_v_lo)
     ,.fetch_pc_i(fetch_pc_lo)
     ,.fetch_instr_i(fetch_instr_lo)
     ,.fetch_instr_scan_i(fetch_instr_scan_lo)
     ,.fetch_linear_i(fetch_linear_lo)
     ,.fetch_scan_i(fetch_scan_lo)
     ,.fetch_rebase_i(fetch_rebase_lo)
     );

  logic itlb_r_v_li;
  wire [dword_width_gp-1:0] r_eaddr_li = `BSG_SIGN_EXTEND(next_pc_lo, dword_width_gp);
  wire [1:0] r_size_li = 2'b10;

  logic itlb_w_v_li, itlb_flush_v_li, itlb_fence_v_li;
  logic [vtag_width_p-1:0] itlb_w_vtag_li;
  bp_pte_leaf_s itlb_w_tlb_entry_li;

  logic instr_access_fault_v, instr_page_fault_v;
  logic ptag_v_li, ptag_uncached_li, ptag_nonidem_li, ptag_dram_li, ptag_miss_li;
  logic [ptag_width_p-1:0] ptag_li;

  wire uncached_mode = (cfg_bus_cast_i.icache_mode == e_lce_mode_uncached);
  wire nonspec_mode = (cfg_bus_cast_i.icache_mode == e_lce_mode_nonspec);
  bp_mmu
   #(.bp_params_p(bp_params_p)
     ,.tlb_els_4k_p(itlb_els_4k_p)
     ,.tlb_els_2m_p(itlb_els_2m_p)
     ,.tlb_els_1g_p(itlb_els_1g_p)
     ,.latch_last_read_p(1)
     )
   immu
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.flush_i(itlb_flush_v_li)
     ,.fence_i(itlb_fence_v_li)
     ,.priv_mode_i(shadow_priv_r)
     ,.trans_en_i(shadow_translation_en_r)
     // Supervisor use of user memory is always disabled for immu
     ,.sum_i('0)
     // Immu does not handle dcache loads
     ,.mxr_i('0)
     ,.uncached_mode_i(uncached_mode)
     ,.nonspec_mode_i(nonspec_mode)
     ,.hio_mask_i(cfg_bus_cast_i.hio_mask)

     ,.w_v_i(itlb_w_v_li)
     ,.w_vtag_i(itlb_w_vtag_li)
     ,.w_entry_i(itlb_w_tlb_entry_li)

     ,.r_v_i(itlb_r_v_li)
     ,.r_instr_i(1'b1)
     ,.r_load_i('0)
     ,.r_store_i('0)
     ,.r_cbo_i('0)
     ,.r_ptw_i('0)
     ,.r_eaddr_i(r_eaddr_li)
     ,.r_size_i(r_size_li)

     ,.r_v_o(ptag_v_li)
     ,.r_ptag_o(ptag_li)
     ,.r_instr_miss_o(ptag_miss_li)
     ,.r_load_miss_o()
     ,.r_store_miss_o()
     ,.r_uncached_o(ptag_uncached_li)
     ,.r_nonidem_o(ptag_nonidem_li)
     ,.r_dram_o(ptag_dram_li)
     ,.r_instr_misaligned_o()
     ,.r_load_misaligned_o()
     ,.r_store_misaligned_o()
     ,.r_instr_access_fault_o(instr_access_fault_v)
     ,.r_load_access_fault_o()
     ,.r_store_access_fault_o()
     ,.r_instr_page_fault_o(instr_page_fault_v)
     ,.r_load_page_fault_o()
     ,.r_store_page_fault_o()
     );

  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt_li;
  logic [instr_width_gp-1:0] icache_data_lo;
  logic icache_v_li, icache_force_li, icache_yumi_lo;
  logic icache_tv_we;
  logic icache_data_v_lo, icache_spec_v_lo, icache_yumi_li;
  logic poison_if1_lo, poison_if2_lo, poison_isd_lo;
  bp_fe_icache
   #(.bp_params_p(bp_params_p))
   icache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.icache_pkt_i(icache_pkt_li)
     ,.v_i(icache_v_li)
     ,.force_i(icache_force_li)
     ,.yumi_o(icache_yumi_lo)
     ,.poison_tl_i(poison_if1_lo)

     ,.ptag_i(ptag_li)
     ,.ptag_v_i(ptag_v_li)
     ,.ptag_uncached_i(ptag_uncached_li)
     ,.ptag_nonidem_i(ptag_nonidem_li)
     ,.ptag_dram_i(ptag_dram_li)
     ,.poison_tv_i(poison_if2_lo)
     ,.tv_we_o(icache_tv_we)

     ,.data_o(icache_data_lo)
     ,.data_v_o(icache_data_v_lo)
     ,.spec_v_o(icache_spec_v_lo)
     ,.yumi_i(icache_yumi_li)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_lock_i(cache_req_lock_i)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_id_i(cache_req_id_i)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_last_i(cache_req_last_i)
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
  assign icache_yumi_li = if2_yumi_lo;
  wire if2_instr_v = ~poison_isd_lo & fe_queue_ready_and_i & icache_data_v_lo;

  // This tracks the I$ valid. Could move inside entirely, but we're trying to separate
  //   those responsibilities
  logic itlb_miss_r, instr_access_fault_r, instr_page_fault_r;
  bsg_dff_reset_en
   #(.width_p(3))
   fault_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i || poison_if2_lo)
     ,.en_i(if2_we)
     ,.data_i({ptag_miss_li, instr_access_fault_v, instr_page_fault_v})
     ,.data_o({itlb_miss_r, instr_access_fault_r, instr_page_fault_r})
     );
  wire if2_exception_v = ~poison_isd_lo & fe_queue_ready_and_i & (instr_access_fault_r | instr_page_fault_r | itlb_miss_r | icache_spec_v_lo);

  bp_fe_instr_scan_s icache_instr_scan_lo;
  bp_fe_instr_scan
   #(.bp_params_p(bp_params_p))
   instr_scan
    (.instr_i(icache_data_lo)
     ,.scan_o(icache_instr_scan_lo)
     );

  if (compressed_support_p)
    begin : realigner
      bp_fe_realigner
       #(.bp_params_p(bp_params_p))
       realigner
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.if2_instr_v_i(if2_instr_v)
         ,.if2_exception_v_i(if2_exception_v)
         ,.if2_pc_i(if2_pc_lo)
         ,.if2_data_i(icache_data_lo)
         ,.if2_instr_scan_i(icache_instr_scan_lo)
         ,.if2_taken_branch_site_i(if2_taken_branch_site_lo)
         ,.if2_yumi_o(if2_yumi_lo)

         ,.redirect_v_i(redirect_v_li)
         ,.redirect_resume_i(redirect_resume_li)
         ,.redirect_pc_i(redirect_pc_li)
         ,.redirect_instr_i(redirect_instr_li)

         ,.fetch_instr_v_o(fetch_instr_v_lo)
         ,.fetch_exception_v_o(fetch_exception_v_lo)
         ,.fetch_pc_o(fetch_pc_lo)
         ,.fetch_instr_o(fetch_instr_lo)
         ,.fetch_instr_scan_o(fetch_instr_scan_lo)
         ,.fetch_partial_o(fetch_partial_lo)
         ,.fetch_linear_o(fetch_linear_lo)
         ,.fetch_eager_o(fetch_eager_lo)
         ,.fetch_scan_o(fetch_scan_lo)
         ,.fetch_rebase_o(fetch_rebase_lo)
         );
    end
  else
    begin : realigner
      assign if2_yumi_lo = if2_instr_v | if2_exception_v;
      assign fetch_instr_v_lo = if2_instr_v;
      assign fetch_exception_v_lo = if2_exception_v;
      assign fetch_pc_lo = if2_pc_lo;
      assign fetch_instr_lo = icache_data_lo;
      assign fetch_instr_scan_lo = icache_instr_scan_lo;
      assign fetch_partial_lo = '0;
      assign fetch_linear_lo = '0;
      assign fetch_eager_lo = '0;
      assign fetch_scan_lo = '0;
      assign fetch_rebase_lo = '0;
    end

  bp_fe_controller
   #(.bp_params_p(bp_params_p))
   controller
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.pc_gen_init_done_i(pc_gen_init_done_lo)

     ,.fe_cmd_i(fe_cmd_i)
     ,.fe_cmd_v_i(fe_cmd_v_i)
     ,.fe_cmd_yumi_o(fe_cmd_yumi_o)

     ,.fe_queue_o(fe_queue_o)
     ,.fe_queue_v_o(fe_queue_v_o)
     ,.fe_queue_ready_and_i(fe_queue_ready_and_i)

     ,.redirect_v_o(redirect_v_li)
     ,.redirect_pc_o(redirect_pc_li)
     ,.redirect_npc_o(redirect_npc_li)
     ,.redirect_instr_o(redirect_instr_li)
     ,.redirect_resume_o(redirect_resume_li)
     ,.redirect_br_v_o(redirect_br_v_li)
     ,.redirect_br_taken_o(redirect_br_taken_li)
     ,.redirect_br_ntaken_o(redirect_br_ntaken_li)
     ,.redirect_br_nonbr_o(redirect_br_nonbr_li)
     ,.redirect_br_metadata_fwd_o(redirect_br_metadata_fwd_li)

     ,.attaboy_v_o(attaboy_v_li)
     ,.attaboy_force_o(attaboy_force_li)
     ,.attaboy_pc_o(attaboy_pc_li)
     ,.attaboy_taken_o(attaboy_taken_li)
     ,.attaboy_ntaken_o(attaboy_ntaken_li)
     ,.attaboy_br_metadata_fwd_o(attaboy_br_metadata_fwd_li)
     ,.attaboy_yumi_i(attaboy_yumi_lo)

     ,.next_pc_i(next_pc_lo)

     ,.ovr_i(ovr_lo)
     ,.poison_if1_o(poison_if1_lo)
     ,.if1_we_o(if1_we)

     ,.icache_tv_we_i(icache_tv_we)
     ,.poison_if2_o(poison_if2_lo)
     ,.if2_we_o(if2_we)

     ,.if2_instr_v_i(if2_instr_v)
     ,.if2_exception_v_i(if2_exception_v)
     ,.if2_itlb_miss_i(itlb_miss_r)
     ,.if2_instr_page_fault_i(instr_page_fault_r)
     ,.if2_instr_access_fault_i(instr_access_fault_r)
     ,.if2_icache_spec_v_i(icache_spec_v_lo)
     ,.if2_br_metadata_fwd_i(if2_br_metadata_fwd_lo)
     ,.poison_isd_o(poison_isd_lo)

     ,.fetch_instr_v_i(fetch_instr_v_lo)
     ,.fetch_exception_v_i(fetch_exception_v_lo)
     ,.fetch_pc_i(fetch_pc_lo)
     ,.fetch_instr_i(fetch_instr_lo)
     ,.fetch_partial_i(fetch_partial_lo)
     ,.fetch_eager_i(fetch_eager_lo)

     ,.itlb_r_v_o(itlb_r_v_li)
     ,.itlb_w_v_o(itlb_w_v_li)
     ,.itlb_w_vtag_o(itlb_w_vtag_li)
     ,.itlb_w_entry_o(itlb_w_tlb_entry_li)
     ,.itlb_flush_v_o(itlb_flush_v_li)
     ,.itlb_fence_v_o(itlb_fence_v_li)

     ,.icache_v_o(icache_v_li)
     ,.icache_force_o(icache_force_li)
     ,.icache_pkt_o(icache_pkt_li)
     ,.icache_yumi_i(icache_yumi_lo)

     ,.shadow_priv_o(shadow_priv_n)
     ,.shadow_priv_w_o(shadow_priv_w)

     ,.shadow_translation_en_o(shadow_translation_en_n)
     ,.shadow_translation_en_w_o(shadow_translation_en_w)
     );

endmodule


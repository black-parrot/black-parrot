
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_ptw
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(pte_width_p)
   , parameter `BSG_INV_PARAM(page_table_depth_p)
   , parameter `BSG_INV_PARAM(pte_size_in_bytes_p)
   , parameter `BSG_INV_PARAM(page_idx_width_p)

   , localparam trans_info_width_lp   = `bp_be_trans_info_width(ptag_width_p)
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   )
  (input                                      clk_i
   , input                                    reset_i

   // Slow control signals
   , output                                   busy_o
   , input [commit_pkt_width_lp-1:0]          commit_pkt_i
   , input [trans_info_width_lp-1:0]          trans_info_i
   , input                                    ordered_i

   , output logic                             v_o
   , output logic                             walk_o
   , output logic                             itlb_fill_o
   , output logic                             dtlb_fill_o
   , output logic                             instr_page_fault_o
   , output logic                             load_page_fault_o
   , output logic                             store_page_fault_o
   , output logic [fetch_ptr_gp-1:0]          count_o
   , output logic [dword_width_gp-1:0]        addr_o
   , output logic [dword_width_gp-1:0]        pte_o

   , input                                    v_i
   , input [dword_width_gp-1:0]               data_i
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_i(bp_be_trans_info_s, trans_info);

  enum logic [1:0] {e_idle, e_wait, e_send_load, e_writeback} state_n, state_r;
  wire is_idle  = (state_r == e_idle);
  wire is_wait  = (state_r == e_wait);
  wire is_send  = (state_r == e_send_load);
  wire is_write = (state_r == e_writeback);

  localparam lg_pte_size_in_bytes_lp = `BSG_SAFE_CLOG2(pte_size_in_bytes_p);
  localparam lg_page_table_depth_lp = `BSG_SAFE_CLOG2(page_table_depth_p);
  localparam pte_ptag_offset_lp = (page_table_depth_p-1)*page_idx_width_p;

  sv39_pte_s dcache_pte;
  assign dcache_pte = data_i;

  logic [ptag_width_p-1:0]           ppn_r, ppn_n;
  logic [lg_page_table_depth_lp-1:0] level_n, level_r;
  logic instr_n, instr_r;
  logic store_n, store_r;
  logic load_n, load_r;
  logic [fetch_ptr_gp-1:0] count_n, count_r;
  logic [vaddr_width_p-1:0] vaddr_n, vaddr_r;

  logic [dword_width_gp-1:0] vpn;
  logic [dword_width_gp-1:0] ppn;
  logic [page_table_depth_p-1:0][page_idx_width_p-1:0] partial_vpn;
  logic [page_table_depth_p-1:0][page_idx_width_p-1:0] partial_ppn;

  assign vpn = vaddr_r >> sv39_page_offset_width_gp;
  for (genvar i = 0; i < page_table_depth_p; i++)
    begin : rof1
      assign partial_vpn[i] = vpn[page_idx_width_p*i+:page_idx_width_p];
      assign partial_ppn[i] = ppn[page_idx_width_p*i+:page_idx_width_p];
    end
  wire [ptag_width_p-1:0] writeback_ppn =
    (((level_r > 0) ? partial_vpn[0] : partial_ppn[0]) << 0*page_idx_width_p)
    | (((level_r > 1) ? partial_vpn[1] : partial_ppn[1]) << 1*page_idx_width_p)
    | (((level_r > 2) ? partial_vpn[2] : partial_ppn[2]) << 2*page_idx_width_p)
    | (dcache_pte.ppn[ptag_width_p-1:pte_ptag_offset_lp] << pte_ptag_offset_lp);

  // PMA attributes
  assign busy_o                 = ~is_idle;

  wire pte_is_leaf              = dcache_pte.x | dcache_pte.w | dcache_pte.r;
  wire pte_is_kilopage          = (level_r == 2'd0);
  wire pte_is_megapage          = (level_r == 2'd1);
  wire pte_is_gigapage          = (level_r == 2'd2);

  wire pte_invalid              = ~dcache_pte.v | (~dcache_pte.r & dcache_pte.w);
  wire leaf_not_found           = pte_is_kilopage & ~pte_is_leaf;
  wire s_priv_req               = pte_is_leaf & (trans_info_cast_i.priv_mode == `PRIV_MODE_S) & (instr_r | ~trans_info_cast_i.mstatus_sum);
  wire u_priv_req               = pte_is_leaf & (trans_info_cast_i.priv_mode == `PRIV_MODE_U);
  wire priv_fault               = pte_is_leaf & ((dcache_pte.u & s_priv_req) | (~dcache_pte.u & u_priv_req));
  wire misaligned_superpage     = pte_is_leaf & |level_r & |dcache_pte.ppn[page_idx_width_p*(level_r-1'b1)+:page_idx_width_p];

  wire ad_fault                 = pte_is_leaf & (~dcache_pte.a | (store_r & ~dcache_pte.d));
  wire common_faults            = pte_invalid | leaf_not_found | priv_fault | misaligned_superpage | ad_fault;

  wire instr_page_fault         = instr_r & (common_faults | (pte_is_leaf & ~dcache_pte.x));
  wire load_page_fault          = load_r  & (common_faults | (pte_is_leaf & ~(dcache_pte.r | (dcache_pte.x & trans_info_cast_i.mstatus_mxr))));
  wire store_page_fault         = store_r & (common_faults | (pte_is_leaf & ~dcache_pte.w));
  wire page_fault_v             = instr_page_fault | load_page_fault | store_page_fault;
  wire fill_v                   = pte_is_leaf & ~page_fault_v;

  wire tlb_miss_v               = commit_pkt_cast_i.itlb_miss | commit_pkt_cast_i.dtlb_store_miss | commit_pkt_cast_i.dtlb_load_miss;

  wire walk_start               = is_idle  & tlb_miss_v;
  wire walk_ready               = is_wait  & ordered_i;
  wire walk_send                = is_send;
  wire walk_replay              = commit_pkt_cast_i.dcache_replay;
  wire walk_next                = v_i & ~(pte_is_leaf | page_fault_v);
  wire walk_done                = v_i &  (pte_is_leaf | page_fault_v);

  wire [page_offset_width_gp-1:0] walk_offset = (partial_vpn[level_n] << lg_pte_size_in_bytes_lp);
  wire [paddr_width_p-1:0] walk_addr = {ppn, walk_offset};

  assign instr_n = commit_pkt_cast_i.itlb_miss;
  assign load_n = commit_pkt_cast_i.dtlb_load_miss;
  assign store_n = commit_pkt_cast_i.dtlb_store_miss;
  assign count_n = commit_pkt_cast_i.count;
  assign vaddr_n = commit_pkt_cast_i.vaddr;
  bsg_dff_en
   #(.width_p(3+fetch_ptr_gp+vaddr_width_p))
   miss_reg
    (.clk_i(clk_i)
     ,.en_i(walk_start)
     ,.data_i({instr_n, load_n, store_n, count_n, vaddr_n})
     ,.data_o({instr_r, load_r, store_r, count_r, vaddr_r})
     );

  assign ppn_n = walk_start ? trans_info_cast_i.base_ppn : dcache_pte.ppn;
  assign level_n = walk_start ? page_table_depth_p-1'b1 : level_r-walk_next;
  wire walk_en = walk_start | walk_next | walk_done;
  bsg_dff_en
   #(.width_p(lg_page_table_depth_lp+ptag_width_p))
   walk_reg
    (.clk_i(clk_i)
     ,.en_i(walk_en)
     ,.data_i({level_n, ppn_n})
     ,.data_o({level_r, ppn_r})
     );
  assign ppn = walk_en ? ppn_n : ppn_r;

  bp_be_pte_leaf_s tlb_w_entry;
  assign tlb_w_entry.ptag     = writeback_ppn;
  assign tlb_w_entry.gigapage = pte_is_gigapage;
  assign tlb_w_entry.megapage = pte_is_megapage;
  assign tlb_w_entry.a        = dcache_pte.a;
  assign tlb_w_entry.d        = dcache_pte.d;
  assign tlb_w_entry.u        = dcache_pte.u;
  assign tlb_w_entry.x        = dcache_pte.x;
  assign tlb_w_entry.w        = dcache_pte.w;
  assign tlb_w_entry.r        = dcache_pte.r;

  assign v_o                = walk_send | walk_next | walk_done;
  assign walk_o             = walk_send | walk_next;
  assign itlb_fill_o        = walk_done &  instr_r & ~page_fault_v;
  assign dtlb_fill_o        = walk_done & ~instr_r & ~page_fault_v;
  assign instr_page_fault_o = walk_done & instr_page_fault;
  assign load_page_fault_o  = walk_done & load_page_fault;
  assign store_page_fault_o = walk_done & store_page_fault;
  assign count_o            = walk_done ? count_r : '0;
  assign addr_o             = walk_done ? vaddr_r : walk_addr;
  assign pte_o              = tlb_w_entry;

  // Because internal dcache flushing is a possibility, we need to manually replay
  //   rather than relying on the late writeback
  always_comb
    case (state_r)
      e_idle      : state_n = walk_start         ? e_wait       : e_idle;
      e_wait      : state_n = walk_ready         ? e_send_load  : e_wait;
      e_send_load : state_n = walk_send          ? e_writeback  : e_send_load;
      e_writeback : state_n = walk_replay
                              ? e_wait
                              : walk_done
                                ? e_idle
                                : e_writeback;
      default : state_n = e_idle;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_idle;
    else
      state_r <= state_n;

endmodule

`BSG_ABSTRACT_MODULE(bp_be_ptw)



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

   , localparam dcache_pkt_width_lp   = `bp_be_dcache_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam trans_info_width_lp   = `bp_be_trans_info_width(ptag_width_p)
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   // Slow control signals
   , input [commit_pkt_width_lp-1:0]          commit_pkt_i
   , input [trans_info_width_lp-1:0]          trans_info_i
   , output                                   busy_o
   , input                                    ordered_i

   // D-Cache connections
   , output logic                             dcache_v_o
   , output logic [dcache_pkt_width_lp-1:0]   dcache_pkt_o
   , output logic [ptag_width_p-1:0]          dcache_ptag_o
   , output logic                             dcache_ptag_v_o
   , input                                    dcache_ready_and_i

   , input                                    dcache_early_v_i
   , input                                    dcache_early_req_i

   , input                                    dcache_final_v_i
   , input                                    dcache_final_ptw_i
   , input [dpath_width_gp-1:0]               dcache_final_data_i

   , output logic [ptw_fill_pkt_width_lp-1:0] ptw_fill_pkt_o
   , output logic                             ptw_fill_v_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_dcache_pkt_s(vaddr_width_p);
  `bp_cast_o(bp_be_dcache_pkt_s, dcache_pkt);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_i(bp_be_trans_info_s, trans_info);
  `bp_cast_o(bp_be_ptw_fill_pkt_s, ptw_fill_pkt);

  enum logic [2:0] {e_idle, e_wait, e_send_load, e_check_load, e_writeback} state_n, state_r;
  wire is_idle    = (state_r == e_idle);
  wire is_wait    = (state_r == e_wait);
  wire is_send    = (state_r == e_send_load);
  wire is_check   = (state_r == e_check_load);
  wire is_write   = (state_r == e_writeback);

  localparam lg_pte_size_in_bytes_lp = `BSG_SAFE_CLOG2(pte_size_in_bytes_p);
  localparam lg_page_table_depth_lp = `BSG_SAFE_CLOG2(page_table_depth_p);
  localparam pte_ptag_offset_lp = (page_table_depth_p-1)*page_idx_width_p;

  sv39_pte_s dcache_pte;
  assign dcache_pte = dcache_final_data_i[0+:dword_width_gp];

  logic [ptag_width_p-1:0]           ppn_r, ppn_n;
  logic [lg_page_table_depth_lp-1:0] level_n, level_r;
  logic instr_n, instr_r;
  logic store_n, store_r;
  logic load_n, load_r;
  logic partial_n, partial_r;
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

  assign dcache_ptag_o          = ppn_r;
  assign dcache_ptag_v_o        = is_check;

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
  wire walk_replay              = is_check & ~dcache_early_v_i & ~dcache_early_req_i;
  wire walk_next                = is_write & dcache_final_v_i & ~(pte_is_leaf | page_fault_v);
  wire walk_done                = is_write & dcache_final_v_i &  (pte_is_leaf | page_fault_v);

  wire itlb_fill_v              =  instr_r & ~page_fault_v;
  wire dtlb_fill_v              = ~instr_r & ~page_fault_v;

  assign dcache_v_o                    = walk_send | walk_next;
  assign dcache_pkt_cast_o.opcode      = e_dcache_op_ptw;
  assign dcache_pkt_cast_o.vaddr       = partial_vpn[level_n] << lg_pte_size_in_bytes_lp;
  assign dcache_pkt_cast_o.rd_addr     = '0;

  bp_be_pte_leaf_s tlb_w_entry;
  assign tlb_w_entry.ptag       = writeback_ppn;
  assign tlb_w_entry.gigapage   = pte_is_gigapage;
  assign tlb_w_entry.megapage   = pte_is_megapage;
  assign tlb_w_entry.a          = dcache_pte.a;
  assign tlb_w_entry.d          = dcache_pte.d;
  assign tlb_w_entry.u          = dcache_pte.u;
  assign tlb_w_entry.x          = dcache_pte.x;
  assign tlb_w_entry.w          = dcache_pte.w;
  assign tlb_w_entry.r          = dcache_pte.r;

  assign ptw_fill_v_o                           = walk_done;
  assign ptw_fill_pkt_cast_o.v                  = walk_done; 
  assign ptw_fill_pkt_cast_o.itlb_fill_v        = walk_done & itlb_fill_v;
  assign ptw_fill_pkt_cast_o.dtlb_fill_v        = walk_done & dtlb_fill_v;
  assign ptw_fill_pkt_cast_o.instr_page_fault_v = walk_done & instr_page_fault;
  assign ptw_fill_pkt_cast_o.load_page_fault_v  = walk_done & load_page_fault;
  assign ptw_fill_pkt_cast_o.store_page_fault_v = walk_done & store_page_fault;
  assign ptw_fill_pkt_cast_o.partial            = walk_done & partial_r;
  assign ptw_fill_pkt_cast_o.vaddr              = vaddr_r;
  assign ptw_fill_pkt_cast_o.entry              = tlb_w_entry;

  assign instr_n = commit_pkt_cast_i.itlb_miss;
  assign load_n = commit_pkt_cast_i.dtlb_load_miss;
  assign store_n = commit_pkt_cast_i.dtlb_store_miss;
  assign partial_n = commit_pkt_cast_i.partial;
  assign vaddr_n = commit_pkt_cast_i.vaddr;
  bsg_dff_en
   #(.width_p(4+vaddr_width_p))
   miss_reg
    (.clk_i(clk_i)
     ,.en_i(walk_start)
     ,.data_i({instr_n, load_n, store_n, partial_n, vaddr_n})
     ,.data_o({instr_r, load_r, store_r, partial_r, vaddr_r})
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

  // Because internal dcache flushing is a possibility, we need to manually replay
  //   rather than relying on the late writeback
  always_comb
    case (state_r)
      e_idle      : state_n = walk_start         ? e_wait       : e_idle;
      e_wait      : state_n = walk_ready         ? e_send_load  : e_wait;
      e_send_load : state_n = walk_send          ? e_check_load : e_send_load;
      e_check_load: state_n = walk_replay        ? e_send_load  : e_writeback;
      e_writeback : state_n = walk_done
                              ? e_idle
                              : walk_next
                                ? e_check_load
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


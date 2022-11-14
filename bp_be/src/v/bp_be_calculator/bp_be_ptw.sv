
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
   , localparam ptw_miss_pkt_width_lp = `bp_be_ptw_miss_pkt_width(vaddr_width_p, ptag_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   // Slow control signals
   , output                                 busy_o

   // TLB miss and fill interfaces
   , input [ptw_miss_pkt_width_lp-1:0]      ptw_miss_pkt_i
   , output [ptw_fill_pkt_width_lp-1:0]     ptw_fill_pkt_o

   // D-Cache connections
   , output logic                           dcache_v_o
   , output logic [dcache_pkt_width_lp-1:0] dcache_pkt_o
   , output logic [ptag_width_p-1:0]        dcache_ptag_o
   , output logic                           dcache_ptag_v_o
   , input                                  dcache_ready_i

   , input                                  dcache_early_hit_v_i
   , input [dpath_width_gp-1:0]             dcache_early_data_i
  );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_dcache_pkt_s(vaddr_width_p);
  `bp_cast_o(bp_be_dcache_pkt_s, dcache_pkt);
  `bp_cast_i(bp_be_ptw_miss_pkt_s, ptw_miss_pkt);
  `bp_cast_o(bp_be_ptw_fill_pkt_s, ptw_fill_pkt);

  enum logic [2:0] {e_idle, e_send_load, e_recv_load, e_check_load, e_writeback} state_n, state_r;
  wire is_idle  = (state_r == e_idle);
  wire is_send  = (state_r == e_send_load);
  wire is_recv  = (state_r == e_recv_load);
  wire is_check = (state_r == e_check_load);
  wire is_write = (state_r == e_writeback);

  localparam lg_page_table_depth_lp = `BSG_SAFE_CLOG2(page_table_depth_p);
  logic start;
  logic [lg_page_table_depth_lp-1:0] level_cntr;
  logic                              level_cntr_en;
  logic [ptag_width_p-1:0]           ppn_r, ppn_n, writeback_ppn;
  logic                              ppn_en;
  bp_be_ptw_miss_pkt_s               ptw_miss_pkt_r;

  logic [vtag_width_p-1:0] vpn;
  logic [page_table_depth_p-1:0][page_idx_width_p-1:0] partial_vpn;
  logic [page_table_depth_p-2:0][page_idx_width_p-1:0] partial_ppn;
  logic [page_table_depth_p-2:0] partial_pte_misaligned;

  logic tlb_miss_v, page_fault_v;

  sv39_pte_s dcache_pte_n, dcache_pte_r;
  assign dcache_pte_n = dcache_early_data_i[0+:dword_width_gp];
  bsg_dff_en
   #(.width_p($bits(sv39_pte_s)))
   dcache_pte_reg
    (.clk_i(clk_i)
     ,.en_i(is_recv)
     ,.data_i(dcache_pte_n)
     ,.data_o(dcache_pte_r)
     );

  for(genvar i=0; i<page_table_depth_p; i++) begin : rof1
     assign partial_vpn[i] = vpn[page_idx_width_p*i +: page_idx_width_p];
   end
  for(genvar i=0; i<page_table_depth_p-1; i++) begin : rof2
     assign partial_ppn[i] = ppn_r[page_idx_width_p*i +: page_idx_width_p];
     assign partial_pte_misaligned[i] = (level_cntr > i)? |dcache_pte_r.ppn[page_idx_width_p*i +: page_idx_width_p] : 1'b0;
     assign writeback_ppn[page_idx_width_p*i +: page_idx_width_p] = (level_cntr > i) ? partial_vpn[i] : partial_ppn[i];
   end
   assign writeback_ppn[ptag_width_p-1 : (page_table_depth_p-1)*page_idx_width_p] = ppn_r[ptag_width_p-1 : (page_table_depth_p-1)*page_idx_width_p];

  assign dcache_ptag_o          = ppn_r;
  assign dcache_ptag_v_o        = is_recv;

  // PMA attributes
  localparam lg_pte_size_in_bytes_lp = `BSG_SAFE_CLOG2(pte_size_in_bytes_p);
  assign dcache_v_o                    = is_send;
  assign dcache_pkt_cast_o.opcode      = e_dcache_op_ptw_ld;
  assign dcache_pkt_cast_o.vaddr       = partial_vpn[level_cntr] << lg_pte_size_in_bytes_lp;
  assign dcache_pkt_cast_o.data        = '0;
  assign dcache_pkt_cast_o.rd_addr     = '0;

  assign busy_o                 = ~is_idle;

  assign start                  = is_idle & tlb_miss_v;

  wire pte_is_leaf              = dcache_pte_r.x | dcache_pte_r.w | dcache_pte_r.r;
  wire pte_is_megapage          = (level_cntr == 2'd1);
  wire pte_is_gigapage          = (level_cntr == 2'd2);

  assign level_cntr_en          = is_check & ~pte_is_leaf & ~page_fault_v;

  assign ppn_en                 = start | is_check;
  assign ppn_n                  = is_idle ? ptw_miss_pkt_cast_i.base_ppn : dcache_pte_r.ppn[0+:ptag_width_p];

  wire pte_invalid              = (~dcache_pte_r.v) | (~dcache_pte_r.r & dcache_pte_r.w);
  wire leaf_not_found           = (level_cntr == '0) & (~pte_is_leaf);
  wire priv_fault               = pte_is_leaf & ((dcache_pte_r.u & (ptw_miss_pkt_r.priv_mode == `PRIV_MODE_S) & (ptw_miss_pkt_r.instr_miss_v | ~ptw_miss_pkt_r.mstatus_sum)) | (~dcache_pte_r.u & (ptw_miss_pkt_r.priv_mode == `PRIV_MODE_U)));
  wire misaligned_superpage     = pte_is_leaf & (|partial_pte_misaligned);
  wire ad_fault                 = pte_is_leaf & (~dcache_pte_r.a | (ptw_miss_pkt_r.store_miss_v & ~dcache_pte_r.d));
  wire common_faults            = pte_invalid | leaf_not_found | priv_fault | misaligned_superpage | ad_fault;

  wire instr_page_fault         = ptw_miss_pkt_r.instr_miss_v & (common_faults | (pte_is_leaf & ~dcache_pte_r.x));
  wire load_page_fault          = ptw_miss_pkt_r.load_miss_v  & (common_faults | (pte_is_leaf & ~(dcache_pte_r.r | (dcache_pte_r.x & ptw_miss_pkt_r.mstatus_mxr))));
  wire store_page_fault         = ptw_miss_pkt_r.store_miss_v & (common_faults | (pte_is_leaf & ~dcache_pte_r.w));
  assign page_fault_v           = (instr_page_fault | load_page_fault | store_page_fault);

  wire itlb_fill_v              = ptw_miss_pkt_r.instr_miss_v & ~page_fault_v;
  wire dtlb_fill_v              = ~ptw_miss_pkt_r.instr_miss_v & ~page_fault_v;

  bp_be_pte_leaf_s tlb_w_entry;
  assign tlb_w_entry.ptag       = writeback_ppn;
  assign tlb_w_entry.gigapage   = pte_is_gigapage;
  assign tlb_w_entry.a          = dcache_pte_r.a;
  assign tlb_w_entry.d          = dcache_pte_r.d;
  assign tlb_w_entry.u          = dcache_pte_r.u;
  assign tlb_w_entry.x          = dcache_pte_r.x;
  assign tlb_w_entry.w          = dcache_pte_r.w;
  assign tlb_w_entry.r          = dcache_pte_r.r;

  assign ptw_fill_pkt_cast_o.v                  = is_write;
  assign ptw_fill_pkt_cast_o.itlb_fill_v        = is_write & itlb_fill_v;
  assign ptw_fill_pkt_cast_o.dtlb_fill_v        = is_write & dtlb_fill_v;
  assign ptw_fill_pkt_cast_o.instr_page_fault_v = is_write & instr_page_fault;
  assign ptw_fill_pkt_cast_o.load_page_fault_v  = is_write & load_page_fault;
  assign ptw_fill_pkt_cast_o.store_page_fault_v = is_write & store_page_fault;
  assign ptw_fill_pkt_cast_o.partial            = is_write & ptw_miss_pkt_r.partial;
  assign ptw_fill_pkt_cast_o.vaddr              = ptw_miss_pkt_r.vaddr;
  assign ptw_fill_pkt_cast_o.entry              = tlb_w_entry;

  assign tlb_miss_v   = ptw_miss_pkt_cast_i.instr_miss_v
                        | ptw_miss_pkt_cast_i.load_miss_v
                        | ptw_miss_pkt_cast_i.store_miss_v;

  wire [lg_page_table_depth_lp-1:0] max_level_li = page_table_depth_p-1'b1;
  bsg_counter_set_down
   #(.width_p(lg_page_table_depth_lp), .set_and_down_exclusive_p(1))
   level_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(start)
     ,.val_i(max_level_li)
     ,.down_i(level_cntr_en)
     ,.count_r_o(level_cntr)
     );

  bsg_dff_reset_en
   #(.width_p($bits(bp_be_ptw_miss_pkt_s)))
   miss_pkt_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i(ptw_miss_pkt_cast_i)
     ,.data_o(ptw_miss_pkt_r)
     );
  assign vpn = ptw_miss_pkt_r.vaddr[vaddr_width_p-1-:vtag_width_p];

  bsg_dff_reset_en
   #(.width_p(ptag_width_p))
   ppn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ppn_en)
     ,.data_i(ppn_n)
     ,.data_o(ppn_r)
     );

  // If flushing is a possibility, then we need to manually replay. However, this should
  //   not be the case, because the pipeline should not flush after TLB miss, since they
  //   are non-speculative
  always_comb begin
    case(state_r)
      e_idle      :  state_n = tlb_miss_v ? e_send_load : e_idle;
      e_send_load :  state_n = (dcache_ready_i & dcache_v_o) ? e_recv_load : e_send_load;
      e_recv_load :  state_n = dcache_early_hit_v_i ? e_check_load : e_send_load;
      e_check_load:  state_n = (pte_is_leaf | page_fault_v) ? e_writeback : e_send_load;
      default: // e_writeback
                    state_n = e_idle;
    endcase
  end

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      state_r <= e_idle;
    end
    else begin
      state_r <= state_n;
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_be_ptw)


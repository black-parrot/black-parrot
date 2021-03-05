
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_ptw
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter pte_width_p         = sv39_pte_width_gp
   , parameter page_table_depth_p  = sv39_levels_gp
   , parameter pte_size_in_bytes_p = sv39_pte_size_in_bytes_gp
   , parameter page_idx_width_p    = sv39_page_idx_width_gp

   , localparam dcache_pkt_width_lp     = $bits(bp_be_dcache_pkt_s)
   , localparam tlb_entry_width_lp      = `bp_be_pte_leaf_width(paddr_width_p)
   , localparam ptw_miss_pkt_width_lp   = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp   = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   // Slow control signals
   , input [ptag_width_p-1:0]               base_ppn_i
   , input [rv64_priv_width_gp-1:0]         priv_mode_i
   , input                                  mstatus_sum_i
   , input                                  mstatus_mxr_i
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

   , input                                  dcache_v_i
   , input [dpath_width_gp-1:0]             dcache_data_i
  );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  enum logic [2:0] { eIdle, eSendLoad, eWaitLoad, eRecvLoad, eWriteBack } state_n, state_r;

  bp_be_dcache_pkt_s   dcache_pkt_cast_o;
  sv39_pte_s           dcache_data;
  bp_be_pte_leaf_s     tlb_w_entry;
  bp_be_ptw_miss_pkt_s ptw_miss_pkt_cast_i;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt_cast_o;

  assign ptw_miss_pkt_cast_i = ptw_miss_pkt_i;
  assign ptw_fill_pkt_o = ptw_fill_pkt_cast_o;

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

  logic [dword_width_gp-1:0] dcache_data_r;
  logic dcache_v_r;

   for(genvar i=0; i<page_table_depth_p; i++) begin : rof1
      assign partial_vpn[i] = vpn[page_idx_width_p*i +: page_idx_width_p];
    end
   for(genvar i=0; i<page_table_depth_p-1; i++) begin : rof2
      assign partial_ppn[i] = ppn_r[page_idx_width_p*i +: page_idx_width_p];
      assign partial_pte_misaligned[i] = (level_cntr > i)? |dcache_data.ppn[page_idx_width_p*i +: page_idx_width_p] : 1'b0;
      assign writeback_ppn[page_idx_width_p*i +: page_idx_width_p] = (level_cntr > i)? partial_vpn[i] : partial_ppn[i];
    end
    assign writeback_ppn[ptag_width_p-1 : (page_table_depth_p-1)*page_idx_width_p] = ppn_r[ptag_width_p-1 : (page_table_depth_p-1)*page_idx_width_p];

  assign dcache_pkt_o           = dcache_pkt_cast_o;
  assign dcache_ptag_o          = ppn_r;
  assign dcache_ptag_v_o        = (state_r == eWaitLoad);
  assign dcache_data            = dcache_data_r;

  // PMA attributes
  localparam lg_pte_size_in_bytes_lp = `BSG_SAFE_CLOG2(pte_size_in_bytes_p);
  assign dcache_v_o                    = dcache_ready_i & (state_r == eSendLoad);
  assign dcache_pkt_cast_o.opcode      = e_dcache_op_ld;
  assign dcache_pkt_cast_o.page_offset = {partial_vpn[level_cntr], (lg_pte_size_in_bytes_lp)'(0)};
  assign dcache_pkt_cast_o.data        = '0;
  assign dcache_pkt_cast_o.rd_addr     = '0;

  assign busy_o                 = (state_r != eIdle);

  assign start                  = (state_r == eIdle) & tlb_miss_v;

  wire pte_is_leaf              = dcache_data.x | dcache_data.w | dcache_data.r;
  wire pte_is_megapage          = (level_cntr == 2'd1);
  wire pte_is_gigapage          = (level_cntr == 2'd2);

  assign level_cntr_en          = busy_o & dcache_v_r & ~pte_is_leaf & ~page_fault_v;

  assign ppn_en                 = start | (busy_o & dcache_v_r);
  assign ppn_n                  = (state_r == eIdle)? base_ppn_i : dcache_data.ppn[0+:ptag_width_p];

  wire pte_invalid              = (~dcache_data.v) | (~dcache_data.r & dcache_data.w);
  wire leaf_not_found           = (level_cntr == '0) & (~pte_is_leaf);
  wire priv_fault               = pte_is_leaf & ((dcache_data.u & (priv_mode_i == `PRIV_MODE_S) & (ptw_miss_pkt_r.instr_miss_v | ~mstatus_sum_i)) | (~dcache_data.u & (priv_mode_i == `PRIV_MODE_U)));
  wire misaligned_superpage     = pte_is_leaf & (|partial_pte_misaligned);
  wire ad_fault                 = pte_is_leaf & (~dcache_data.a | (ptw_miss_pkt_r.store_miss_v & ~dcache_data.d));
  wire common_faults            = pte_invalid | leaf_not_found | priv_fault | misaligned_superpage | ad_fault;

  assign ptw_fill_pkt_cast_o.v                  = (state_r == eWriteBack) || page_fault_v;
  assign ptw_fill_pkt_cast_o.itlb_fill_v        = (state_r == eWriteBack) &  ptw_miss_pkt_r.instr_miss_v;
  assign ptw_fill_pkt_cast_o.dtlb_fill_v        = (state_r == eWriteBack) & ~ptw_miss_pkt_r.instr_miss_v;
  assign ptw_fill_pkt_cast_o.instr_page_fault_v = busy_o
    & dcache_v_r & ptw_miss_pkt_r.instr_miss_v
    & (common_faults | (pte_is_leaf & ~dcache_data.x));
  assign ptw_fill_pkt_cast_o.load_page_fault_v  = busy_o
    & dcache_v_r & ptw_miss_pkt_r.load_miss_v
    & (common_faults | (pte_is_leaf & ~(dcache_data.r | (dcache_data.x & mstatus_mxr_i))));
  assign ptw_fill_pkt_cast_o.store_page_fault_v = busy_o
    & dcache_v_r & ptw_miss_pkt_r.store_miss_v
    & (common_faults | (pte_is_leaf & ~dcache_data.w));
  assign ptw_fill_pkt_cast_o.vaddr              = ptw_miss_pkt_r.vaddr;
  assign ptw_fill_pkt_cast_o.entry              = tlb_w_entry;

  assign tlb_w_entry.ptag       = writeback_ppn;
  assign tlb_w_entry.gigapage   = pte_is_gigapage;
  assign tlb_w_entry.a          = dcache_data.a;
  assign tlb_w_entry.d          = dcache_data.d;
  assign tlb_w_entry.u          = dcache_data.u;
  assign tlb_w_entry.x          = dcache_data.x;
  assign tlb_w_entry.w          = dcache_data.w;
  assign tlb_w_entry.r          = dcache_data.r;

  assign tlb_miss_v   = ptw_miss_pkt_cast_i.instr_miss_v
                        | ptw_miss_pkt_cast_i.load_miss_v
                        | ptw_miss_pkt_cast_i.store_miss_v;
  assign page_fault_v = ptw_fill_pkt_cast_o.instr_page_fault_v
                        | ptw_fill_pkt_cast_o.load_page_fault_v
                        | ptw_fill_pkt_cast_o.store_page_fault_v;

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

  bsg_dff_reset #(.width_p(1+dword_width_gp))
    dcache_data_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({dcache_v_i, dcache_data_i[0+:dword_width_gp]})
     ,.data_o({dcache_v_r, dcache_data_r})
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

  always_comb begin
    case(state_r)
      eIdle:      state_n = tlb_miss_v ? eSendLoad : eIdle;
      eSendLoad:  state_n = dcache_ready_i ? eWaitLoad : eSendLoad;
      eWaitLoad:  state_n = eRecvLoad;
      eRecvLoad:  state_n = (dcache_v_r
                             ? (page_fault_v
                                ? eIdle
                                : (pte_is_leaf ? eWriteBack : eSendLoad))
                             : eSendLoad);
      eWriteBack: state_n = eIdle;
      default: state_n = eIdle;
    endcase
  end

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      state_r <= eIdle;
    end
    else begin
      state_r <= state_n;
    end
  end

endmodule


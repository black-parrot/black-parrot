
module bp_be_ptw
  import bp_common_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

    ,parameter pte_width_p              = bp_sv39_pte_width_gp
    ,parameter page_table_depth_p       = bp_sv39_page_table_depth_gp

    ,localparam ptw_miss_pkt_width_lp   = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
    ,localparam ptw_fill_pkt_width_lp   = `bp_be_ptw_fill_pkt_width(vaddr_width_p)

    ,localparam dcache_pkt_width_lp     = `bp_be_dcache_pkt_width(page_offset_width_p, dpath_width_p)
    ,localparam tlb_entry_width_lp      = `bp_pte_entry_leaf_width(paddr_width_p)
    ,localparam lg_page_table_depth_lp  = `BSG_SAFE_CLOG2(page_table_depth_p)

    ,localparam pte_size_in_bytes_lp    = pte_width_p/rv64_byte_width_gp
    ,localparam lg_pte_size_in_bytes_lp = `BSG_SAFE_CLOG2(pte_size_in_bytes_lp)
    ,localparam partial_vpn_width_lp    = page_offset_width_p - lg_pte_size_in_bytes_lp
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
   , input                                  dcache_rdy_i

   , input                                  dcache_v_i
   , input [dpath_width_p-1:0]              dcache_data_i
  );

  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_dcache_pkt_s(page_offset_width_p, dpath_width_p);
  `declare_bp_be_mem_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dcache_block_width_p/8)

  typedef enum logic [2:0] { eIdle, eSendLoad, eWaitLoad, eRecvLoad, eWriteBack, eStuck } state_e;

  bp_be_dcache_pkt_s  dcache_pkt;
  bp_sv39_pte_s       dcache_data;
  bp_pte_entry_leaf_s tlb_w_entry;
  bp_be_ptw_miss_pkt_s ptw_miss_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;

  assign ptw_miss_pkt = ptw_miss_pkt_i;
  assign ptw_fill_pkt_o = ptw_fill_pkt;

  state_e state_r, state_n;

  logic pte_is_leaf;
  logic start;
  logic [lg_page_table_depth_lp-1:0] level_cntr;
  logic                              level_cntr_en;
  logic [vtag_width_p-1:0]           vpn_r, vpn_n;
  logic [ptag_width_p-1:0]           ppn_r, ppn_n, writeback_ppn;
  logic                              ppn_en;
  logic [vaddr_width_p-1:0]          ptw_pc_r;
  logic [vaddr_width_p-1:0]          ptw_vaddr_r;

  logic [page_table_depth_p-1:0] [partial_vpn_width_lp-1:0] partial_vpn;
  logic [page_table_depth_p-2:0] [partial_vpn_width_lp-1:0] partial_ppn;
  logic [page_table_depth_p-2:0] partial_pte_misaligned;

  logic instr_ptw_r, load_ptw_r, store_ptw_r;

  logic tlb_miss_v, page_fault_v;

  logic [dword_width_p-1:0] dcache_data_r;
  logic dcache_v_r;

   for(genvar i=0; i<page_table_depth_p; i++) begin : vpn
      assign partial_vpn[i] = vpn_r[partial_vpn_width_lp*i +: partial_vpn_width_lp];
    end
   for(genvar i=0; i<page_table_depth_p-1; i++) begin : ppn
      assign partial_ppn[i] = ppn_r[partial_vpn_width_lp*i +: partial_vpn_width_lp];
      assign partial_pte_misaligned[i] = (level_cntr > i)? |dcache_data.ppn[partial_vpn_width_lp*i +: partial_vpn_width_lp] : 1'b0;
      assign writeback_ppn[partial_vpn_width_lp*i +: partial_vpn_width_lp] = (level_cntr > i)? partial_vpn[i] : partial_ppn[i];
    end
    assign writeback_ppn[ptag_width_p-1 : (page_table_depth_p-1)*partial_vpn_width_lp] = ppn_r[ptag_width_p-1 : (page_table_depth_p-1)*partial_vpn_width_lp];

  assign dcache_pkt_o           = dcache_pkt;
  assign dcache_ptag_o          = ppn_r;
  assign dcache_ptag_v_o        = (state_r == eWaitLoad);
  assign dcache_data            = dcache_data_r;

  // PMA attributes
  assign dcache_v_o             = dcache_rdy_i & (state_r == eSendLoad);
  assign dcache_pkt.opcode      = e_dcache_op_ld;
  assign dcache_pkt.page_offset = {partial_vpn[level_cntr], (lg_pte_size_in_bytes_lp)'(0)};
  assign dcache_pkt.data        = '0;

  assign busy_o                 = (state_r != eIdle);

  assign start                  = (state_r == eIdle) & tlb_miss_v;

  assign pte_is_leaf            = dcache_data.x | dcache_data.w | dcache_data.r;

  assign level_cntr_en          = busy_o & dcache_v_r & ~pte_is_leaf;

  assign ppn_en                 = start | (busy_o & dcache_v_r);
  assign ppn_n                  = (state_r == eIdle)? base_ppn_i : dcache_data.ppn[0+:ptag_width_p];
  assign vpn_n                  = ptw_miss_pkt.vaddr[vaddr_width_p-1-:vtag_width_p];

  wire pte_invalid              = (~dcache_data.v) | (~dcache_data.r & dcache_data.w);
  wire leaf_not_found           = (level_cntr == '0) & (~pte_is_leaf);
  wire priv_fault               = pte_is_leaf & ((dcache_data.u & (priv_mode_i == `PRIV_MODE_S) & (instr_ptw_r | ~mstatus_sum_i)) | (~dcache_data.u & (priv_mode_i == `PRIV_MODE_U)));
  wire misaligned_superpage     = pte_is_leaf & (|partial_pte_misaligned);
  wire ad_fault                 = pte_is_leaf & (~dcache_data.a | (store_ptw_r & ~dcache_data.d));
  wire common_faults            = pte_invalid | leaf_not_found | priv_fault | misaligned_superpage | ad_fault;

  assign ptw_fill_pkt.itlb_fill_v        = (state_r == eWriteBack) &  instr_ptw_r;
  assign ptw_fill_pkt.dtlb_fill_v        = (state_r == eWriteBack) & ~instr_ptw_r;
  assign ptw_fill_pkt.instr_page_fault_v = busy_o & dcache_v_r & instr_ptw_r & (common_faults | (pte_is_leaf & ~dcache_data.x));
  assign ptw_fill_pkt.load_page_fault_v  = busy_o & dcache_v_r & load_ptw_r & (common_faults | (pte_is_leaf & ~(dcache_data.r | (dcache_data.x & mstatus_mxr_i))));
  assign ptw_fill_pkt.store_page_fault_v = busy_o & dcache_v_r & store_ptw_r & (common_faults | (pte_is_leaf & ~dcache_data.w));
  assign ptw_fill_pkt.pc                 = ptw_pc_r;
  assign ptw_fill_pkt.vaddr              = ptw_vaddr_r;
  assign ptw_fill_pkt.entry              = tlb_w_entry;

  assign tlb_w_entry.ptag       = writeback_ppn;
  assign tlb_w_entry.a          = dcache_data.a;
  assign tlb_w_entry.d          = dcache_data.d;
  assign tlb_w_entry.u          = dcache_data.u;
  assign tlb_w_entry.x          = dcache_data.x;
  assign tlb_w_entry.w          = dcache_data.w;
  assign tlb_w_entry.r          = dcache_data.r;

  assign tlb_miss_v   = ptw_miss_pkt.instr_miss_v | ptw_miss_pkt.load_miss_v | ptw_miss_pkt.store_miss_v;
  assign page_fault_v = ptw_fill_pkt.instr_page_fault_v | ptw_fill_pkt.load_page_fault_v | ptw_fill_pkt.store_page_fault_v;

  always_comb begin
    case(state_r)
      eIdle:      state_n = tlb_miss_v ? eSendLoad : eIdle;
      eSendLoad:  state_n = dcache_rdy_i ? eWaitLoad : eSendLoad;
      eWaitLoad:  state_n = eRecvLoad;
      eRecvLoad:  state_n = (dcache_v_r
                             ? (page_fault_v
                                ? eIdle
                                : (pte_is_leaf ? eWriteBack : eSendLoad))
                             : eSendLoad);
      eWriteBack: state_n = eIdle;
      default: state_n = eStuck;
    endcase
  end


  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      level_cntr <= '0;
    end
    else if(start) begin
      level_cntr <= page_table_depth_p - 1;
    end
    else if(level_cntr_en) begin
      level_cntr <= level_cntr - 'b1;
    end
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

  bsg_dff_reset #(.width_p(1+dword_width_p))
    dcache_data_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({dcache_v_i, dcache_data_i[0+:dword_width_p]})
     ,.data_o({dcache_v_r, dcache_data_r})
    );

  bsg_dff_reset_en #(.width_p(vtag_width_p))
    vpn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i(vpn_n)
     ,.data_o(vpn_r)
    );

  bsg_dff_reset_en #(.width_p(vaddr_width_p))
    miss_pc_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(start)
      ,.data_i(ptw_miss_pkt.pc)
      ,.data_o(ptw_pc_r)
      );

  bsg_dff_reset_en #(.width_p(vaddr_width_p))
    miss_vaddr_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(start)
      ,.data_i(ptw_miss_pkt.vaddr)
      ,.data_o(ptw_vaddr_r)
      );

  bsg_dff_reset_en #(.width_p(ptag_width_p))
    ppn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ppn_en)
     ,.data_i(ppn_n)
     ,.data_o(ppn_r)
    );

  bsg_dff_reset_en #(.width_p(3))
    walk_type_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i({ptw_miss_pkt.store_miss_v, ptw_miss_pkt.load_miss_v, ptw_miss_pkt.instr_miss_v})
     ,.data_o({store_ptw_r, load_ptw_r, instr_ptw_r})
     );

endmodule

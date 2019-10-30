
module bp_be_ptw
  import bp_common_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

    ,parameter pte_width_p              = bp_sv39_pte_width_gp
    ,parameter page_table_depth_p       = bp_sv39_page_table_depth_gp
    
    ,localparam dcache_pkt_width_lp     = `bp_be_dcache_pkt_width(page_offset_width_p, pte_width_p)    
    ,localparam tlb_entry_width_lp      = `bp_pte_entry_leaf_width(paddr_width_p)
    ,localparam lg_page_table_depth_lp  = `BSG_SAFE_CLOG2(page_table_depth_p)

    ,localparam pte_size_in_bytes_lp    = pte_width_p/rv64_byte_width_gp
    ,localparam lg_pte_size_in_bytes_lp = `BSG_SAFE_CLOG2(pte_size_in_bytes_lp)
    ,localparam partial_vpn_width_lp    = page_offset_width_p - lg_pte_size_in_bytes_lp
  )
  (input                                    clk_i
   , input                                  reset_i
   , input [ptag_width_p-1:0]               base_ppn_i
   , input [rv64_priv_width_gp-1:0]         priv_mode_i
   , input                                  translation_en_i
   , input                                  mstatus_sum_i
   , input                                  mstatus_mxr_i
   , output                                 busy_o
   
   , input                                  itlb_not_dtlb_i
   , output logic                           itlb_not_dtlb_o
   
   , input                                  store_not_load_i
   
   , output logic                           instr_page_fault_o
   , output logic                           load_page_fault_o
   , output logic                           store_page_fault_o
   
   // TLB connections
   , input                                  tlb_miss_v_i
   , input [vtag_width_p-1:0]               tlb_miss_vtag_i
   
   , output logic                           tlb_w_v_o
   , output logic [vtag_width_p-1:0]        tlb_w_vtag_o
   , output logic [tlb_entry_width_lp-1:0]  tlb_w_entry_o

   // D-Cache connections
   , input                                  dcache_v_i
   , input [pte_width_p-1:0]                dcache_data_i
   
   , output logic                           dcache_v_o
   , output logic [dcache_pkt_width_lp-1:0] dcache_pkt_o
   , output logic [ptag_width_p-1:0]        dcache_ptag_o
   , input                                  dcache_rdy_i
   , input                                  dcache_miss_i
  );
  
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_dcache_pkt_s(page_offset_width_p, pte_width_p);
  
  typedef enum bit [2:0] { eIdle, eSendLoad, eWaitLoad, eWriteBack, eStuck } state_e;
  
  bp_be_dcache_pkt_s  dcache_pkt;
  bp_sv39_pte_s       dcache_data;
  bp_pte_entry_leaf_s tlb_w_entry;
  
  state_e state_r, state_n;

  logic pte_is_leaf;
  logic start;
  logic [lg_page_table_depth_lp-1:0] level_cntr;
  logic                              level_cntr_en;
  logic [vtag_width_p-1:0]           vpn_r, vpn_n;
  logic [ptag_width_p-1:0]           ppn_r, ppn_n, writeback_ppn;
  logic                              ppn_en;
  
  logic [page_table_depth_p-1:0] [partial_vpn_width_lp-1:0] partial_vpn;
  logic [page_table_depth_p-2:0] [partial_vpn_width_lp-1:0] partial_ppn;
  logic [page_table_depth_p-2:0] partial_pte_misaligned;
  
  logic store_not_load_r;
  logic page_fault_v;

  genvar i;
  generate 
    for(i=0; i<page_table_depth_p; i++) begin
      assign partial_vpn[i] = vpn_r[partial_vpn_width_lp*i +: partial_vpn_width_lp];
    end
   for(i=0; i<page_table_depth_p-1; i++) begin
      assign partial_ppn[i] = ppn_r[partial_vpn_width_lp*i +: partial_vpn_width_lp];
      assign partial_pte_misaligned[i] = (level_cntr > i)? |dcache_data.ppn[partial_vpn_width_lp*i +: partial_vpn_width_lp] : 1'b0;
      assign writeback_ppn[partial_vpn_width_lp*i +: partial_vpn_width_lp] = (level_cntr > i)? partial_vpn[i] : partial_ppn[i];
    end
    assign writeback_ppn[ptag_width_p-1 : (page_table_depth_p-1)*partial_vpn_width_lp] = ppn_r[ptag_width_p-1 : (page_table_depth_p-1)*partial_vpn_width_lp];
  endgenerate
  
  assign dcache_pkt_o           = dcache_pkt;
  assign dcache_ptag_o          = ppn_r;
  assign dcache_data            = dcache_data_i;
  
  assign tlb_w_v_o              = (state_r == eWriteBack);
  assign tlb_w_vtag_o           = vpn_r;
  assign tlb_w_entry_o          = tlb_w_entry;
  
  assign tlb_w_entry.ptag       = translation_en_i ? writeback_ppn : ptag_width_p'(vpn_r);
  assign tlb_w_entry.g          = translation_en_i ? dcache_data.g : 1'b0;
  assign tlb_w_entry.u          = translation_en_i ? dcache_data.u : 1'b0;
  assign tlb_w_entry.x          = translation_en_i ? dcache_data.x : 1'b1;
  assign tlb_w_entry.w          = translation_en_i ? dcache_data.w : 1'b1;
  assign tlb_w_entry.r          = translation_en_i ? dcache_data.r : 1'b1;

  // PMA attributes
  assign tlb_w_entry.uc         = (tlb_w_entry.ptag < (dram_base_addr_gp >> page_offset_width_p));

  assign dcache_v_o             = (state_r == eSendLoad);
  assign dcache_pkt.opcode      = e_dcache_opcode_ld;
  assign dcache_pkt.page_offset = {partial_vpn[level_cntr], (lg_pte_size_in_bytes_lp)'(0)};
  assign dcache_pkt.data        = '0;
    
  assign busy_o                 = (state_r != eIdle);
    
  assign start                  = (state_r == eIdle) & tlb_miss_v_i;
  
  assign pte_is_leaf            = dcache_data.x | dcache_data.w | dcache_data.r;
  
  assign level_cntr_en          = busy_o & dcache_v_i & ~pte_is_leaf;
  
  assign ppn_en                 = start | (busy_o & dcache_v_i);
  assign ppn_n                  = (state_r == eIdle)? base_ppn_i : dcache_data.ppn[0+:ptag_width_p];
  assign vpn_n                  = tlb_miss_vtag_i;
  
  wire pte_invalid              = (~dcache_data.v) | (~dcache_data.r & dcache_data.w);
  wire leaf_not_found           = (level_cntr == '0) & (~pte_is_leaf);
  wire priv_fault               = pte_is_leaf & dcache_data.u & (priv_mode_i == `PRIV_MODE_S) & ~mstatus_sum_i;
  wire misaligned_superpage     = pte_is_leaf & (|partial_pte_misaligned);
  wire ad_fault                 = pte_is_leaf & (~dcache_data.a | (~itlb_not_dtlb_o & store_not_load_r & ~dcache_data.d));
  wire common_faults            = pte_invalid | leaf_not_found | priv_fault | misaligned_superpage | ad_fault;

  assign instr_page_fault_o     = busy_o & dcache_v_i & itlb_not_dtlb_o & (common_faults | (pte_is_leaf & ~dcache_data.x));
  assign load_page_fault_o      = busy_o & dcache_v_i & ~itlb_not_dtlb_o & ~store_not_load_r & (common_faults | (pte_is_leaf & ~(dcache_data.r | (dcache_data.x & mstatus_mxr_i))));
  assign store_page_fault_o     = busy_o & dcache_v_i & ~itlb_not_dtlb_o & store_not_load_r & (common_faults | (pte_is_leaf & ~dcache_data.w));
  assign page_fault_v           = instr_page_fault_o | load_page_fault_o | store_page_fault_o;
  
  always_comb begin
    case(state_r)
      eIdle:      state_n = tlb_miss_v_i 
                             ? (translation_en_i ? eSendLoad : eWriteBack) 
                             : eIdle;                           
      eSendLoad:  state_n = dcache_rdy_i ? eWaitLoad : eSendLoad; 
      eWaitLoad:  state_n = dcache_miss_i
                            ? eSendLoad
                            : (dcache_v_i
                                ? (page_fault_v
                                    ? eIdle
                                    : (pte_is_leaf ? eWriteBack : eSendLoad))
                                    : eWaitLoad);                                                             
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
  
  bsg_dff_reset_en #(.width_p(vtag_width_p))
    vpn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i(vpn_n)
     ,.data_o(vpn_r)
    );
  
  bsg_dff_reset_en #(.width_p(ptag_width_p))
    ppn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ppn_en)
     ,.data_i(ppn_n)
     ,.data_o(ppn_r)
    );
    
  bsg_dff_reset_en #(.width_p(1))
    tlb_sel_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i(itlb_not_dtlb_i)
     ,.data_o(itlb_not_dtlb_o)
    );
    
  bsg_dff_reset_en #(.width_p(1))
    cmd_sel_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i(store_not_load_i)
     ,.data_o(store_not_load_r)
    );
 
endmodule


module bp_be_mock_ptw
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter pte_width_p              = bp_sv39_pte_width_gp
    ,parameter vaddr_width_p           = bp_sv39_vaddr_width_gp
    ,parameter paddr_width_p           = bp_sv39_paddr_width_gp
    ,parameter page_offset_width_p     = bp_page_offset_width_gp
    ,parameter page_table_depth_p      = bp_sv39_page_table_depth_gp
    
    ,localparam vpn_width_lp           = vaddr_width_p - page_offset_width_p
    ,localparam ppn_width_lp           = paddr_width_p - page_offset_width_p
    ,localparam dcache_pkt_width_lp    = `bp_be_dcache_pkt_width(page_offset_width_p, pte_width_p)    
    ,localparam tlb_entry_width_lp     = `bp_be_tlb_entry_width(ppn_width_lp)
	,localparam lg_page_table_depth_lp = `BSG_SAFE_CLOG2(page_table_depth_p)
	
	,localparam page_entry_offset_width_lp = page_offset_width_p - `BSG_SAFE_CLOG2(pte_width_p/8)
  )
  (input                                    clk_i
   , input                                  reset_i
   , input [ppn_width_lp-1:0]               base_ppn_i
   
   // TLB connections
   , input                                  tlb_miss_v_i
   , input [vpn_width_lp-1:0]               tlb_miss_vtag_i
   , output logic                           tlb_rdy_o
   
   , output logic                           tlb_w_v_o
   , output logic [vpn_width_lp-1:0]        tlb_w_vtag_o
   , output logic [tlb_entry_width_lp-1:0]  tlb_w_entry_o

   // D-Cache connections
   , input                                  dcache_v_i
   , input [pte_width_p-1:0]                dcache_data_i
   
   , output logic                           dcache_v_o
   , output logic [dcache_pkt_width_lp-1:0] dcache_pkt_o
   , output logic [ppn_width_lp-1:0]        dcache_ptag_o
   , input                                  dcache_rdy_i
   , input                                  dcache_miss_i
  );
  
  `declare_bp_be_dcache_pkt_s(page_offset_width_p, pte_width_p);
  `declare_bp_sv39_pte_s(pte_width_p, ppn_width_lp, pte_offset_width_lp);
  
  typedef enum [2:0] { eIdle, eSendLoad, eSendPtag, eWaitLoad, eWriteBack, eStuck } state_e;
  
  bp_be_dcache_pkt_s dcache_pkt;
  bp_sv39_pte_s      dcache_data;
  bp_be_tlb_entry_s  tlb_w_entry;
  
  state_e state_r, state_n;

  logic pte_leaf_v;
  logic start;
  logic [lg_page_table_depth_lp-1:0] page_level_cntr;
  logic                              page_level_cntr_en;
  logic [vpn_width_lp-1:0]           vpn_r;
  logic [ppn_width_lp-1:0]           ppn_r, ppn_n;
  logic                              ppn_en;
  
  assign dcache_pkt_o           = dcache_pkt;
  assign dcache_ptag_o          = ppn_r;
  assign dcache_data            = dcache_data_i;
  assign tlb_w_entry_o          = tlb_w_entry;
  
  assign dcache_pkt.opcode      = e_dcache_opcode_ld;
  assign dcache_pkt.page_offset = {vpn_r[page_level_cntr*page_entry_offset_width_lp +: page_entry_offset_width_lp], 3'b0};
  
  assign tlb_w_entry.ptag       = (page_level_cntr == '0)? ppn_r :
                                  {ppn_r[ppn_width_lp-1 : page_level_cntr*page_entry_offset_width_lp], 
								   vpn_r[0 +: page_level_cntr*page_entry_offset_width_lp]};

  assign start                  = (state_r == eIdle) & tlb_miss_v_i;
  
  assign pte_leaf_v             = dcache_data.x | dcache_data.w | dcache_data.r;
  
  assign page_level_cntr_en     = dcache_v_i & ~pte_leaf_v;
  
  assign ppn_en                 = start | dcache_v_i;
  assign ppn_n                  = (state_r == eIdle)? base_ppn_i : dcache_data.ppn;
  
  
  always_comb begin
    case(state_r)
	  eIdle:      state_n = (tlb_miss_v_i)? eSendLoad : eIdle;
	  eSendLoad:  state_n = (dcache_rdy_i)? eSendPtag : eSendLoad;
	  eSendPtag:  state_n = eWaitLoad;
	  eWaitLoad:  state_n = (dcache_miss_i)? eSendLoad :
	                        (dcache_v_i)? ((pte_leaf_v)? eWaitLoad : eSendLoad) :
						    eWaitLoad;
	  eWriteBack: state_n = eIdle;
      default: state_n = eStuck;
    endcase
  end

  
  always_ff @(posedge clk_i) begin
    if(reset_i) begin
	  page_level_cntr <= '0;
	end
	else if(start) begin
	  page_level_cntr <= page_table_depth_p - 1;
	end
	else if(page_level_cntr_en) begin
	  page_level_cntr <= page_level_cntr - 'b1;
	end
  end
  
  bsg_dff_reset_en #(.width_p(vpn_width_lp))
    vpn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(start)
     ,.data_i(tlb_miss_vtag_i)
     ,.data_o(vpn_r)
    );
  
  bsg_dff_reset_en #(.width_p(ppn_width_lp))
    ppn_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ppn_en)
     ,.data_i(ppn_n)
     ,.data_o(ppn_r)
    );
 
endmodule
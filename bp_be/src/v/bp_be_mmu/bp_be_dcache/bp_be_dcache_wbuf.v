/**
 *  Name:
 *    bp_be_dcache_wbuf.v
 *
 *  Description:
 *    Data cache write buffer.
 */

module bp_be_dcache_wbuf
  import bp_common_pkg::*;
  #(parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter ways_p="inv"
    , parameter sets_p="inv"

    , localparam block_size_in_words_lp=ways_p
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)

    , localparam wbuf_entry_width_lp=
      `bp_be_dcache_wbuf_entry_width(paddr_width_p,data_width_p,ways_p)
  )
  (
    input clk_i
    , input reset_i
    
    , input v_i
    , input [wbuf_entry_width_lp-1:0] wbuf_entry_i

    , input yumi_i
    , output logic v_o
    , output logic [wbuf_entry_width_lp-1:0] wbuf_entry_o

    , output logic empty_o
    
    , input [paddr_width_p-1:0] bypass_addr_i
    , input bypass_v_i
    , output logic [data_width_p-1:0] bypass_data_o
    , output logic [data_mask_width_lp-1:0] bypass_mask_o

    , input [index_width_lp-1:0] lce_snoop_index_i
    , input [way_id_width_lp-1:0] lce_snoop_way_i
    , output logic lce_snoop_match_o
  );

  `declare_bp_be_dcache_wbuf_entry_s(paddr_width_p, data_width_p, ways_p);

  bp_be_dcache_wbuf_entry_s wbuf_entry_in;
  assign wbuf_entry_in = wbuf_entry_i;
  
  bp_be_dcache_wbuf_entry_s wbuf_entry_el0;
  bp_be_dcache_wbuf_entry_s wbuf_entry_el1;

  logic [1:0] num_els_r;

  logic el0_valid;
  logic el1_valid;
  logic mux1_sel;
  logic mux0_sel;
  logic el0_enable;
  logic el1_enable;

  always_comb begin
    case (num_els_r) 
      2'd0: begin
        v_o = v_i;
        empty_o = 1'b1;
        el0_valid = 1'b0;
        el1_valid = 1'b0;
        el0_enable = 1'b0;
        el1_enable = v_i & ~yumi_i;
        mux0_sel = 1'b0;
        mux1_sel = 1'b0;
      end
      
      2'd1: begin
        v_o = 1'b1;
        empty_o = 1'b0;
        el0_valid = 1'b0;
        el1_valid = 1'b1;
        el0_enable = v_i & ~yumi_i;
        el1_enable = v_i & yumi_i;
        mux0_sel = 1'b0;
        mux1_sel = 1'b1;
      end

      2'd2: begin
        v_o = 1'b1;
        empty_o = 1'b0;
        el0_valid = 1'b1;
        el1_valid = 1'b1;
        el0_enable = v_i & yumi_i;
        el1_enable = yumi_i;
        mux0_sel = 1'b1;
        mux1_sel = 1'b1;
      end
      default: begin
        v_o = 1'b0;
        empty_o = 1'b0;
        el0_valid = 1'b0;
        el1_valid = 1'b0;
        el0_enable = 1'b0;
        el1_enable = 1'b0;
        mux0_sel = 1'b0;
        mux1_sel = 1'b0;
      end
    endcase
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      num_els_r <= 2'b0;
    end
    else begin
      num_els_r <= num_els_r + 2'(v_i - (v_o & yumi_i));
    end
  end

  // wbuf queue
  //
  bp_be_dcache_wbuf_queue
    #(.width_p(wbuf_entry_width_lp))
    wbq
      (.clk_i(clk_i)
      ,.data_i(wbuf_entry_in)
      ,.el0_en_i(el0_enable)
      ,.el1_en_i(el1_enable)
      ,.mux0_sel_i(mux0_sel)
      ,.mux1_sel_i(mux1_sel)
      ,.el0_snoop_o(wbuf_entry_el0)
      ,.el1_snoop_o(wbuf_entry_el1)
      ,.data_o(wbuf_entry_o)
      );

  // bypassing
  //
  logic tag_hit0, tag_hit0_n;
  logic tag_hit1, tag_hit1_n;
  logic tag_hit2, tag_hit2_n;
  logic [paddr_width_p-byte_offset_width_lp-1:0] bypass_word_addr;

  assign bypass_word_addr = bypass_addr_i[paddr_width_p-1:byte_offset_width_lp];
  assign tag_hit0_n = bypass_word_addr == wbuf_entry_el0.paddr[paddr_width_p-1:byte_offset_width_lp]; 
  assign tag_hit1_n = bypass_word_addr == wbuf_entry_el1.paddr[paddr_width_p-1:byte_offset_width_lp]; 
  assign tag_hit2_n = bypass_word_addr == wbuf_entry_in.paddr[paddr_width_p-1:byte_offset_width_lp]; 

  assign tag_hit0 = tag_hit0_n & el0_valid;
  assign tag_hit1 = tag_hit1_n & el1_valid;
  assign tag_hit2 = tag_hit2_n & v_i;

  logic [data_mask_width_lp-1:0] tag_hit0x4;
  logic [data_mask_width_lp-1:0] tag_hit1x4;
  logic [data_mask_width_lp-1:0] tag_hit2x4;
  
  assign tag_hit0x4 = {data_mask_width_lp{tag_hit0}};
  assign tag_hit1x4 = {data_mask_width_lp{tag_hit1}};
  assign tag_hit2x4 = {data_mask_width_lp{tag_hit2}};
   
  logic [data_width_p-1:0] el0or1_data;
  logic [data_width_p-1:0] bypass_data_n;
  logic [data_mask_width_lp-1:0] bypass_mask_n;

  assign bypass_mask_n = (tag_hit0x4 & wbuf_entry_el0.mask)
    | (tag_hit1x4 & wbuf_entry_el1.mask)
    | (tag_hit2x4 & wbuf_entry_in.mask);

  bsg_mux_segmented #(
    .segments_p(data_mask_width_lp)
    ,.segment_width_p(8) 
  ) mux_segmented_merge0 (
    .data0_i(wbuf_entry_el1.data)
    ,.data1_i(wbuf_entry_el0.data)
    ,.sel_i(tag_hit0x4 & wbuf_entry_el0.mask)
    ,.data_o(el0or1_data)
  );

  bsg_mux_segmented #(
    .segments_p(data_mask_width_lp)
    ,.segment_width_p(8) 
  ) mux_segmented_merge1 (
    .data0_i(el0or1_data)
    ,.data1_i(wbuf_entry_in.data)
    ,.sel_i(tag_hit2x4 & wbuf_entry_in.mask)
    ,.data_o(bypass_data_n)
  );

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      bypass_mask_o <= '0;
      bypass_data_o <= '0;
    end
    else begin
      if (bypass_v_i) begin
        bypass_mask_o <= bypass_mask_n;
        bypass_data_o <= bypass_data_n; 
      end
    end
  end

  // LCE snoop
  //
  logic lce_snoop_el2_match;
  logic lce_snoop_el0_match;
  logic lce_snoop_el1_match;

  assign lce_snoop_el2_match = v_i
    & (lce_snoop_index_i == wbuf_entry_in.paddr[block_offset_width_lp+:index_width_lp])
    & (lce_snoop_way_i == wbuf_entry_in.way_id);

  assign lce_snoop_el0_match = el0_valid
    & (lce_snoop_index_i == wbuf_entry_el0.paddr[block_offset_width_lp+:index_width_lp])
    & (lce_snoop_way_i == wbuf_entry_el0.way_id);

  assign lce_snoop_el1_match = el1_valid
    & (lce_snoop_index_i == wbuf_entry_el1.paddr[block_offset_width_lp+:index_width_lp])
    & (lce_snoop_way_i == wbuf_entry_el1.way_id);

  assign lce_snoop_match_o = lce_snoop_el2_match | lce_snoop_el0_match | lce_snoop_el1_match;

endmodule

/**
 *  bp_dcache_wbuf.v
 *
 *  @author tommy
 */


module bp_dcache_wbuf
  #(parameter data_width_p="inv"
    ,parameter addr_width_p="inv"
    ,parameter ways_p="inv"
    ,parameter sets_p="inv"
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
  )
  (
    input clk_i
    ,input reset_i
    
    ,input v_i
    ,input [addr_width_p-1:0] addr_i
    ,input [data_width_p-1:0] data_i
    ,input [data_mask_width_lp-1:0] mask_i
    ,input [lg_ways_lp-1:0] way_i

    ,output logic v_o
    ,output logic [data_width_p-1:0] data_o
    ,output logic [addr_width_p-1:0] addr_o
    ,output logic [data_mask_width_lp-1:0] mask_o
    ,output logic [lg_ways_lp-1:0] way_o
    ,input yumi_i

    ,output logic empty_o
    
    ,input [addr_width_p-1:0] bypass_addr_i
    ,input bypass_v_i
    ,output logic [data_width_p-1:0] bypass_data_o
    ,output logic [data_mask_width_lp-1:0] bypass_mask_o

    ,input [lg_sets_lp-1:0] lce_snoop_index_i
    ,input [lg_ways_lp-1:0] lce_snoop_way_i
    ,output logic lce_snoop_match_o
  );

  logic [addr_width_p-1:0] el0_addr;
  logic [addr_width_p-1:0] el1_addr;
  logic [data_width_p-1:0] el0_data;
  logic [data_width_p-1:0] el1_data;
  logic [data_mask_width_lp-1:0] el0_mask;
  logic [data_mask_width_lp-1:0] el1_mask;
  logic [lg_ways_lp-1:0] el0_way;
  logic [lg_ways_lp-1:0] el1_way;

  logic [1:0] num_els_r;

  logic el0_valid;
  logic el1_valid;
  logic mux1_sel;
  logic mux0_sel;
  logic el0_enable;
  logic el1_enable;

  always_comb begin
    case (num_els_r) 
      0: begin
        v_o = v_i;
        empty_o = 1;
        el0_valid = 0;
        el1_valid = 0;
        el0_enable = 0;
        el1_enable = v_i & ~yumi_i;
        mux0_sel = 0;
        mux1_sel = 0;
      end
      
      1: begin
        v_o = 1;
        empty_o = 0;
        el0_valid = 0;
        el1_valid = 1;
        el0_enable = v_i & ~yumi_i;
        el1_enable = v_i & yumi_i;
        mux0_sel = 0;
        mux1_sel = 1;
      end

      2: begin
        v_o = 1;
        empty_o = 0;
        el0_valid = 1;
        el1_valid = 1;
        el0_enable = v_i & yumi_i;
        el1_enable = yumi_i;
        mux0_sel = 1;
        mux1_sel = 1;
      end
      default: begin
        v_o = 0;
        empty_o = 0;
        el0_valid = 0;
        el1_valid = 0;
        el0_enable = 0;
        el1_enable = 0;
        mux0_sel = 0;
        mux1_sel = 0;
      end
    endcase
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      num_els_r <= 2'b0;
    end
    else begin
      num_els_r <= num_els_r + v_i - (v_o & yumi_i);
    end
  end

  // wbuf queues
  //
  bp_dcache_wbuf_queue #(.width_p(data_mask_width_lp)) wbq_mask (
    .clk_i(clk_i)
    ,.data_i(mask_i)
    ,.el0_en_i(el0_enable)
    ,.el1_en_i(el1_enable)
    ,.mux0_sel_i(mux0_sel)
    ,.mux1_sel_i(mux1_sel)
    ,.el0_snoop_o(el0_mask)
    ,.el1_snoop_o(el1_mask)
    ,.data_o(mask_o)
  );

  bp_dcache_wbuf_queue #(.width_p(data_width_p)) wbq_data (
    .clk_i(clk_i)
    ,.data_i(data_i)
    ,.el0_en_i(el0_enable)
    ,.el1_en_i(el1_enable)
    ,.mux0_sel_i(mux0_sel)
    ,.mux1_sel_i(mux1_sel)
    ,.el0_snoop_o(el0_data)
    ,.el1_snoop_o(el1_data)
    ,.data_o(data_o)
  );

  bp_dcache_wbuf_queue #(.width_p(addr_width_p)) wbq_addr (
    .clk_i(clk_i)
    ,.data_i(addr_i)
    ,.el0_en_i(el0_enable)
    ,.el1_en_i(el1_enable)
    ,.mux0_sel_i(mux0_sel)
    ,.mux1_sel_i(mux1_sel)
    ,.el0_snoop_o(el0_addr)
    ,.el1_snoop_o(el1_addr)
    ,.data_o(addr_o)
  );

  bp_dcache_wbuf_queue #(.width_p(lg_ways_lp)) wbq_way (
    .clk_i(clk_i)
    ,.data_i(way_i)
    ,.el0_en_i(el0_enable)
    ,.el1_en_i(el1_enable)
    ,.mux0_sel_i(mux0_sel)
    ,.mux1_sel_i(mux1_sel)
    ,.el0_snoop_o(el0_way)
    ,.el1_snoop_o(el1_way)
    ,.data_o(way_o)
  );

  // bypassing
  //
  logic tag_hit0, tag_hit0_n;
  logic tag_hit1, tag_hit1_n;
  logic tag_hit2, tag_hit2_n;
  logic [addr_width_p-lg_data_mask_width_lp-1:0] bypass_word_addr;

  assign bypass_word_addr = bypass_addr_i[addr_width_p-1:lg_data_mask_width_lp];
  assign tag_hit0_n = bypass_word_addr == el0_addr[addr_width_p-1:lg_data_mask_width_lp]; 
  assign tag_hit1_n = bypass_word_addr == el1_addr[addr_width_p-1:lg_data_mask_width_lp]; 
  assign tag_hit2_n = bypass_word_addr == addr_i[addr_width_p-1:lg_data_mask_width_lp]; 

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

  assign bypass_mask_n = (tag_hit0x4 & el0_mask)
    | (tag_hit1x4 & el1_mask)
    | (tag_hit2x4 & mask_i);

  bsg_mux_segmented #(
    .segments_p(data_mask_width_lp)
    ,.segment_width_p(8) 
  ) mux_segmented_merge0 (
    .data0_i(el1_data)
    ,.data1_i(el0_data)
    ,.sel_i(tag_hit0x4 & el0_mask)
    ,.data_o(el0or1_data)
  );

  bsg_mux_segmented #(
    .segments_p(data_mask_width_lp)
    ,.segment_width_p(8) 
  ) mux_segmented_merge1 (
    .data0_i(el0or1_data)
    ,.data1_i(data_i)
    ,.sel_i(tag_hit2x4 & mask_i)
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

  assign lce_snoop_el2_match = v_i & (lce_snoop_index_i == addr_i[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp]) & (lce_snoop_way_i == way_i);
  assign lce_snoop_el0_match = el0_valid & (lce_snoop_index_i == el0_addr[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp]) & (lce_snoop_way_i == el0_way);
  assign lce_snoop_el1_match = el1_valid & (lce_snoop_index_i == el1_addr[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp]) & (lce_snoop_way_i == el1_way);
  assign lce_snoop_match_o = lce_snoop_el2_match | lce_snoop_el0_match | lce_snoop_el1_match;

endmodule

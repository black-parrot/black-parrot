/**
 *  Name:
 *    bp_be_dcache_wbuf.sv
 *
 *  Description:
 *    Data cache write buffer.
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_dcache_wbuf
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter sets_p         = dcache_sets_p
   , parameter assoc_p        = dcache_assoc_p
   , parameter block_width_p  = dcache_block_width_p
   , parameter fill_width_p   = dcache_fill_width_p
   , parameter tag_width_p    = dcache_tag_width_p
   , parameter id_width_p     = dcache_req_id_width_p

   `declare_bp_be_dcache_engine_if_widths(paddr_width_p, tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p)

   , localparam wbuf_entry_width_lp=`bp_be_dcache_wbuf_entry_width(caddr_width_p, dcache_assoc_p)
   )
  (input                                      clk_i
   , input                                    reset_i

   , input [wbuf_entry_width_lp-1:0]          wbuf_entry_i
   , input                                    v_i

   , output logic [wbuf_entry_width_lp-1:0]   wbuf_entry_o
   , output logic                             v_o
   , output logic                             force_o
   , input                                    yumi_i

   , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
   , input                                    data_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_i
   , input                                    tag_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
   , input                                    stat_mem_pkt_v_i
   , output logic                             snoop_match_o

   , input                                    v_tl_i
   , input [caddr_width_p-1:0]                addr_tl_i
   , input [dword_width_gp-1:0]               data_tv_i
   , output logic [dword_width_gp-1:0]        data_merged_o
   );

  `declare_bp_be_dcache_wbuf_entry_s(caddr_width_p, dcache_assoc_p);
  `declare_bp_be_dcache_engine_if(paddr_width_p, tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p);
  `bp_cast_i(bp_be_dcache_wbuf_entry_s, wbuf_entry);
  `bp_cast_i(bp_be_dcache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_i(bp_be_dcache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_i(bp_be_dcache_stat_mem_pkt_s, stat_mem_pkt);

  localparam data_mask_width_lp    = dword_width_gp >> 3;
  localparam byte_offset_width_lp  = `BSG_SAFE_CLOG2(data_mask_width_lp);
  localparam bindex_width_lp       = `BSG_SAFE_CLOG2(assoc_p);
  localparam sindex_width_lp       = `BSG_SAFE_CLOG2(sets_p);
  localparam block_offset_width_lp = (assoc_p > 1)
    ? (bindex_width_lp+byte_offset_width_lp)
    : byte_offset_width_lp;

  logic [1:0] num_els_r;
  bsg_counter_up_down
   #(.max_val_p(2), .init_val_p(0), .max_step_p(1))
   num_els_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.up_i(v_i)
     ,.down_i(yumi_i)
     ,.count_o(num_els_r)
     );

  logic el0_valid, el1_valid;
  logic el0_enable, el1_enable;
  logic mux0_sel, mux1_sel;
  always_comb begin
    unique case (num_els_r)
      2'd0: begin
        v_o = v_i;
        el0_valid = 1'b0;
        el1_valid = 1'b0;
        el0_enable = 1'b0;
        el1_enable = v_i & ~yumi_i;
        mux0_sel = 1'b0;
        mux1_sel = 1'b0;
      end
      2'd1: begin
        v_o = 1'b1;
        el0_valid = 1'b0;
        el1_valid = 1'b1;
        el0_enable = v_i & ~yumi_i;
        el1_enable = v_i & yumi_i;
        mux0_sel = 1'b0;
        mux1_sel = 1'b1;
      end
      //2'd2
      default : begin
        v_o = 1'b1;
        el0_valid = 1'b1;
        el1_valid = 1'b1;
        el0_enable = v_i & yumi_i;
        el1_enable = yumi_i;
        mux0_sel = 1'b1;
        mux1_sel = 1'b1;
      end
    endcase
  end

  assign force_o = v_i & (num_els_r == 2'd2);

  // wbuf queue
  //
  bp_be_dcache_wbuf_entry_s wbuf_entry_el0_n, wbuf_entry_el0_r;
  bp_be_dcache_wbuf_entry_s wbuf_entry_el1_n, wbuf_entry_el1_r;

  assign wbuf_entry_el0_n = wbuf_entry_cast_i;
  bsg_dff_en
   #(.width_p($bits(bp_be_dcache_wbuf_entry_s)))
   wbuf_entry0_reg
    (.clk_i(clk_i)
     ,.en_i(el0_enable)
     ,.data_i(wbuf_entry_el0_n)
     ,.data_o(wbuf_entry_el0_r)
     );

  assign wbuf_entry_el1_n = mux0_sel ? wbuf_entry_el0_r : wbuf_entry_cast_i;
  bsg_dff_en
   #(.width_p($bits(bp_be_dcache_wbuf_entry_s)))
   wbuf_entry1_reg
    (.clk_i(clk_i)
     ,.en_i(el1_enable)
     ,.data_i(wbuf_entry_el1_n)
     ,.data_o(wbuf_entry_el1_r)
     );
  assign wbuf_entry_o = mux1_sel ? wbuf_entry_el1_r : wbuf_entry_cast_i;

  // bypassing
  //
  localparam word_addr_width_lp = caddr_width_p-byte_offset_width_lp;
  wire [word_addr_width_lp-1:0] bypass_word_addr = addr_tl_i[byte_offset_width_lp+:word_addr_width_lp];
  wire tag_hit0_n = bypass_word_addr == wbuf_entry_el0_r.caddr[byte_offset_width_lp+:word_addr_width_lp];
  wire tag_hit1_n = bypass_word_addr == wbuf_entry_el1_r.caddr[byte_offset_width_lp+:word_addr_width_lp];
  wire tag_hit2_n = bypass_word_addr == wbuf_entry_cast_i.caddr[byte_offset_width_lp+:word_addr_width_lp];

  wire tag_hit0 = v_tl_i & tag_hit0_n & el0_valid;
  wire tag_hit1 = v_tl_i & tag_hit1_n & el1_valid;
  wire tag_hit2 = v_tl_i & tag_hit2_n & v_i;

  wire [data_mask_width_lp-1:0] tag_hit0x4 = {data_mask_width_lp{tag_hit0}};
  wire [data_mask_width_lp-1:0] tag_hit1x4 = {data_mask_width_lp{tag_hit1}};
  wire [data_mask_width_lp-1:0] tag_hit2x4 = {data_mask_width_lp{tag_hit2}};

  logic [dword_width_gp-1:0] el0or1_data;
  bsg_mux_segmented
   #(.segments_p(data_mask_width_lp), .segment_width_p(byte_width_gp))
   mux_segmented_merge0
    (.data0_i(wbuf_entry_el1_r.data)
     ,.data1_i(wbuf_entry_el0_r.data)
     ,.sel_i(tag_hit0x4 & wbuf_entry_el0_r.mask)
     ,.data_o(el0or1_data)
     );

  logic [dword_width_gp-1:0] bypass_data_n;
  bsg_mux_segmented
   #(.segments_p(data_mask_width_lp), .segment_width_p(byte_width_gp))
   mux_segmented_merge1
    (.data0_i(el0or1_data)
     ,.data1_i(wbuf_entry_cast_i.data)
     ,.sel_i(tag_hit2x4 & wbuf_entry_cast_i.mask)
     ,.data_o(bypass_data_n)
     );

  wire [data_mask_width_lp-1:0] bypass_mask_n = (tag_hit0x4 & wbuf_entry_el0_r.mask)
                                                | (tag_hit1x4 & wbuf_entry_el1_r.mask)
                                                | (tag_hit2x4 & wbuf_entry_cast_i.mask);

  logic [dword_width_gp-1:0] bypass_data_r;
  logic [data_mask_width_lp-1:0] bypass_mask_r;
  bsg_dff_reset
   #(.width_p(dword_width_gp+data_mask_width_lp))
   bypass_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({bypass_mask_n, bypass_data_n})
     ,.data_o({bypass_mask_r, bypass_data_r})
     );

  logic [dword_width_gp-1:0] bypass_data_masked;
  bsg_mux_segmented
   #(.segments_p(data_mask_width_lp), .segment_width_p(byte_width_gp))
   bypass_mux_segmented
    (.data0_i(data_tv_i)
     ,.data1_i(bypass_data_r)
     ,.sel_i(bypass_mask_r)
     ,.data_o(data_merged_o)
     );

  // This is slightly pessimistic because it blocks all ways. However, putting the SRAM read
  //   and tag match on the slow path seems like a bad idea.
  wire snoop_tag_match = v_tl_i & tag_mem_pkt_v_i
    & (addr_tl_i[block_offset_width_lp+:sindex_width_lp] == tag_mem_pkt_cast_i.index);
  wire snoop_stat_match = v_tl_i & stat_mem_pkt_v_i
    & (addr_tl_i[block_offset_width_lp+:sindex_width_lp] == stat_mem_pkt_cast_i.index);
  wire snoop_el0_match = el0_valid & ~wbuf_entry_cast_i.snoop & data_mem_pkt_v_i
    & (wbuf_entry_el0_r.caddr[block_offset_width_lp+:sindex_width_lp] == data_mem_pkt_cast_i.index);
  wire snoop_el1_match = el1_valid & ~wbuf_entry_el1_r.snoop & data_mem_pkt_v_i
    & (wbuf_entry_el1_r.caddr[block_offset_width_lp+:sindex_width_lp] == data_mem_pkt_cast_i.index);
  wire snoop_el2_match = v_i & ~wbuf_entry_cast_i.snoop & data_mem_pkt_v_i
    & (wbuf_entry_cast_i.caddr[block_offset_width_lp+:sindex_width_lp] == data_mem_pkt_cast_i.index);

  assign snoop_match_o = snoop_tag_match | snoop_stat_match | snoop_el0_match | snoop_el1_match | snoop_el2_match;

  // synopsys translate_off
  always_ff @(negedge clk_i) begin
    assert(reset_i !== '0 || num_els_r < 2'd3) else $error("Write buffer overflow\n");
  end
  // synopsys translate_on

endmodule


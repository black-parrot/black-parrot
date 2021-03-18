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

   , localparam data_mask_width_lp   = (dword_width_gp>>3)
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(dword_width_gp>>3)

   , localparam wbuf_entry_width_lp=`bp_be_dcache_wbuf_entry_width(paddr_width_p,dcache_assoc_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input [wbuf_entry_width_lp-1:0]        wbuf_entry_i
   , input                                  v_i

   , output logic [wbuf_entry_width_lp-1:0] wbuf_entry_o
   , output logic                           v_o
   , input                                  yumi_i

   , input [paddr_width_p-1:0]              load_addr_i
   , input [dword_width_gp-1:0]             load_data_i
   , output logic [dword_width_gp-1:0]      data_merged_o
   );

  `declare_bp_be_dcache_wbuf_entry_s(paddr_width_p, dcache_assoc_p);
  bp_be_dcache_wbuf_entry_s wbuf_entry_in;
  assign wbuf_entry_in = wbuf_entry_i;

  logic [1:0] num_els_r;
  bsg_counter_up_down
   #(.max_val_p(3), .init_val_p(0), .max_step_p(1))
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
        v_o = 1'b0;
        el0_valid = 1'b0;
        el1_valid = 1'b0;
        el0_enable = 1'b0;
        el1_enable = v_i;
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

  // wbuf queue
  //
  bp_be_dcache_wbuf_entry_s wbuf_entry_el0_n, wbuf_entry_el0_r;
  bp_be_dcache_wbuf_entry_s wbuf_entry_el1_n, wbuf_entry_el1_r;

  assign wbuf_entry_el0_n = wbuf_entry_in;
  bsg_dff_en
   #(.width_p($bits(bp_be_dcache_wbuf_entry_s)))
   wbuf_entry0_reg
    (.clk_i(clk_i)
     ,.en_i(el0_enable)
     ,.data_i(wbuf_entry_el0_n)
     ,.data_o(wbuf_entry_el0_r)
     );

  assign wbuf_entry_el1_n = mux0_sel ? wbuf_entry_el0_r : wbuf_entry_in;
  bsg_dff_en
   #(.width_p($bits(bp_be_dcache_wbuf_entry_s)))
   wbuf_entry1_reg
    (.clk_i(clk_i)
     ,.en_i(el1_enable)
     ,.data_i(wbuf_entry_el1_n)
     ,.data_o(wbuf_entry_el1_r)
     );
  assign wbuf_entry_o = mux1_sel ? wbuf_entry_el1_r : wbuf_entry_in;

  // bypassing
  //
  localparam word_addr_width_lp = paddr_width_p-byte_offset_width_lp;
  wire [word_addr_width_lp-1:0] bypass_word_addr = load_addr_i[byte_offset_width_lp+:word_addr_width_lp];
  wire tag_hit0_n = bypass_word_addr == wbuf_entry_el0_r.paddr[byte_offset_width_lp+:word_addr_width_lp];
  wire tag_hit1_n = bypass_word_addr == wbuf_entry_el1_r.paddr[byte_offset_width_lp+:word_addr_width_lp];
  wire tag_hit2_n = bypass_word_addr == wbuf_entry_in.paddr[byte_offset_width_lp+:word_addr_width_lp];

  wire tag_hit0 = tag_hit0_n & el0_valid;
  wire tag_hit1 = tag_hit1_n & el1_valid;
  wire tag_hit2 = tag_hit2_n & v_i;

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
     ,.data1_i(wbuf_entry_in.data)
     ,.sel_i(tag_hit2x4 & wbuf_entry_in.mask)
     ,.data_o(bypass_data_n)
     );

  wire [data_mask_width_lp-1:0] bypass_mask_n = (tag_hit0x4 & wbuf_entry_el0_r.mask)
                                                | (tag_hit1x4 & wbuf_entry_el1_r.mask)
                                                | (tag_hit2x4 & wbuf_entry_in.mask);

  logic [dword_width_gp-1:0] bypass_data_r;
  logic [data_mask_width_lp-1:0] bypass_mask_r;
  bsg_dff_reset
   #(.width_p(dword_width_gp+data_mask_width_lp))
   bypass_reg
    (.clk_i(~clk_i)
     ,.reset_i(reset_i)
     ,.data_i({bypass_mask_n, bypass_data_n})
     ,.data_o({bypass_mask_r, bypass_data_r})
     );

  logic [dword_width_gp-1:0] bypass_data_masked;
  bsg_mux_segmented
   #(.segments_p(data_mask_width_lp), .segment_width_p(byte_width_gp))
   bypass_mux_segmented
    (.data0_i(load_data_i)
     ,.data1_i(bypass_data_r)
     ,.sel_i(bypass_mask_r)
     ,.data_o(data_merged_o)
     );

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    assert (~reset_i || num_els_r < 2'd3) else $error("Write buffer overflow\n");
  end
  //synopsys translate_on

endmodule


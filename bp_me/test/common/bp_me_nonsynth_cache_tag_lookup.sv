/**
 * bp_me_nonsynth_cache_tag_lookup.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cache_tag_lookup
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter `BSG_INV_PARAM(assoc_p)
    , parameter `BSG_INV_PARAM(tag_width_p)
    , localparam cache_tag_info_width_lp=`bp_cache_tag_info_width(tag_width_p)
    , localparam lg_assoc_lp=`BSG_SAFE_CLOG2(assoc_p)
   )
  (input [assoc_p-1:0][cache_tag_info_width_lp-1:0]  tag_set_i
   , input [tag_width_p-1:0]                         tag_i
   // write not read operation
   , input                                           w_i
   , output logic                                    hit_o
   , output logic                                    dirty_o
   , output logic [lg_assoc_lp-1:0]                  way_o
   , output bp_coh_states_e                          state_o
   , output logic [assoc_p-1:0]                      invalid_ways_o
  );

  `declare_bp_cache_tag_info_s(tag_width_p, cache);
  bp_cache_tag_info_s [assoc_p-1:0] tags;
  assign tags = tag_set_i;

  logic [assoc_p-1:0] rd_hits, wr_hits, hits;
  genvar i;
  generate
  for (i = 0; i < assoc_p; i=i+1) begin
    assign rd_hits[i] = (tags[i].state != e_COH_I) & ~w_i;
    assign wr_hits[i] = (tags[i].state inside {e_COH_E, e_COH_M}) & w_i;
    assign hits[i] = ((tags[i].tag == tag_i) & (rd_hits[i] | wr_hits[i]));
    assign invalid_ways_o[i] = (tags[i].state == e_COH_I);
  end
  endgenerate

  logic way_v_lo;
  logic [lg_assoc_lp-1:0] way_lo;
  bsg_encode_one_hot
    #(.width_p(assoc_p))
  hits_to_way_id
    (.i(hits)
     ,.addr_o(way_lo)
     ,.v_o(way_v_lo)
    );

  // suppress unused warning
  wire unused0 = way_v_lo;

  // hit_o is set if tag matched and read or write hit
  assign hit_o = |hits;
  assign way_o = way_lo;
  // MOESIF states: M and O are dirty
  assign dirty_o = (tags[way_o].state inside {e_COH_M, e_COH_O});
  assign state_o = bp_coh_states_e'(tags[way_o].state);

endmodule


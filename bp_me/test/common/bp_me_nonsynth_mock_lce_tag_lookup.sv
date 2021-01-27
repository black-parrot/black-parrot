/**
 * bp_me_nonsynth_mock_lce_tag_lookup.v
 *
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_mock_lce_tag_lookup
  import bp_common_pkg::*;
  #(parameter assoc_p="inv"
    , parameter ptag_width_p="inv"
    , localparam dir_entry_width_lp=`bp_cce_dir_entry_width(ptag_width_p)
    , localparam lg_assoc_lp=`BSG_SAFE_CLOG2(assoc_p)
   )
  (input [assoc_p-1:0][dir_entry_width_lp-1:0] tag_set_i
   , input [ptag_width_p-1:0] ptag_i
   , output logic hit_o
   , output logic dirty_o
   , output logic [lg_assoc_lp-1:0] way_o
   , output bp_coh_states_e state_o
  );

  `declare_bp_cce_dir_entry_s(ptag_width_p);
  dir_entry_s [assoc_p-1:0] tags;
  assign tags = tag_set_i;

  logic [assoc_p-1:0] hits;
  genvar i;
  generate
  for (i = 0; i < assoc_p; i=i+1) begin
    assign hits[i] = ((tags[i].tag == ptag_i) && (tags[i].state != e_COH_I));
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

  // hit_o is set if tag matched and coherence state was any valid state
  assign hit_o = |hits;
  assign way_o = way_lo;
  assign dirty_o = (tags[way_o].state == e_COH_M);
  assign state_o = tags[way_o].state;

endmodule


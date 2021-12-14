/**
 *
 * Name:
 *   bp_cce_dir_tag_checker.sv
 *
 * Description:
 *   This module performs the parallel tag comparison on a row of tag sets from the directory.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_dir_tag_checker
  import bp_common_pkg::*;
  #(parameter `BSG_INV_PARAM(tag_sets_per_row_p)
    , parameter `BSG_INV_PARAM(row_width_p)
    , parameter `BSG_INV_PARAM(assoc_p)
    , parameter `BSG_INV_PARAM(tag_width_p)

    , localparam lg_assoc_lp = `BSG_SAFE_CLOG2(assoc_p)
  )
  (
   // input row from directory RAM
   input [row_width_p-1:0]                                        row_i
   , input [tag_sets_per_row_p-1:0]                               row_v_i
   , input [tag_width_p-1:0]                                      tag_i

   , output logic [tag_sets_per_row_p-1:0]                        sharers_hits_o
   , output logic [tag_sets_per_row_p-1:0][lg_assoc_lp-1:0]       sharers_ways_o
   , output bp_coh_states_e [tag_sets_per_row_p-1:0]              sharers_coh_states_o
  );

  `declare_bp_cce_dir_entry_s(tag_width_p);

  // Directory RAM row cast
  dir_entry_s [tag_sets_per_row_p-1:0][assoc_p-1:0] row;
  assign row = row_i;

  // one bit per way per tag set indicating if a target block is cached in valid state
  logic [tag_sets_per_row_p-1:0][assoc_p-1:0] row_hits;

  // compute hit per way per tag set
  for (genvar i = 0; i < tag_sets_per_row_p; i++) begin : row_hits_tag_set
    for (genvar j = 0; j < assoc_p; j++) begin : row_hits_way
      assign row_hits[i][j] = row_v_i[i] & (row[i][j].tag == tag_i) & |(row[i][j].state);
    end
  end

  // extract way and valid bit per tag set
  for (genvar i = 0; i < tag_sets_per_row_p; i++) begin : sharers_ways_gen
    bsg_encode_one_hot
      #(.width_p(assoc_p)
        )
      row_hits_to_way_ids_and_v
       (.i(row_hits[i])
        ,.addr_o(sharers_ways_o[i])
        ,.v_o(sharers_hits_o[i])
        );
  end

  // extract coherence state for tag sets that have block cached
  for (genvar i = 0; i < tag_sets_per_row_p; i++) begin : sharers_states_gen
    assign sharers_coh_states_o[i] = (sharers_hits_o[i])
                                   ? row[i][sharers_ways_o[i]].state
                                   : e_COH_I;
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_dir_tag_checker)


/**
 *
 * Name:
 *   bp_cce_dir_tag_checker.v
 *
 * Description:
 *   This module performs the parallel tag comparison on a row of tag sets from the directory.
 *
 */

module bp_cce_dir_tag_checker
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter tag_sets_per_row_p          = "inv"
    , parameter rows_per_wg_p             = "inv"
    , parameter row_width_p               = "inv"
    , parameter lce_assoc_p               = "inv"
    , parameter tag_width_p               = "inv"

    , localparam lg_lce_assoc_lp          = `BSG_SAFE_CLOG2(lce_assoc_p)
  )
  (
   // input row from directory RAM
   input [row_width_p-1:0]                                        row_i
   , input                                                        row_v_i
   , input [tag_width_p-1:0]                                      tag_i

   , output logic [tag_sets_per_row_p-1:0]                        sharers_hits_o
   , output logic [tag_sets_per_row_p-1:0][lg_lce_assoc_lp-1:0]   sharers_ways_o
   , output logic [tag_sets_per_row_p-1:0][`bp_coh_bits-1:0]      sharers_coh_states_o
  );

  typedef struct packed {
    logic [tag_width_p-1:0]      tag;
    logic [`bp_coh_bits-1:0]     state;
  } dir_entry_s;

  // Directory RAM row cast
  dir_entry_s [tag_sets_per_row_p-1:0][lce_assoc_p-1:0] row;
  assign row = row_i;

  // one bit per way per tag set indicating if a target block is cached in valid state
  logic [tag_sets_per_row_p-1:0][lce_assoc_p-1:0]                row_hits;

  // compute hit per way per tag set
  for (genvar i = 0; i < tag_sets_per_row_p; i++) begin : row_hits_tag_set
    for (genvar j = 0; j < lce_assoc_p; j++) begin : row_hits_way
      assign row_hits[i][j] =
        (row_v_i)
        ? (row[i][j].tag == tag_i) & |(row[i][j].state)
        : '0;
    end
  end

  // extract way and valid bit per tag set
  for (genvar i = 0; i < tag_sets_per_row_p; i++) begin : sharers_ways_gen
    bsg_encode_one_hot
      #(.width_p(lce_assoc_p)
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
                                   : '0;
  end

endmodule


/**
 *
 * Name:
 *   bp_cce_dir_lru_extract.v
 *
 * Description:
 *   This module extracts information about the LRU entry of the requesting LCE
 *
 */

module bp_cce_dir_lru_extract
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter tag_sets_per_row_p          = "inv"
    , parameter row_width_p               = "inv"
    , parameter num_lce_p                 = "inv"
    , parameter lce_assoc_p               = "inv"
    , parameter rows_per_wg_p             = "inv"
    , parameter tag_width_p               = "inv"

    , localparam lg_num_lce_lp            = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp          = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_tag_sets_per_row_lp   = `BSG_SAFE_CLOG2(tag_sets_per_row_p)
    , localparam lg_rows_per_wg_lp        = `BSG_SAFE_CLOG2(rows_per_wg_p)

    , localparam lce_wg_offset_lp = (rows_per_wg_p == 1) ? 0 : lg_tag_sets_per_row_lp
    , localparam lce_wg_bits_lp = (rows_per_wg_p == 1) ? 1 : lg_rows_per_wg_lp
  )
  (
   // input row from directory RAM
   input [row_width_p-1:0]                                        row_i
   , input                                                        row_v_i
   // If there are multiple rows per wg, wg_part_i indicates which row is being input
   , input [lg_rows_per_wg_lp-1:0]                                wg_row_i

   // requesting LCE and LRU way for the request
   , input [lg_num_lce_lp-1:0]                                    lce_i
   , input [lg_lce_assoc_lp-1:0]                                  lru_way_i

   , output logic                                                 lru_v_o
   , output logic                                                 lru_cached_excl_o
   , output logic [tag_width_p-1:0]                               lru_tag_o

  );

  typedef struct packed {
    logic [tag_width_p-1:0]      tag;
    logic [`bp_coh_bits-1:0]     state;
  } dir_entry_s;

  // Directory RAM row cast
  dir_entry_s [tag_sets_per_row_p-1:0][lce_assoc_p-1:0] row;
  assign row = row_i;

  // LRU information is valid if the input row is valid and...
  // If only one row in directory per wg, then output is valid.
  // If more than one row per wg, then the current row from directory must be the row that
  // holds the tag set for the requesting lce (lce_i).
  assign lru_v_o = (row_v_i) 
                   ? (rows_per_wg_p == 1)
                     ? 1'b1
                     : (lce_i[lce_wg_offset_lp+:lce_wg_bits_lp] == wg_row_i)
                       ? 1'b1
                       : 1'b0
                   : 1'b0;

  logic [`bp_coh_bits-1:0] lru_coh_state;
  assign lru_coh_state = (row_v_i)
                         ? row[lce_i[0+:lg_tag_sets_per_row_lp]][lru_way_i].state
                         : '0;
  assign lru_cached_excl_o = |lru_coh_state & ~lru_coh_state[`bp_coh_shared_bit];
  assign lru_tag_o = (row_v_i)
                     ? row[lce_i[0+:lg_tag_sets_per_row_lp]][lru_way_i].tag
                     : '0;
endmodule


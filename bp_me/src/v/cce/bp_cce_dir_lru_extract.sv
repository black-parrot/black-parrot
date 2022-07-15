// Copyright (c) 2022, University of Washington
// Copyright and related rights are licensed under the BSD 3-Clause
// License (the “License”); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
// https://github.com/black-parrot/black-parrot/LICENSE.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed
// on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language
// governing permissions and limitations under the License.

/**
 *
 * Name:
 *   bp_cce_dir_lru_extract.sv
 *
 * Description:
 *   This module extracts information about the LRU entry of the requesting LCE
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_dir_lru_extract
  import bp_common_pkg::*;
  #(parameter `BSG_INV_PARAM(tag_sets_per_row_p)
    , parameter `BSG_INV_PARAM(row_width_p)
    , parameter `BSG_INV_PARAM(num_lce_p)
    , parameter `BSG_INV_PARAM(assoc_p)
    , parameter `BSG_INV_PARAM(rows_per_set_p)
    , parameter `BSG_INV_PARAM(tag_width_p)

    , localparam lg_num_lce_lp            = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_assoc_lp              = `BSG_SAFE_CLOG2(assoc_p)
    , localparam lg_rows_per_set_lp       = `BSG_SAFE_CLOG2(rows_per_set_p)
  )
  (
   // input row from directory RAM, per tag set valid bit, and row number
   input [row_width_p-1:0]                                        row_i
   , input [tag_sets_per_row_p-1:0]                               row_v_i
   , input [lg_rows_per_set_lp-1:0]                               row_num_i

   // requesting LCE and LRU way for the request
   , input [lg_num_lce_lp-1:0]                                    lce_i
   , input [lg_assoc_lp-1:0]                                      lru_way_i

   , output logic                                                 lru_v_o
   , output bp_coh_states_e                                       lru_coh_state_o
   , output logic [tag_width_p-1:0]                               lru_tag_o

  );

  `declare_bp_cce_dir_entry_s(tag_width_p);
  dir_entry_s [tag_sets_per_row_p-1:0][assoc_p-1:0] row;

  always_comb begin
    // cast directory row for easy access to state and tag
    row = row_i;

    // LRU output is valid if:
    // 1. tag set input is valid
    // 2. target LCE's tag set is stored on the input row
    lru_v_o = (row_v_i[lce_i[0]]) & ((lce_i >> 1) == row_num_i);
    lru_coh_state_o = row[lce_i[0]][lru_way_i].state;
    lru_tag_o = row[lce_i[0]][lru_way_i].tag;
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_dir_lru_extract)


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


`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_scoreboard
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(num_rs_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input                                      score_v_i
   , input [reg_addr_width_gp-1:0]               score_rd_i

   , input                                      clear_v_i
   , input [reg_addr_width_gp-1:0]               clear_rd_i

   , input [num_rs_p-1:0][reg_addr_width_gp-1:0] rs_i
   , input               [reg_addr_width_gp-1:0] rd_i

   , output logic [num_rs_p-1:0]                rs_match_o
   , output logic                               rd_match_o
   );

  localparam rf_els_lp = 2**reg_addr_width_gp;
  logic [rf_els_lp-1:0] scoreboard_r;

  logic [rf_els_lp-1:0] score_onehot_li;
  bsg_decode_with_v
   #(.num_out_p(rf_els_lp))
   score_decode
    (.i(score_rd_i)
     ,.v_i(score_v_i)
     ,.o(score_onehot_li)
     );

  logic [rf_els_lp-1:0] clear_onehot_li;
  bsg_decode_with_v
   #(.num_out_p(rf_els_lp))
   clear_decode
    (.i(clear_rd_i)
     ,.v_i(clear_v_i)
     ,.o(clear_onehot_li)
     );

  bsg_dff_reset_set_clear
   #(.width_p(rf_els_lp))
   scoreboard_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(score_onehot_li)
     ,.clear_i(clear_onehot_li)
     ,.data_o(scoreboard_r)
     );

  for (genvar i = 0; i < num_rs_p; i++)
    begin : rs
      assign rs_match_o[i] = scoreboard_r[rs_i[i]];
    end
  assign rd_match_o = scoreboard_r[rd_i];

endmodule

`BSG_ABSTRACT_MODULE(bp_be_scoreboard)


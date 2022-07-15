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

module bp_be_nan_unbox
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dpath_width_gp-1:0]          reg_i
   , input                             unbox_i
   , output logic [dpath_width_gp-1:0] reg_o
   );

 `bp_cast_i(bp_be_fp_reg_s, reg);
 `bp_cast_o(bp_be_fp_reg_s, reg);

  wire invbox = unbox_i & (reg_cast_i.tag == e_fp_full);
  assign reg_cast_o = invbox ? '{tag: unbox_i ? e_rne : e_fp_full, rec: dp_canonical_rec} : reg_i;

endmodule


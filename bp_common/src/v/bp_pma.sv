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

module bp_pma
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                          clk_i
   , input                        reset_i

   , input                        ptag_v_i
   , input [ptag_width_p-1:0]     ptag_i
   , input                        uncached_mode_i
   , input                        nonspec_mode_i

   , output logic                 uncached_o
   , output logic                 nonidem_o
   , output logic                 dram_o
   );

  wire is_local_addr = (ptag_i < (dram_base_addr_gp >> page_offset_width_gp));
  wire is_io_addr    = (ptag_i[ptag_width_p-1:dtag_width_p] != '0);
  wire is_uc_addr    = (ptag_i[ptag_width_p-1:ctag_width_p] != '0);

  assign uncached_o = ptag_v_i & (is_uc_addr | is_io_addr | is_local_addr | uncached_mode_i);
  // For now, uncached mode also means non-idempotency. Will reevaluate if we need
  //   a high-performance, unsafe, uncached mode
  assign nonidem_o  = ptag_v_i & (is_uc_addr | is_io_addr | is_local_addr | uncached_mode_i | nonspec_mode_i);
  assign dram_o     = ptag_v_i & (~is_local_addr & ~is_io_addr & ~is_uc_addr);

endmodule


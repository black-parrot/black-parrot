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
 *   bp_cce_pma.sv
 *
 * Description:
 *   This module defines the physical memory attributes (PMAs) obeyed by the CCE.
 *   The purpose is to define the cacheability properties of memory.
 *
 *   Only cached, global memory is kept explicitly coherent (i.e., DRAM memory). All other memory
 *   is uncached. See the BlackParrot Platform Guide (docs/platform_guide.md)
 *   and the bp_common_pkg files in bp_common/src/include/ for more details on BlackParrot's
 *   platform memory maps.
 *
 *   Uncacheable requests from an LCE are allowed to cacheable, global memory, and these requests
 *   will be kept coherent with all LCEs by invalidating (and writing back, if necessary) the block
 *   from all LCEs prior to performing the uncached operation.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_pma
  import bp_common_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
  )
  (input [paddr_width_p-1:0]                           paddr_i
   , input                                             paddr_v_i
   , output logic                                      cacheable_addr_o
  );

  always_comb begin

    cacheable_addr_o = paddr_v_i
                       ? (paddr_i >= dram_base_addr_gp) && (paddr_i < coproc_base_addr_gp)
                       : 1'b0;

  end

endmodule


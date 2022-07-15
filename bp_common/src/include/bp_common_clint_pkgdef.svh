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


`ifndef BP_COMMON_CLINT_PKGDEF_SVH
`define BP_COMMON_CLINT_PKGDEF_SVH


  localparam clint_base_addr_gp         = (dev_id_width_gp+dev_addr_width_gp)'('h30_0000);
  localparam clint_match_addr_gp        = (dev_id_width_gp+dev_addr_width_gp)'('h30_0???);

  localparam mipi_reg_base_addr_gp      = dev_addr_width_gp'('h0_0000);
  localparam mipi_reg_match_addr_gp     = dev_addr_width_gp'('h0_0???);

  localparam mtimecmp_reg_base_addr_gp  = dev_addr_width_gp'('h0_4000);
  localparam mtimecmp_reg_match_addr_gp = dev_addr_width_gp'('h0_4???);

  localparam mtimesel_reg_base_addr_gp  = dev_addr_width_gp'('h0_8000);
  localparam mtimesel_reg_match_addr_gp = dev_addr_width_gp'('h0_8???);

  localparam mtime_reg_addr_gp          = dev_addr_width_gp'('h0_bff8);
  localparam mtime_reg_match_addr_gp    = dev_addr_width_gp'('h0_bff?);

  localparam plic_reg_base_addr_gp      = dev_addr_width_gp'('h0_b000);
  localparam plic_reg_match_addr_gp     = dev_addr_width_gp'('h0_b00?);

  localparam debug_reg_base_addr_gp     = dev_addr_width_gp'('h0_c000);
  localparam debug_reg_match_addr_gp    = dev_addr_width_gp'('h0_c???);

`endif


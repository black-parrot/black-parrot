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


`ifndef BP_COMMON_HOST_PKGDEF_SVH
`define BP_COMMON_HOST_PKGDEF_SVH

  localparam host_base_addr_gp         = (dev_id_width_gp+dev_addr_width_gp)'('h0010_0000);
  localparam host_match_addr_gp        = (dev_id_width_gp+dev_addr_width_gp)'('h001?_????);

  localparam getchar_base_addr_gp      = (dev_addr_width_gp)'('h0_0000);
  localparam getchar_match_addr_gp     = (dev_addr_width_gp)'('h0_0???);

  localparam putchar_base_addr_gp      = (dev_addr_width_gp)'('h0_1000);
  localparam putchar_match_addr_gp     = (dev_addr_width_gp)'('h0_1???);

  localparam finish_base_addr_gp       = (dev_addr_width_gp)'('h0_2000);
  localparam finish_match_addr_gp      = (dev_addr_width_gp)'('h0_2???);

  localparam putch_core_base_addr_gp   = (dev_addr_width_gp)'('h0_3000);
  localparam putch_core_match_addr_gp  = (dev_addr_width_gp)'('h0_3???);

  localparam finish_all_addr_gp        = (dev_addr_width_gp)'('h0_4000);

  localparam bootrom_base_addr_gp      = (dev_addr_width_gp)'('h1_0000);
  localparam bootrom_match_addr_gp     = (dev_addr_width_gp)'('h1_????);

  localparam paramrom_base_addr_gp     = (dev_addr_width_gp)'('h2_0000);
  localparam paramrom_match_addr_gp    = (dev_addr_width_gp)'('h2_????);

`endif


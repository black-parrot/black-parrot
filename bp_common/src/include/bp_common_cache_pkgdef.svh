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


`ifndef BP_COMMON_CACHE_PKGDEF_SVH
`define BP_COMMON_CACHE_PKGDEF_SVH

  localparam cache_base_addr_gp   = (dev_id_width_gp+dev_addr_width_gp)'('h0400_0000);
  localparam cache_tagfl_addr_gp  = (dev_addr_width_gp)'('h0_0000);

`endif


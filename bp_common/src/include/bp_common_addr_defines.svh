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

`ifndef BP_COMMON_ADDR_DEFINES_SVH
`define BP_COMMON_ADDR_DEFINES_SVH

  `define declare_bp_memory_map(paddr_width_mp, daddr_width_mp) \
    typedef struct packed                                           \
    {                                                               \
      logic [paddr_width_mp-daddr_width_mp-1:0] hio;                \
      logic [daddr_width_mp-1:0]                daddr;              \
    }  bp_global_addr_s;                                            \
                                                                    \
    typedef struct packed                                           \
    {                                                               \
      logic [paddr_width_mp-tile_id_width_gp-dev_id_width_gp-dev_addr_width_gp-1:0] \
                                     nonlocal;         \
      logic [tile_id_width_gp-1:0]   tile;             \
      logic [dev_id_width_gp-1:0]    dev;              \
      logic [dev_addr_width_gp-1:0]  addr;             \
    }  bp_local_addr_s

`endif


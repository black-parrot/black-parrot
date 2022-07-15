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

`ifndef BP_COMMON_CFG_BUS_DEFINES_SVH
`define BP_COMMON_CFG_BUS_DEFINES_SVH

  `define declare_bp_cfg_bus_s(vaddr_width_mp, hio_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp) \
    typedef struct packed                             \
    {                                                 \
      logic                        freeze;            \
      logic [vaddr_width_mp-1:0]   npc;               \
      logic [core_id_width_mp-1:0] core_id;           \
      logic [lce_id_width_mp-1:0]  icache_id;         \
      bp_lce_mode_e                icache_mode;       \
      logic [lce_id_width_mp-1:0]  dcache_id;         \
      bp_lce_mode_e                dcache_mode;       \
      logic [cce_id_width_mp-1:0]  cce_id;            \
      bp_cce_mode_e                cce_mode;          \
      logic [hio_width_mp-1:0]     hio_mask;          \
    }  bp_cfg_bus_s

  `define bp_cfg_bus_width(vaddr_width_mp, hio_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp) \
    (1                                \
     + vaddr_width_mp                 \
     + core_id_width_mp               \
     + lce_id_width_mp                \
     + $bits(bp_lce_mode_e)           \
     + lce_id_width_mp                \
     + $bits(bp_lce_mode_e)           \
     + cce_id_width_mp                \
     + $bits(bp_cce_mode_e)           \
     + hio_width_mp                   \
     )

`endif


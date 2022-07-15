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

`ifndef BP_FE_ICACHE_DEFINES_SVH
`define BP_FE_ICACHE_DEFINES_SVH

  `define declare_bp_fe_icache_pkt_s(vaddr_width_mp) \
    typedef struct packed                 \
    {                                     \
      logic [vaddr_width_mp-1:0] vaddr;   \
      bp_fe_icache_op_e          op;      \
    }  bp_fe_icache_pkt_s;

  `define bp_fe_icache_pkt_width(vaddr_width_mp) \
    (vaddr_width_mp+$bits(bp_fe_icache_op_e))

`endif


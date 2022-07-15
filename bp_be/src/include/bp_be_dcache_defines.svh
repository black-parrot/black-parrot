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


`ifndef BP_BE_DCACHE_DEFINES_SVH
`define BP_BE_DCACHE_DEFINES_SVH

  `define declare_bp_be_dcache_pkt_s(vaddr_width_mp) \
    typedef struct packed                           \
    {                                               \
      logic [reg_addr_width_gp-1:0]    rd_addr;     \
      bp_be_dcache_fu_op_e             opcode;      \
      logic [vaddr_width_mp-1:0]       vaddr;       \
      logic [dpath_width_gp-1:0]       data;        \
    }  bp_be_dcache_pkt_s;                          \

  `define declare_bp_be_dcache_wbuf_entry_s(paddr_width_mp, ways_mp) \
    typedef struct packed                           \
    {                                               \
      logic [paddr_width_mp-1:0]           paddr;   \
      logic [dword_width_gp-1:0]           data;    \
      logic [(dword_width_gp>>3)-1:0]      mask;    \
      logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] way_id;  \
    } bp_be_dcache_wbuf_entry_s

  `define bp_be_dcache_pkt_width(vaddr_width_mp) \
    (dpath_width_gp+vaddr_width_mp+$bits(bp_be_dcache_fu_op_e)+reg_addr_width_gp)

  `define bp_be_dcache_wbuf_entry_width(paddr_width_mp, ways_mp) \
    (paddr_width_mp+dword_width_gp+(dword_width_gp>>3)+`BSG_SAFE_CLOG2(ways_mp))

`endif


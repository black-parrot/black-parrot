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

/*
 * bp_fe_defines.svh
 *
 * bp_fe_defines.svh provides all the necessary structs for the Frontend submodules.
 * Backend supplies the frontend with branch prediction results and exceptions
 * codes. The Frontend should update the states accordingly.
 */

`ifndef BP_FE_DEFINES_SVH
`define BP_FE_DEFINES_SVH

  `include "bsg_defines.v"
  `include "bp_common_core_if.svh"
  `include "bp_fe_icache_defines.svh"

  /*
   * bp_fe_instr_scan_s specifies metadata about the instruction, including FE-special opcodes
   *   and the calculated branch target
   */
  `define declare_bp_fe_instr_scan_s(vaddr_width_mp) \
    typedef struct packed                    \
    {                                        \
      logic branch;                          \
      logic jal;                             \
      logic jalr;                            \
      logic call;                            \
      logic ret;                             \
      logic [vaddr_width_mp-1:0] imm;        \
    }  bp_fe_instr_scan_s;

  `define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ghist_width_mp, bht_row_width_mp) \
    typedef struct packed                                                                         \
    {                                                                                             \
      logic                           is_br;                                                      \
      logic                           is_jal;                                                     \
      logic                           is_jalr;                                                    \
      logic                           is_call;                                                    \
      logic                           is_ret;                                                     \
      logic                           src_btb;                                                    \
      logic                           src_ret;                                                    \
      logic [btb_tag_width_mp-1:0]    btb_tag;                                                    \
      logic [btb_idx_width_mp-1:0]    btb_idx;                                                    \
      logic [bht_idx_width_mp-1:0]    bht_idx;                                                    \
      logic [bht_row_width_mp-1:0]    bht_row;                                                    \
      logic [ghist_width_mp-1:0]      ghist;                                                      \
    }  bp_fe_branch_metadata_fwd_s;

  `define declare_bp_fe_pc_gen_stage_s(vaddr_width_mp, ghist_width_mp, bht_row_width_mp) \
    typedef struct packed                   \
    {                                       \
      logic pred;                           \
      logic taken;                          \
      logic redir;                          \
      logic ret;                            \
      logic btb;                            \
      logic [bht_row_width_mp-1:0] bht_row; \
      logic [ghist_width_mp-1:0] ghist;     \
    }  bp_fe_pred_s

  `define bp_fe_instr_scan_width(vaddr_width_mp) \
    (5 + vaddr_width_mp)

  `define bp_fe_pred_width(vaddr_width_mp, ghist_width_mp, bht_row_width_mp) \
    (5 + bht_row_width_mp + ghist_width_mp)

  `include "bp_fe_icache_pkgdef.svh"

`endif


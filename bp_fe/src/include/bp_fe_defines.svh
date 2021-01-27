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

  `define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ghist_width_mp) \
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
      logic [1:0]                     bht_val;                                                    \
      logic [ghist_width_mp-1:0]      ghist;                                                      \
    }  bp_fe_branch_metadata_fwd_s;

  `define declare_bp_fe_pc_gen_stage_s(vaddr_width_mp, ghist_width_mp) \
    typedef struct packed               \
    {                                   \
      logic taken;                      \
      logic redir;                      \
      logic ret;                        \
      logic btb;                        \
      logic [1:0] bht;                  \
      logic [ghist_width_mp-1:0] ghist; \
    }  bp_fe_pred_s

  `define bp_fe_instr_scan_width(vaddr_width_mp) \
    (5 + vaddr_width_mp)

  `define bp_fe_pred_width(vaddr_width_mp, ghist_width_mp) \
    (6 + ghist_width_mp)

  `include "bp_fe_icache_pkgdef.svh"

`endif


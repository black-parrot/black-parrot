/*
 * bp_fe_defines.svh
 *
 * bp_fe_defines.svh provides all the necessary structs for the Frontend submodules.
 * Backend supplies the frontend with branch prediction results and exceptions
 * codes. The Frontend should update the states accordingly.
 */

`ifndef BP_FE_DEFINES_SVH
`define BP_FE_DEFINES_SVH

  `include "bsg_defines.sv"
  `include "bp_fe_icache_defines.svh"

  `define declare_bp_fe_branch_metadata_fwd_s(ras_idx_width_mp, btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ghist_width_mp, bht_row_els_mp) \
    typedef struct packed                                                                         \
    {                                                                                             \
      logic                                       site_br;                                        \
      logic                                       site_jal;                                       \
      logic                                       site_jalr;                                      \
      logic                                       site_call;                                      \
      logic                                       site_return;                                    \
      logic                                       src_ras;                                        \
      logic                                       src_btb;                                        \
      logic [ras_idx_width_mp-1:0]                ras_next;                                       \
      logic [ras_idx_width_mp-1:0]                ras_tos;                                        \
      logic [btb_tag_width_mp-1:0]                btb_tag;                                        \
      logic [btb_idx_width_mp-1:0]                btb_idx;                                        \
      logic [bht_idx_width_mp-1:0]                bht_idx;                                        \
      logic [2*bht_row_els_mp-1:0]                bht_row;                                        \
      logic [`BSG_SAFE_CLOG2(bht_row_els_mp)-1:0] bht_offset;                                     \
      logic [ghist_width_mp-1:0]                  ghist;                                          \
    }  bp_fe_branch_metadata_fwd_s

`endif


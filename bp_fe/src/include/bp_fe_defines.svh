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
  `include "bp_fe_icache_defines.svh"

  `define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ghist_width_mp, bht_row_width_mp) \
    typedef struct packed                                                                         \
    {                                                                                             \
      logic                           site_br;                                                    \
      logic                           site_jal;                                                   \
      logic                           site_jalr;                                                  \
      logic                           site_call;                                                  \
      logic                           site_return;                                                \
      logic                           src_ras;                                                    \
      logic                           src_btb;                                                    \
      logic [btb_tag_width_mp-1:0]    btb_tag;                                                    \
      logic [btb_idx_width_mp-1:0]    btb_idx;                                                    \
      logic [bht_idx_width_mp-1:0]    bht_idx;                                                    \
      logic [bht_row_width_mp-1:0]    bht_row;                                                    \
      logic [ghist_width_mp-1:0]      ghist;                                                      \
    }  bp_fe_branch_metadata_fwd_s;

  `define bp_addr_is_aligned(addr_mp, num_bytes_mp) \
    (!(|{ addr_mp[$clog2(num_bytes_mp)-1:0] }))

  `define bp_addr_align(addr_mp, num_bytes_mp) \
    ((addr_mp >> $clog2(num_bytes_mp)) << $clog2(num_bytes_mp))

`endif


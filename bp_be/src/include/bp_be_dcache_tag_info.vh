/**
 *  Name:
 *    bp_be_dcache_tag_info.vh
 *
 *  Description:
 *    dcache tag_mem format.
 */

`ifndef BP_BE_DCACHE_TAG_INFO_VH
`define BP_BE_DCACHE_TAG_INFO_VH

`include "bp_common_lce_cce_if.vh"

`define declare_bp_be_dcache_tag_info_s(ptag_width_mp) \
  typedef struct packed {                              \
    bp_coh_states_e              coh_state;            \
    logic [ptag_width_mp-1:0]    tag;                  \
  } bp_be_dcache_tag_info_s

`define bp_be_dcache_tag_info_width(ptag_width_mp) \
  (ptag_width_mp+$bits(bp_coh_states_e))

`endif

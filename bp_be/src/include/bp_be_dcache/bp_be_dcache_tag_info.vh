/**
 *  bp_be_dcache_tag_info.vh
 */

`ifndef BP_BE_DCACHE_TAG_INFO_VH
`define BP_BE_DCACHE_TAG_INFO_VH

`define declare_bp_be_dcache_tag_info_s(ptag_width_mp) \
  typedef struct packed {               \
    logic [1:0] coh_state;              \
    logic [ptag_width_mp-1:0] tag;      \
  } bp_be_dcache_tag_info_s
  
`define bp_be_dcache_tag_info_width(ptag_width_mp) \
  (ptag_width_mp+2)

`endif

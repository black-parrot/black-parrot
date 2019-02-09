/**
 *  Name:
 *    bp_be_dcache_stat_info.vh
 *
 *  Description:
 *    stat_mem entry format.
 */

`ifndef BP_BE_DCACHE_STAT_INFO_VH
`define BP_BE_DCACHE_STAT_INFO_VH

`define declare_bp_be_dcache_stat_info_s(ways_mp)  \
  typedef struct packed {                 \
    logic [ways_mp-2:0] lru;              \
    logic [ways_mp-1:0] dirty;            \
  } bp_be_dcache_stat_info_s

`define bp_be_dcache_stat_info_width(ways_mp) \
  (2*ways_mp-1)

`endif

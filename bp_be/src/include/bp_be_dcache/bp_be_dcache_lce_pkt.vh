/**
 *  Name:
 *    bp_be_dcache_lce_pkt.vh
 *
 *  Description:
 *    packet definition that LCE uses to access data_mem, tag_mem, and stat_mem.
 */

`ifndef BP_BE_DCACHE_LCE_PKT_VH
`define BP_BE_DCACHE_LCE_PKT_VH

`include "bp_common_me_if.vh"

//  data_mem pkt
//
`define declare_bp_be_dcache_lce_data_mem_pkt_s(sets_mp, ways_mp, data_width_mp) \
  typedef struct packed { \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0] index; \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] way_id; \
    logic [data_width_mp-1:0] data; \
    bp_be_dcache_lce_data_mem_opcode_e opcode; \
  } bp_be_dcache_lce_data_mem_pkt_s

`define bp_be_dcache_lce_data_mem_pkt_width(sets_mp, ways_mp, data_width_mp) \
  (`BSG_SAFE_CLOG2(sets_mp)+data_width_mp+`BSG_SAFE_CLOG2(ways_mp)+2)


//  tag_mem pkt
//
`define declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_mp, ways_mp, tag_width_mp) \
  typedef struct packed { \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0] index; \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] way_id; \
    logic [`bp_coh_bits-1:0] state; \
    logic [tag_width_mp-1:0] tag; \
    bp_be_dcache_lce_tag_mem_opcode_e opcode; \
  } bp_be_dcache_lce_tag_mem_pkt_s

`define bp_be_dcache_lce_tag_mem_pkt_width(sets_mp, ways_mp, tag_width_mp) \
  (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+tag_width_mp+`bp_coh_bits+2)


//  stat_mem pkt
//
`define declare_bp_be_dcache_lce_stat_mem_pkt_s(sets_mp, ways_mp) \
  typedef struct packed { \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0] index; \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] way_id; \
    bp_be_dcache_lce_stat_mem_opcode_e opcode; \
  } bp_be_dcache_lce_stat_mem_pkt_s

`define bp_be_dcache_lce_stat_mem_pkt_width(sets_mp, ways_mp) \
  (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+2)


`endif

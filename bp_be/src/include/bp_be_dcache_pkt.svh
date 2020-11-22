/**
 *  Name:
 *    bp_be_dcache_pkt.svh
 *
 *  Description:
 *    dcache packet format to be sent from mmu.
 */

`ifndef BP_BE_DCACHE_PKT_VH
`define BP_BE_DCACHE_PKT_VH

`define declare_bp_be_dcache_pkt_s(page_offset_width_mp, data_width_mp) \
  typedef struct packed {                                      \
    bp_be_dcache_fu_op_e opcode;                               \
    logic [page_offset_width_mp-1:0] page_offset;              \
    logic [data_width_mp-1:0] data;                            \
  } bp_be_dcache_pkt_s

`define bp_be_dcache_pkt_width(page_offset_width_mp, data_width_mp) \
  ($bits(bp_be_dcache_fu_op_e)+page_offset_width_mp+data_width_mp)

`endif

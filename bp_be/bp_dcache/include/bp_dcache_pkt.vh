/**
 *  bp_dcache_pkt.vh
 *
 *  @author tommy
 */

`ifndef BP_DCACHE_PKT_VH
`define BP_DCACHE_PKT_VH

import bp_dcache_pkg::*;

`define declare_bp_dcache_pkt_s(vaddr_width_mp, data_width_mp) \
  typedef struct packed {                                      \
    bp_dcache_opcode_e opcode;                                 \
    logic [vaddr_width_mp-1:0] vaddr;                          \
    logic [data_width_mp-1:0] data;                            \
  } bp_dcache_pkt_s

`define bp_dcache_pkt_width(vaddr_width_mp, data_width_mp) \
  (4+vaddr_width_mp+data_width_mp)

`endif

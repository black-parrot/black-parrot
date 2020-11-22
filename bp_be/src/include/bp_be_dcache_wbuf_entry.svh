/**
 *  Name:
 *    bp_be_dcache_wbuf_entry.svh
 *
 *  Description:
 *    dcache write buffer entry format.
 */


`ifndef BP_BE_DCACHE_WBUF_ENTRY_VH
`define BP_BE_DCACHE_WBUF_ENTRY_VH

`define declare_bp_be_dcache_wbuf_entry_s(paddr_width_mp, data_width_mp, ways_mp) \
  typedef struct packed {                           \
    logic [paddr_width_mp-1:0] paddr;               \
    logic [data_width_mp-1:0] data;                 \
    logic [(data_width_mp>>3)-1:0] mask;            \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] way_id;    \
  } bp_be_dcache_wbuf_entry_s

`define bp_be_dcache_wbuf_entry_width(paddr_width_mp, data_width_mp, ways_mp) \
  (paddr_width_mp+data_width_mp+(data_width_mp>>3)+`BSG_SAFE_CLOG2(ways_mp))

`endif

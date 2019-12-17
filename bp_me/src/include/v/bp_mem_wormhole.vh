/**
 *
 * Name:
 *   bp_mem_wormhole.vh
 *
 */

`ifndef BP_MEM_WORMHOLE_VH
`define BP_MEM_WORMHOLE_VH

`include "bsg_noc_links.vh"
`include "bsg_wormhole_router.vh"

`define declare_bp_mem_wormhole_payload_s(cord_width_mp, cid_width_mp, data_width_mp, struct_name_mp) \
    typedef struct packed                                               \
    {                                                                   \
      logic [data_width_mp-1:0]     data;                               \
      logic [cord_width_mp-1:0]     src_cord;                           \
      logic [cid_width_mp-1:0]      src_cid;                            \
    } struct_name_mp
    
`define bp_mem_wormhole_payload_width(cord_width_mp, cid_width_mp, data_width_mp) \
  (cord_width_mp+cid_width_mp+data_width_mp)

`define declare_bp_io_wormhole_payload_s(cord_width_mp, data_width_mp, struct_name_mp) \
    typedef struct packed                                               \
    {                                                                   \
      logic [data_width_mp-1:0]     data;                               \
      logic [cord_width_mp-1:0]     src_cord;                           \
    } struct_name_mp
    
`define bp_io_wormhole_payload_width(cord_width_mp, data_width_mp) \
  (cord_width_mp+data_width_mp)

`endif


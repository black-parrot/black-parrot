/**
 *
 * Name:
 *   bp_mem_wormhole.vh
 *
 */

`ifndef BP_MEM_WORMHOLE_VH
`define BP_MEM_WORMHOLE_VH

`include "bsg_noc_links.vh"

`define declare_bp_mem_wormhole_payload_s(reserved_width_mp, cord_width_mp, data_width_mp, struct_name_mp) \
    typedef struct packed {                                             \
      logic [data_width_mp-1:0]     data;                               \
      logic [cord_width_mp-1:0]     src_cord;                           \
      logic [reserved_width_mp-1:0] reserved;                           \
    } struct_name_mp
    
`define bp_mem_wormhole_payload_width(reserved_width_mp, cord_width_mp, data_width_mp) \
  (reserved_width_mp+cord_width_mp+data_width_mp)

`define declare_bp_mem_wormhole_packet_s(reserved_width, cord_width, len_width, data_width, in_struct_name) \
    typedef struct packed {                                             \
      logic [data_width-1:0]     data;                                  \
      logic [cord_width-1:0]     src_cord;                              \
      logic [reserved_width-1:0] reserved;                              \
      logic [len_width-1:0]      len;                                   \
      logic [cord_width-1:0]     cord;                                  \
    } in_struct_name

`define bp_mem_wormhole_packet_width(reserved_width, cord_width, len_width, data_width) \
  (2*cord_width+len_width+reserved_width+data_width)

`define declare_wormhole_header_flit_s(flit_width, cord_width, len_width, in_struct_name) \
    typedef struct packed {                                             \
      logic [flit_width-cord_width-len_width-1:0] data;                 \
      logic [len_width-1:0]      len;                                   \
      logic [cord_width-1:0]     cord;                                  \
    } in_struct_name

`endif


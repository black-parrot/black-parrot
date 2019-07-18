/**
 *
 * Name:
 *   bp_mem_wormhole.vh
 *
 */

`ifndef BP_MEM_WORMHOLE_VH
`define BP_MEM_WORMHOLE_VH

`include "bsg_noc_links.vh"

`define bp_mem_wormhole_packet_width(reserved_width, cord_width, len_width, data_width) (reserved_width+2*cord_width+len_width+data_width+2)

`define declare_bp_mem_wormhole_packet_s(reserved_width, cord_width, len_width, data_width, in_struct_name) \
    typedef struct packed {                                             \
      logic [data_width-1:0]     data;                                  \
      logic                      write_en;                              \
      logic                      non_cacheable;                         \
      logic [cord_width-1:0]     src_cord;                              \
      logic [reserved_width-1:0] reserved;                              \
      logic [len_width-1:0]      len;                                   \
      logic [cord_width-1:0]     cord;                                  \
    } in_struct_name
    
`define declare_wormhole_header_flit_s(flit_width, cord_width, len_width, in_struct_name) \
    typedef struct packed {                                             \
      logic [flit_width-cord_width-len_width-1:0] data;                 \
      logic [len_width-1:0]      len;                                   \
      logic [cord_width-1:0]     cord;                                  \
    } in_struct_name

`endif

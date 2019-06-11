/**
 *
 * Name:
 *   bp_mem_wormhole.vh
 *
 */

`ifndef BP_MEM_WORMHOLE_VH
`define BP_MEM_WORMHOLE_VH

`include "bsg_noc_links.vh"

`define bp_mem_wormhole_packet_width(reserved_width, x_cord_width, y_cord_width, len_width, data_width) (reserved_width+2*x_cord_width+2*y_cord_width+len_width+data_width+2)

`define declare_bp_mem_wormhole_packet_s(reserved_width, x_cord_width, y_cord_width, len_width, data_width, in_struct_name) \
    typedef struct packed {                                             \
      logic [data_width-1:0]     data;                                  \
      logic                      write_en;                              \
      logic                      non_cacheable;                         \
      logic [y_cord_width-1:0]   src_y_cord;                            \
      logic [x_cord_width-1:0]   src_x_cord;                            \
      logic [reserved_width-1:0] reserved;                              \
      logic [len_width-1:0]      len;                                   \
      logic [y_cord_width-1:0]   y_cord;                                \
      logic [x_cord_width-1:0]   x_cord;                                \
    } in_struct_name

`endif

/**
 *
 * Name:
 *   bp_mem_wormhole.vh
 *
 */

`ifndef BP_MEM_WORMHOLE_VH
`define BP_MEM_WORMHOLE_VH

`define declare_bp_mem_wormhole_header_s(width_p, reserved_width_p, x_cord_width_p, y_cord_width_p, len_width_p, nc_size_width_p,  paddr_width_p, in_struct_name) \
    typedef struct packed {                                               \
      logic [reserved_width_p-1:0] reserved;                              \
      logic [x_cord_width_p-1:0] x_cord;                                  \
      logic [y_cord_width_p-1:0] y_cord;                                  \
      logic [len_width_p-1:0] len;                                        \
      logic [width_p-reserved_width_p-x_cord_width_p-y_cord_width_p       \
            -len_width_p-nc_size_width_p-paddr_width_p-2-1:0] dummy;      \
      logic [x_cord_width_p-1:0] src_x_cord;                              \
      logic [y_cord_width_p-1:0] src_y_cord;                              \
      logic write_en;                                                     \
      logic non_cacheable;                                                \
      logic [nc_size_width_p-1:0] nc_size;                                \
      logic [paddr_width_p-1:0] addr;                                     \
    } in_struct_name

`endif

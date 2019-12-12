/**
 *
 * Name:
 *   bp_io_mesh.vh
 *
 */

`ifndef BP_IO_MESH_VH
`define BP_IO_MESH_VH

`include "bsg_noc_links.vh"

`define declare_bp_io_mesh_payload_s(cord_width_mp, data_width_mp, struct_name_mp) \
    typedef struct packed                     \
    {                                         \
      logic [data_width_mp-1:0]     data;     \
      logic [cord_width_mp-1:0]     src_cord; \
    }  struct_name_mp

`define bp_io_mesh_payload_width(cord_width_mp, data_width_mp) \
  (data_width_mp+cord_width_mp)
    
`endif


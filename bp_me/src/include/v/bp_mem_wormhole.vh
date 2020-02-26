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

`define declare_bp_mem_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp, data_width_mp, struct_name_mp) \
  typedef struct packed                 \
  {                                     \
    logic [data_width_mp-1:0] data;     \
    logic [`bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp)-1:0] \
                              pad;      \
    logic [msg_width_mp-1:0]  msg;      \
    logic [cid_width_mp-1:0]  src_cid;  \
    logic [cord_width_mp-1:0] src_cord; \
    logic [cid_width_mp-1:0]  cid;      \
    logic [len_width_mp-1:0]  len;      \
    logic [cord_width_mp-1:0] cord;     \
  }  struct_name_mp

`define bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp) \
  ((2*cord_width_mp+2*cid_width_mp+len_width_mp+msg_width_mp)%flit_width_mp==0   \
   ? flit_width_mp                                                               \
   : (2*cord_width_mp+2*cid_width_mp+len_width_mp+msg_width_mp)%flit_width_mp    \
   )

`define bp_mem_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp, data_width_mp) \
  (cid_width_mp   \
   +cord_width_mp \
   +cid_width_mp  \
   +msg_width_mp  \
   +`bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp) \
   +data_width_mp \
   )

`define bp_mem_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp, data_width_mp) \
  (cord_width_mp   \
   +len_width_mp   \
   +`bp_mem_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_width_mp, data_width_mp) \
   )

`define declare_bp_lce_wormhole_packet_s(cord_width_mp, cid_width_mp, len_width_mp, msg_width_mp, flit_width_mp, data_width_mp, struct_name_mp) \
  typedef struct packed              \
  {                                  \
    logic [data_width_mp-1:0] data;  \
    logic [`bp_lce_wormhole_packet_pad_width(cord_width_mp, cid_width_mp, len_width_mp, msg_width_mp, flit_width_mp)] \
                              pad;   \
    logic [msg_width_mp-1:0]  msg;   \
    logic [cid_width_mp-1:0]  cid;   \
    logic [len_width_mp-1:0]  len;   \
    logic [cord_width_mp-1:0] cord;  \
  } struct_name_mp

`define bp_lce_wormhole_packet_pad_width(cord_width_mp, cid_width_mp, len_width_mp, msg_width_mp, flit_width_mp) \
  ((cord_width_mp+cid_width_mp+len_width_mp+msg_width_mp)%flit_width_mp==0   \
   ? flit_width_mp                                                           \
   : cord_width_mp+cid_width_mp+len_width_mp+msg_width_mp)%flit_width_mp     \
   )

`endif


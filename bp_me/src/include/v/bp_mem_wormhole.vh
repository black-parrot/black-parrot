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

`define declare_bp_mem_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
  typedef struct packed                 \
  {                                     \
    logic [cid_width_mp-1:0]  src_cid;  \
    logic [cord_width_mp-1:0] src_cord; \
    logic [cid_width_mp-1:0]  cid;      \
    logic [len_width_mp-1:0]  len;      \
    logic [cord_width_mp-1:0] cord;     \
  }  bp_mem_router_header_s;            \
                                        \
  typedef struct packed                 \
  {                                     \
    logic [(flit_width_mp-(2*cord_width_mp+2*cid_width_mp+len_width_mp+$bits(msg_hdr_name_mp))%flit_width_mp)-1:0] \
                              pad;      \
    msg_hdr_name_mp           msg_hdr;  \
    bp_mem_router_header_s    wh_hdr;   \
  }  bp_mem_wormhole_header_s;          \
                                        \
  typedef struct packed                 \
  {                                     \
    logic [data_width_mp-1:0] data;     \
    bp_mem_wormhole_header_s  header;   \
  }  bp_mem_wormhole_packet_s;

`define bp_mem_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
  (cid_width_mp + cord_width_mp + cid_width_mp + msg_hdr_width_mp + data_width_mp \
   + `bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
   )

`define bp_mem_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
  (cord_width_mp + len_width_mp + data_width_mp \
   + `bp_mem_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
   )

`define bp_mem_noc_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
  (cord_width_mp + len_width_mp \
   + `bp_mem_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
   )

`define declare_bp_coh_wormhole_packet_s(flit_width_mp, cord_width_mp, cid_width_mp, len_width_mp, msg_hdr_name_mp, struct_name_mp) \
  typedef struct packed                \
  {                                    \
    logic [cid_width_mp-1:0]  cid;     \
    logic [len_width_mp-1:0]  len;     \
    logic [cord_wisth_mp-1:0] cord;    \
  }  bp_coh_router_header_s;           \
                                       \
  typedef struct packed                \
  {                                    \
    logic [(flit_width_mp-(cord_width_mp+cid_width_mp+len_width_mp+$bits(msg_hdr_name_mp))%flit_width_mp-1:0] \
                              pad;     \
    msg_hdr_name_mp           msg_hdr; \
    bp_coh_router_header_s    wh_hdr;  \
  }  bp_coh_noc_header_s;              \
                                       \
  typedef struct packed                \
  {                                    \
    logic [data_width_mp-1:0] data;    \
    bp_coh_noc_header_s       header;  \
  }  bp_coh_wormhole_packet_s;

`define bp_coh_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
  (cid_width_mp + msg_hdr_width_mp \
   + `bp_coh_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, cid_width_mp, len_width_mp, msg_hdr_name_mp) \
   )

`define bp_coh_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
  (cord_width_mp + len_width_mp + data_width_mp \
   + `bp_coh_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
   )

`define bp_coh_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
  (cord_width_mp + len_width_mp \
   + `bp_coh_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
   )

`endif


/**
 *
 * Name:
 *   bp_me_wormhole_defines.svh
 *
 * Note: standard bsg_wormhole messages are {payload, len, cord}
 *       The messages defined here contain extra "header" fields specific
 *       to the networks that are considered part of the payload by the regular
 *       bsg_wormhole networks and routers.
 *
 */

`ifndef BP_ME_WORMHOLE_DEFINES_SVH
`define BP_ME_WORMHOLE_DEFINES_SVH

`include "bsg_noc_links.vh"
`include "bsg_wormhole_router.vh"

  /*
   * BedRock Memory Network Wormhole Packet Definitions
   */

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
      logic [`bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, $bits(msg_hdr_name_mp))-1:0] \
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

  `define bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
    (flit_width_mp-((2*cord_width_mp+2*cid_width_mp+len_width_mp+msg_hdr_width_mp)%flit_width_mp))

  `define bp_mem_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
    (cord_width_mp + len_width_mp + cid_width_mp + cord_width_mp + cid_width_mp + msg_hdr_width_mp \
     + `bp_mem_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
     )

  `define bp_mem_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
    (data_width_mp \
     + `bp_mem_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
     )

  `define bp_mem_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
    (`bp_mem_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
     - len_width_mp - cord_width_mp \
     )

  /*
   * BedRock LCE Coherence Network Wormhole Packet Definitions
   */

  `define declare_bp_coh_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, struct_name_mp, data_width_mp) \
    typedef struct packed                     \
    {                                         \
      logic [cid_width_mp-1:0]  cid;          \
      logic [len_width_mp-1:0]  len;          \
      logic [cord_width_mp-1:0] cord;         \
    }  bp_``struct_name_mp``_router_header_s; \
                                              \
    typedef struct packed                     \
    {                                         \
      logic [`bp_coh_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, $bits(msg_hdr_name_mp))-1:0] \
                                            pad;      \
      msg_hdr_name_mp                       msg_hdr;  \
      bp_``struct_name_mp``_router_header_s wh_hdr;   \
    }  bp_``struct_name_mp``_wormhole_header_s;       \
                                                      \
    typedef struct packed                             \
    {                                                 \
      logic [data_width_mp-1:0]               data;   \
      bp_``struct_name_mp``_wormhole_header_s header; \
    }  bp_``struct_name_mp``_wormhole_packet_s;

  `define bp_coh_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
    (flit_width_mp-((cord_width_mp+cid_width_mp+len_width_mp+msg_hdr_width_mp)%flit_width_mp))

  `define bp_coh_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
    (cord_width_mp + len_width_mp + cid_width_mp + msg_hdr_width_mp \
     + `bp_coh_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
     )

  `define bp_coh_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
    (data_width_mp \
     + `bp_coh_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
     )

  // note: cid_width_mp is counted as part of the payload for a standard wormhole message
  // wormhole message = {payload, len, cord}
  `define bp_coh_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
    (`bp_coh_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
     - len_width_mp - cord_width_mp \
     )

  `define declare_bp_lce_req_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_coh_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_req, data_width_mp)

  `define declare_bp_lce_cmd_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_coh_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_cmd, data_width_mp)

  `define declare_bp_lce_resp_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_coh_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_resp, data_width_mp)

`endif


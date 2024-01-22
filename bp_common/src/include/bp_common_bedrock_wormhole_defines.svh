/**
 *
 * Name:
 *   bp_common_bedrock_wormhole_defines.svh
 *
 * Note: standard bsg_wormhole messages are {payload, len, cord}
 *       The messages defined here contain extra "header" fields specific
 *       to the networks that are considered part of the payload by the regular
 *       bsg_wormhole networks and routers.
 *
 */

`ifndef BP_COMMON_BEDROCK_WORMHOLE_DEFINES_SVH
`define BP_COMMON_BEDROCK_WORMHOLE_DEFINES_SVH

`include "bsg_noc_links.svh"
`include "bsg_wormhole_router.svh"

  /*
   * BedRock LCE Coherence Network Wormhole Packet Definitions
   */

  `define declare_bp_bedrock_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, struct_name_mp) \
    `declare_bsg_wormhole_concentrator_header_s(cord_width_mp, len_width_mp, cid_width_mp, bsg_``struct_name_mp``_router_hdr_s); \
    typedef struct packed                     \
    {                                         \
      logic [`bp_bedrock_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, $bits(msg_hdr_name_mp))-1:0] \
                                            pad;      \
      msg_hdr_name_mp                       msg_hdr;  \
      bsg_``struct_name_mp``_router_hdr_s   rtr_hdr;  \
    }  bp_``struct_name_mp``_wormhole_header_s

  `define declare_bp_bedrock_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, struct_name_mp, data_width_mp) \
    `declare_bp_bedrock_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, struct_name_mp); \
                                                      \
    typedef struct packed                             \
    {                                                 \
      logic [data_width_mp-1:0]               data;   \
      bp_``struct_name_mp``_wormhole_header_s header; \
    }  bp_``struct_name_mp``_wormhole_packet_s

  `define bp_bedrock_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
    (flit_width_mp-((cord_width_mp+cid_width_mp+len_width_mp+msg_hdr_width_mp)%flit_width_mp))

  `define bp_bedrock_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
    (cord_width_mp + len_width_mp + cid_width_mp + msg_hdr_width_mp \
     + `bp_bedrock_wormhole_packet_pad_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
     )

  `define bp_bedrock_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
    (data_width_mp \
     + `bp_bedrock_wormhole_header_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp) \
     )

  // note: cid_width_mp is counted as part of the payload for a standard wormhole message
  // wormhole message = {payload, len, cord}
  `define bp_bedrock_wormhole_payload_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
    (`bp_bedrock_wormhole_packet_width(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_width_mp, data_width_mp) \
     - len_width_mp - cord_width_mp \
     )

  `define declare_bp_lce_req_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp) \
    `declare_bp_bedrock_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_req)

  `define declare_bp_lce_cmd_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp) \
    `declare_bp_bedrock_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_cmd)

  `define declare_bp_lce_fill_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp) \
    `declare_bp_bedrock_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_fill)

  `define declare_bp_lce_resp_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp) \
    `declare_bp_bedrock_wormhole_header_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_resp)

  `define declare_bp_lce_req_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_bedrock_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_req, data_width_mp)

  `define declare_bp_lce_cmd_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_bedrock_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_cmd, data_width_mp)

  `define declare_bp_lce_fill_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_bedrock_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_fill, data_width_mp)

  `define declare_bp_lce_resp_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, data_width_mp) \
    `declare_bp_bedrock_wormhole_packet_s(flit_width_mp, cord_width_mp, len_width_mp, cid_width_mp, msg_hdr_name_mp, lce_resp, data_width_mp)

`endif


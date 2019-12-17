/**
 *  Name:
 *    bp_me_wormhole_packet_encode_io_resp.v
 *
 *  Description:
 *    It takes bp_io_resp_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, cord}
 */

`include "bp_mem_wormhole.vh"

module bp_me_wormhole_packet_encode_io_resp
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_io_if_widths(paddr_width_p, dword_width_p, lce_id_width_p)

    , localparam io_resp_payload_width_lp =
        `bp_io_wormhole_payload_width(io_noc_cord_width_p, cce_io_msg_width_lp)
    , localparam io_resp_packet_width_lp = 
        `bsg_wormhole_router_packet_width(io_noc_cord_width_p, io_noc_len_width_p, io_resp_payload_width_lp)
    )
   (input [cce_io_msg_width_lp-1:0]         io_resp_i
    , input [io_noc_cord_width_p-1:0]      src_cord_i
    , input [io_noc_cord_width_p-1:0]      dst_cord_i
    , output [io_resp_packet_width_lp-1:0]  packet_o
    );

  `declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p);
  `declare_bp_io_wormhole_payload_s(io_noc_cord_width_p, cce_io_msg_width_lp, bp_resp_wormhole_payload_s);
  `declare_bsg_wormhole_router_packet_s(io_noc_cord_width_p, io_noc_len_width_p, $bits(bp_resp_wormhole_payload_s), bp_resp_wormhole_packet_s);

  bp_cce_io_msg_s io_resp_cast_i;
  bp_resp_wormhole_packet_s packet_cast_o;

  assign io_resp_cast_i = io_resp_i;
  assign packet_o       = packet_cast_o;

  bp_resp_wormhole_payload_s payload_li;

  localparam io_resp_ack_len_lp =
    `BSG_CDIV(io_resp_packet_width_lp-$bits(io_resp_cast_i.data), io_noc_flit_width_p) - 1;
  localparam io_resp_data_len_1_lp =
    `BSG_CDIV(io_resp_packet_width_lp-$bits(io_resp_cast_i.data) + 8*1, io_noc_flit_width_p) - 1;
  localparam io_resp_data_len_2_lp =
    `BSG_CDIV(io_resp_packet_width_lp-$bits(io_resp_cast_i.data) + 8*2, io_noc_flit_width_p) - 1;
  localparam io_resp_data_len_4_lp =
    `BSG_CDIV(io_resp_packet_width_lp-$bits(io_resp_cast_i.data) + 8*4, io_noc_flit_width_p) - 1;
  localparam io_resp_data_len_8_lp =
    `BSG_CDIV(io_resp_packet_width_lp-$bits(io_resp_cast_i.data) + 8*8, io_noc_flit_width_p) - 1;

  logic [io_noc_len_width_p-1:0] data_resp_len_li;

  always_comb begin
    payload_li.data       = io_resp_i;
    payload_li.src_cord   = src_cord_i;

    packet_cast_o.payload = payload_li;
    packet_cast_o.cord    = dst_cord_i;

    case (io_resp_cast_i.size)
      e_io_size_1 : data_resp_len_li = io_noc_len_width_p'(io_resp_data_len_1_lp);
      e_io_size_2 : data_resp_len_li = io_noc_len_width_p'(io_resp_data_len_2_lp);
      e_io_size_4 : data_resp_len_li = io_noc_len_width_p'(io_resp_data_len_4_lp);
      e_io_size_8 : data_resp_len_li = io_noc_len_width_p'(io_resp_data_len_8_lp);
      default: data_resp_len_li = '0;
    endcase

    case (io_resp_cast_i.msg_type)
      e_cce_io_rd: packet_cast_o.len = data_resp_len_li;
      e_cce_io_wr: packet_cast_o.len = io_noc_len_width_p'(io_resp_ack_len_lp);
      default: packet_cast_o = '0;
    endcase
  end

endmodule


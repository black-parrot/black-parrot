/**
 *  Name:
 *    bp_me_wormhole_packet_encode_lce_resp.v
 *
 *  Description:
 *    It takes bp_lce_cce_resp_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, cord}
 */


module bp_me_wormhole_packet_encode_lce_resp
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p)

    , localparam lce_cce_resp_packet_width_lp =
        `bsg_wormhole_concentrator_packet_width(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_resp_width_lp)
    , localparam lce_cce_resp_packet_hdr_width_lp = (lce_cce_resp_packet_width_lp-cce_block_width_p)
    )
   (input [lce_cce_resp_width_lp-1:0]           payload_i
    , output [lce_cce_resp_packet_width_lp-1:0] packet_o
    );

  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p);
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_resp_width_lp, lce_cce_resp_packet_s);

  bp_lce_cce_resp_s payload_cast_i;
  lce_cce_resp_packet_s packet_cast_o;
  assign payload_cast_i = payload_i;
  assign packet_o = packet_cast_o;

  // LCE Request with no data
  localparam lce_cce_resp_ack_len_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp, coh_noc_flit_width_p) - 1;
  // LCE Requests with 1B to 128B of data
  localparam lce_cce_resp_data_len_1_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(1*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_2_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(2*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_4_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(4*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_8_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(8*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_16_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(16*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_32_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(32*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_64_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(64*8), coh_noc_flit_width_p) - 1;
  localparam lce_cce_resp_data_len_128_lp =
    `BSG_CDIV(lce_cce_resp_packet_hdr_width_lp+(128*8), coh_noc_flit_width_p) - 1;

  logic [coh_noc_cord_width_p-1:0] cce_cord_li;
  logic [coh_noc_cid_width_p-1:0]  cce_cid_li;
  bp_me_cce_id_to_cord
   #(.bp_params_p(bp_params_p))
   router_cord
    (.cce_id_i(payload_cast_i.header.dst_id)
     ,.cce_cord_o(cce_cord_li)
     ,.cce_cid_o(cce_cid_li)
     );

  always_comb begin
    packet_cast_o.payload = payload_cast_i;
    packet_cast_o.cid     = cce_cid_li;
    packet_cast_o.cord    = cce_cord_li;

    unique case (payload_cast_i.header.msg_type)
      // acks and null wb send no data
      e_lce_cce_sync_ack
      ,e_lce_cce_inv_ack
      ,e_lce_cce_coh_ack
      ,e_lce_cce_resp_null_wb: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_ack_len_lp);
      // writeback sends data
      e_lce_cce_resp_wb:
        unique case (payload_cast_i.header.size)
          e_mem_msg_size_1: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_1_lp);
          e_mem_msg_size_2: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_2_lp);
          e_mem_msg_size_4: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_4_lp);
          e_mem_msg_size_8: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_8_lp);
          e_mem_msg_size_16: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_16_lp);
          e_mem_msg_size_32: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_32_lp);
          e_mem_msg_size_64: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_64_lp);
          e_mem_msg_size_128: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_data_len_128_lp);
          default: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_resp_ack_len_lp);
        endcase
      default: packet_cast_o = '0;
    endcase
  end

endmodule


/**
 *  Name:
 *    bp_me_wormhole_packet_encode_lce_req.v
 *
 *  Description:
 *    It takes bp_lce_cce_req_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, cord}
 */


module bp_me_wormhole_packet_encode_lce_req
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam lce_cce_req_packet_width_lp = 
        `bsg_wormhole_concentrator_packet_width(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp)
    )
   (input [lce_cce_req_width_lp-1:0]           payload_i
    , output [lce_cce_req_packet_width_lp-1:0] packet_o
    );

  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_cce_req_packet_s);

  bp_lce_cce_req_s payload_cast_i;
  lce_cce_req_packet_s packet_cast_o;
  assign payload_cast_i = payload_i;
  assign packet_o = packet_cast_o;

  // UC Store is header + dword_width_p = full length
  localparam lce_cce_req_req_len_lp =
    `BSG_CDIV(lce_cce_req_packet_width_lp-$bits(payload_cast_i.data), coh_noc_flit_width_p) - 1;
  localparam lce_cce_req_uc_wr_len_lp =
    `BSG_CDIV(lce_cce_req_packet_width_lp, coh_noc_flit_width_p) - 1;
  localparam lce_cce_req_uc_rd_len_lp =
    `BSG_CDIV(lce_cce_req_packet_width_lp-$bits(payload_cast_i.data), coh_noc_flit_width_p) - 1;

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

    case (payload_cast_i.header.msg_type)
      e_lce_req_type_rd
      ,e_lce_req_type_wr  : packet_cast_o.len = coh_noc_len_width_p'(lce_cce_req_req_len_lp);
      e_lce_req_type_uc_rd: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_req_uc_wr_len_lp);
      e_lce_req_type_uc_wr: packet_cast_o.len = coh_noc_len_width_p'(lce_cce_req_uc_wr_len_lp);
      default: packet_cast_o = '0;
    endcase
  end

endmodule


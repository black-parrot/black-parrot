/**
 *  Name:
 *    bp_me_wormhole_packet_encode_req.v
 *
 *  Description:
 *    It takes bp_lce_cce_req_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, cord}
 */


module bp_me_wormhole_packet_encode_req
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    // Generalized Wormhole Router parameters
    , localparam dims_lp                                = 2
    , localparam coh_x_cord_width_lp                    = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam coh_y_cord_width_lp                    = 1
    , localparam int coh_cord_markers_pos_lp[dims_lp:0] =
     '{ coh_x_cord_width_lp+coh_y_cord_width_lp, coh_x_cord_width_lp, 0 }
    , localparam coh_cord_width_lp = coh_cord_markers_pos_lp[dims_lp]

    , localparam lce_cce_req_packet_width_lp = 
        `bsg_wormhole_router_packet_width(coh_cord_width_lp, coh_noc_len_width_p, lce_cce_req_width_lp)
    )
   (input [lce_cce_req_width_lp-1:0]           payload_i
    , output [lce_cce_req_packet_width_lp-1:0] packet_o
    );

  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);
  `declare_bsg_wormhole_router_packet_s(coh_cord_width_lp, coh_noc_len_width_p, lce_cce_req_width_lp, lce_cce_req_packet_s);

  bp_lce_cce_req_s payload_cast_i;
  lce_cce_req_packet_s packet_cast_o;
  assign payload_cast_i = payload_i;
  assign packet_o = packet_cast_o;

  localparam lce_cce_req_req_len_lp =
    `BSG_CDIV(lce_cce_req_packet_width_lp-$bits(payload_cast_i.msg.req.pad), coh_noc_width_p) - 1;
  localparam lce_cce_req_uc_wr_len_lp =
    `BSG_CDIV(lce_cce_req_packet_width_lp, coh_noc_width_p) - 1;
  localparam lce_cce_req_uc_rd_len_lp =
    `BSG_CDIV(lce_cce_req_packet_width_lp-$bits(payload_cast_i.msg.uc_req.data), coh_noc_width_p) - 1;

  always_comb begin
    packet_cast_o.payload = payload_cast_i;
    // Multiply by two because CCEs are on every other router
    packet_cast_o.cord    = payload_cast_i.dst_id << 1'b1;

    case (payload_cast_i.msg_type)
      e_lce_req_type_rd
      ,e_lce_req_type_wr  : packet_cast_o.len = lce_cce_req_req_len_lp;
      e_lce_req_type_uc_rd: packet_cast_o.len = lce_cce_req_uc_wr_len_lp;
      e_lce_req_type_uc_wr: packet_cast_o.len = lce_cce_req_uc_wr_len_lp;
      default: packet_cast_o = '0;
    endcase
  end

endmodule


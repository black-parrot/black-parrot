/**
 *  Name:
 *    bp_me_wormhole_packet_encode_lce_cmd.v
 *
 *  Description:
 *    It takes bp_lce_cmd_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, cord}
 */


`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_wormhole_packet_encode_lce_cmd
  import bp_common_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)

    , localparam lce_cmd_wormhole_header_lp = `bp_coh_wormhole_header_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_msg_header_width_lp)
    )
   (input [lce_cmd_msg_header_width_lp-1:0]   lce_cmd_header_i
    , output [lce_cmd_wormhole_header_lp-1:0] wh_header_o
    );

  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_lce_cmd_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_cmd_msg_header_s, cce_block_width_p);

  bp_bedrock_lce_cmd_msg_header_s header_cast_i;
  bp_bedrock_lce_cmd_payload_s header_cast_payload_i;
  assign header_cast_payload_i = header_cast_i.payload;
  bp_lce_cmd_wormhole_header_s header_cast_o;
  assign header_cast_i = lce_cmd_header_i;
  assign wh_header_o = header_cast_o;

  // LCE Command with no data
  localparam lce_cmd_cmd_len_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp, coh_noc_flit_width_p) - 1;
  // LCE Commands with 1B to 128B of data
  localparam lce_cmd_data_len_1_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(1*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_2_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(2*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_4_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(4*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_8_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(8*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_16_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(16*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_32_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(32*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_64_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(64*8), coh_noc_flit_width_p) - 1;
  localparam lce_cmd_data_len_128_lp =
    `BSG_CDIV(lce_cmd_wormhole_header_lp+(128*8), coh_noc_flit_width_p) - 1;

  logic [coh_noc_cord_width_p-1:0] lce_cord_li;
  logic [coh_noc_cid_width_p-1:0]  lce_cid_li;
  bp_me_lce_id_to_cord
   #(.bp_params_p(bp_params_p))
   router_cord
    (.lce_id_i(header_cast_payload_i.dst_id)
     ,.lce_cord_o(lce_cord_li)
     ,.lce_cid_o(lce_cid_li)
     );

  always_comb begin
    header_cast_o = '0;

    header_cast_o.msg_hdr     = header_cast_i;
    header_cast_o.wh_hdr.cid  = lce_cid_li;
    header_cast_o.wh_hdr.cord = lce_cord_li;

    unique case (header_cast_i.msg_type)
      // most commands have no data
      e_bedrock_cmd_sync
      ,e_bedrock_cmd_set_clear
      ,e_bedrock_cmd_inv
      ,e_bedrock_cmd_st
      ,e_bedrock_cmd_st_wakeup
      ,e_bedrock_cmd_wb
      ,e_bedrock_cmd_st_wb
      ,e_bedrock_cmd_tr
      ,e_bedrock_cmd_st_tr
      ,e_bedrock_cmd_st_tr_wb
      ,e_bedrock_cmd_uc_st_done: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_cmd_len_lp);
      // data and uncached data commands have data
      e_bedrock_cmd_data
      ,e_bedrock_cmd_uc_data:
        unique case (header_cast_i.size)
          e_bedrock_msg_size_1: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_1_lp);
          e_bedrock_msg_size_2: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_2_lp);
          e_bedrock_msg_size_4: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_4_lp);
          e_bedrock_msg_size_8: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_8_lp);
          e_bedrock_msg_size_16: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_16_lp);
          e_bedrock_msg_size_32: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_32_lp);
          e_bedrock_msg_size_64: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_64_lp);
          e_bedrock_msg_size_128: header_cast_o.wh_hdr.len = coh_noc_len_width_p'(lce_cmd_data_len_128_lp);
          default: begin end
        endcase
      default: begin end
    endcase
  end

endmodule


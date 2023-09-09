/**
 *  Name:
 *    bp_me_wormhole_header_encode.sv
 *
 *  Description:
 *    Generic BedRock to wormhole packet header encoder that takes a generic bedrock header
 *    as input and forms it into a wormhole packet header.
 *
 *    packet = {payload, cid, length, cord}
 */

`include "bp_common_defines.svh"

module bp_me_wormhole_header_encode
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(flit_width_p)
   , parameter `BSG_INV_PARAM(cord_width_p)
   , parameter `BSG_INV_PARAM(cid_width_p)
   , parameter `BSG_INV_PARAM(len_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)

   `declare_bp_bedrock_generic_if_width(paddr_width_p, payload_width_p, msg)

   // Constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   , parameter stream_mask_p = 0

   , localparam wh_header_width_lp =
       `bp_bedrock_wormhole_header_width(flit_width_p, cord_width_p, len_width_p, cid_width_p, msg_header_width_lp)
   )
  (input [msg_header_width_lp-1:0]          header_i

   , input [cord_width_p-1:0]               dst_cord_i
   , input [cid_width_p-1:0]                dst_cid_i

   , output logic [wh_header_width_lp-1:0]  wh_header_o
   );

  `declare_bp_bedrock_generic_if(paddr_width_p, payload_width_p, msg);
  `bp_cast_i(bp_bedrock_msg_header_s, header);

  `declare_bp_bedrock_wormhole_header_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, bp_bedrock_msg_header_s, bedrock);
  `bp_cast_o(bp_bedrock_wormhole_header_s, wh_header);

  // TODO: could leverage bp_bedrock_size_to_len to compute these values
  // Pre-compute flits per header and flits per data (zero-based)
  localparam msg_hdr_len_lp = `BSG_CDIV(wh_header_width_lp, flit_width_p) - 1;
  localparam msg_data_len_1_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_1), flit_width_p) - 1;
  localparam msg_data_len_2_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_2), flit_width_p) - 1;
  localparam msg_data_len_4_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_4), flit_width_p) - 1;
  localparam msg_data_len_8_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_8), flit_width_p) - 1;
  localparam msg_data_len_16_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_16), flit_width_p) - 1;
  localparam msg_data_len_32_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_32), flit_width_p) - 1;
  localparam msg_data_len_64_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_64), flit_width_p) - 1;
  localparam msg_data_len_128_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_128), flit_width_p) - 1;
  // Pre-compute full message flits (hdr + data flits)
  // note: need to add back 1 since both hdr and data lengths are zero-based
  localparam msg_len_1_lp = msg_data_len_1_lp + msg_hdr_len_lp + 1;
  localparam msg_len_2_lp = msg_data_len_2_lp + msg_hdr_len_lp + 1;
  localparam msg_len_4_lp = msg_data_len_4_lp + msg_hdr_len_lp + 1;
  localparam msg_len_8_lp = msg_data_len_8_lp + msg_hdr_len_lp + 1;
  localparam msg_len_16_lp = msg_data_len_16_lp + msg_hdr_len_lp + 1;
  localparam msg_len_32_lp = msg_data_len_32_lp + msg_hdr_len_lp + 1;
  localparam msg_len_64_lp = msg_data_len_64_lp + msg_hdr_len_lp + 1;
  localparam msg_len_128_lp = msg_data_len_128_lp + msg_hdr_len_lp + 1;

  logic [len_width_p-1:0] msg_len_li;

  always_comb
    begin
      wh_header_cast_o = '0;

      wh_header_cast_o.msg_hdr      = header_cast_i;
      wh_header_cast_o.rtr_hdr.cord = dst_cord_i;
      wh_header_cast_o.rtr_hdr.cid  = dst_cid_i;

      unique case (header_cast_i.size)
        e_bedrock_msg_size_1  : msg_len_li = len_width_p'(msg_len_1_lp);
        e_bedrock_msg_size_2  : msg_len_li = len_width_p'(msg_len_2_lp);
        e_bedrock_msg_size_4  : msg_len_li = len_width_p'(msg_len_4_lp);
        e_bedrock_msg_size_8  : msg_len_li = len_width_p'(msg_len_8_lp);
        e_bedrock_msg_size_16 : msg_len_li = len_width_p'(msg_len_16_lp);
        e_bedrock_msg_size_32 : msg_len_li = len_width_p'(msg_len_32_lp);
        e_bedrock_msg_size_64 : msg_len_li = len_width_p'(msg_len_64_lp);
        e_bedrock_msg_size_128: msg_len_li = len_width_p'(msg_len_128_lp);
        default: msg_len_li = '0;
      endcase

      if (stream_mask_p[header_cast_i.msg_type])
        wh_header_cast_o.rtr_hdr.len = len_width_p'(msg_len_li);
      else
        wh_header_cast_o.rtr_hdr.len = len_width_p'(msg_hdr_len_lp);
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wormhole_header_encode)


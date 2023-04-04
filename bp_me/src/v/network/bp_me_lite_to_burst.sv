/**
 *
 * Name:
 *   bp_me_lite_to_burst.sv
 *
 * Description:
 *   Converts BedRock Lite to Burst.
 *
 *   Converter is helpful on both sides and has 2-element fifos for the Lite header and data.
 *   The Burst output can send header and data independently.
 *
 *   By definition, BedRock Lite is a single beat protocol. Every input beat is
 *   translated to a single-beat BedRock Burst transaction of header and at most one
 *   data beat. This module performs no validation on the Lite message, but it is expected
 *   that the message size is no greater than the data channel width.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_lite_to_burst
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, bp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Lite
   // ready-valid-and
   , input [bp_header_width_lp-1:0]                 in_msg_header_i
   , input [data_width_p-1:0]                       in_msg_data_i
   , input                                          in_msg_v_i
   , output logic                                   in_msg_ready_and_o

   // Output BedRock Burst
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          out_msg_header_o
   , output logic                                   out_msg_header_v_o
   , input                                          out_msg_header_ready_and_i
   , output logic                                   out_msg_has_data_o

   // ready-valid-and
   , output logic [data_width_p-1:0]                out_msg_data_o
   , output logic                                   out_msg_data_v_o
   , input                                          out_msg_data_ready_and_i
   , output logic                                   out_msg_last_o
   );

  if (data_width_p != 64) $error("Lite-to-Burst data width must be 64-bits");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, bp);

  bp_bedrock_bp_header_s out_msg_header_lo;
  logic in_msg_v_li;
  logic in_msg_header_ready_and_lo, in_msg_data_ready_and_lo;

  // accept Lite beat only if both fifos can accept
  assign in_msg_ready_and_o = in_msg_header_ready_and_lo & in_msg_data_ready_and_lo;
  assign in_msg_v_li = in_msg_v_i & in_msg_ready_and_o;

  bsg_two_fifo
    #(.width_p(bp_header_width_lp)
      ,.ready_THEN_valid_p(1)
      )
    header_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(in_msg_header_i)
      ,.v_i(in_msg_v_li)
      ,.ready_o(in_msg_header_ready_and_lo)
      ,.data_o(out_msg_header_lo)
      ,.v_o(out_msg_header_v_o)
      ,.yumi_i(out_msg_header_v_o & out_msg_header_ready_and_i)
      );

  bsg_two_fifo
    #(.width_p(data_width_p)
      ,.ready_THEN_valid_p(1)
      )
    data_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(in_msg_data_i)
      ,.v_i(in_msg_v_li)
      ,.ready_o(in_msg_data_ready_and_lo)
      ,.data_o(out_msg_data_o)
      ,.v_o(out_msg_data_v_o)
      ,.yumi_i(out_msg_data_v_o & out_msg_data_ready_and_i)
      );

  assign out_msg_header_o = out_msg_header_lo;
  assign out_msg_has_data_o = payload_mask_p[out_msg_header_lo.msg_type];

  assign out_msg_last_o = 1'b1;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_lite_to_burst)


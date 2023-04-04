/**
 *
 * Name:
 *   bp_me_lite_to_burst.sv
 *
 * Description:
 *   Converts BedRock Lite to Burst.
 *
 *   Converter supports a minimal implementation of BedRock Burst that sends the header beat before
 *   sending any data beats. This avoids buffering the input message that would be required to
 *   allow independent flow control on the output Burst protocol.
 *
 *   By definition, BedRock Lite is a single beat protocol. Every input beat is
 *   translated to a single-beat BedRock Burst transaction of header and at most one
 *   data beat.
 *
 *   TODO: enable header and data send same cycle
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

  bp_bedrock_bp_header_s in_msg_header_li;
  logic in_msg_v_li;
  logic [data_width_p-1:0] in_msg_data_i;
  logic in_msg_yumi_lo;

  bsg_two_fifo
    #(.width_p(bp_header_width_lp+data_width_p))
    lite_fifo
     (.clk_i
      ,.reset_i
      ,.data_i({in_msg_data_i, in_msg_header_i})
      ,.v_i(in_msg_v_i)
      ,.ready_o(in_msg_ready_and_o)
      ,.data_o({in_msg_data_li, in_msg_header_li})
      ,.v_o(in_msg_v_li)
      ,.yumi_i(in_msg_yumi_lo)
      );

  // has_data is raised when input message has valid data
  wire has_data = payload_mask_p[in_msg_header_li.msg_type];

  wire header_sending = out_msg_header_v_o & out_msg_header_ready_and_i;
  wire data_sending = out_msg_data_v_o & out_msg_data_ready_and_i;
  logic header_sent, data_sent;

  assign in_msg_yumi_lo = (header_sending & ~has_data)
                        | (header_sent & data_sending)
                        | (header_sending & data_sent)
                        | (header_sending & data_sending);

  bsg_dff_reset_set_clear
    #(.width_p(2)
      ,.clear_over_set_p(1)
      )
    state_reg
     (.clk_i
      ,.reset_i
      ,.set_i({data_sending, header_sending})
      ,.clear_i({2{in_msg_yumi_lo}})
      ,.data_o({data_sent, header_sent})
      );

  // header passthrough
  assign out_msg_header_o = in_msg_header_li;
  assign out_msg_header_v_o = in_msg_v_li & ~header_sent;
  assign out_msg_has_data_o = has_data;

  // data passthrough
  assign out_msg_data_o = in_msg_data_li;
  assign out_msg_data_v_o = in_msg_v_li & has_data & ~data_sent;
  assign out_msg_last_o = 1'b1;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_lite_to_burst)


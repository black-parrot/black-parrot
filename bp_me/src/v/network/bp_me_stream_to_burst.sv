/**
 *
 * Name:
 *   bp_me_stream_to_burst.sv
 *
 * Description:
 *   Converts BedRock Stream to Burst.
 *
 *   Converter supports a minimal implementation of BedRock Burst that sends the header beat before
 *   sending any data beats. This avoids buffering the input stream that would be required to
 *   allow independent flow control on the output Burst protocol.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_to_burst
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(data_width_p  )
   , parameter `BSG_INV_PARAM(payload_width_p  )

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, data_width_p, bp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Stream
   // ready-valid-and
   , input [bp_header_width_lp-1:0]                 in_msg_header_i
   , input [data_width_p-1:0]                       in_msg_data_i
   , input                                          in_msg_v_i
   , input                                          in_msg_last_i
   , output logic                                   in_msg_ready_and_o

   // Output BedRock Burst
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          out_msg_header_o
   , output logic                                   out_msg_header_v_o
   , output logic                                   out_msg_has_data_o
   , input                                          out_msg_header_ready_and_i

   // ready-valid-and
   , output logic [data_width_p-1:0]                out_msg_data_o
   , output logic                                   out_msg_data_v_o
   , output logic                                   out_msg_last_o
   , input                                          out_msg_data_ready_and_i
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, data_width_p, lce_id_width_p, lce_assoc_p, bp);

  bp_bedrock_bp_header_s in_msg_header_li;
  assign in_msg_header_li = in_msg_header_i;

  // has_data is raised when input stream message has one or more beats of data. It is valid
  // only on the first beat of the input message.
  wire has_data = payload_mask_p[in_msg_header_li.msg_type];

  // streaming register is set while sending output data beats.
  // It is set when header of a data-carrying message sends and cleared when last data
  // beat is consumed by output client.
  logic streaming_r;
  bsg_dff_reset_set_clear
    #(.width_p(1)
      ,.clear_over_set_p(1)
      )
    streaming_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(out_msg_header_v_o & out_msg_header_ready_and_i & has_data)
     ,.clear_i(out_msg_data_v_o & out_msg_data_ready_and_i & out_msg_last_o)
     ,.data_o(streaming_r)
     );

  // header passthrough
  assign out_msg_header_o = in_msg_header_li;
  assign out_msg_header_v_o = in_msg_v_i & ~streaming_r;
  assign out_msg_has_data_o = has_data;

  // data passthrough
  assign out_msg_data_o = in_msg_data_i;
  assign out_msg_data_v_o = in_msg_v_i & streaming_r;
  assign out_msg_last_o = in_msg_last_i;

  // Input messages without data ack are acked by sending of the output header.
  // Input messages with data send the output header without acking the input beat and then ack
  // the N input beats when sending the N output data beats.
  assign in_msg_ready_and_o = streaming_r
                              ? out_msg_data_ready_and_i
                              : ~has_data
                                ? out_msg_header_ready_and_i
                                : '0;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_to_burst)


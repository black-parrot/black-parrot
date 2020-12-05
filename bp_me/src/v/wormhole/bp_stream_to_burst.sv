
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_to_burst
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   // Assuming in_data_width_p(stream) == out_data_width_p(burst)
   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = in_data_width_p
   , parameter payload_width_p  = "inv"

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)

   )
  (input                                     clk_i
   , input                                   reset_i

   // Master BP Stream
   // ready-valid-and
   , input [in_msg_header_width_lp-1:0]      in_msg_header_i
   , input [in_data_width_p-1:0]             in_msg_data_i
   , input                                   in_msg_v_i
   , output logic                            in_msg_ready_and_o
   , input                                   in_msg_last_i

   // Client BP Burst
   // ready-valid-and
   , output logic [out_msg_header_width_lp-1:0]     out_msg_header_o
   , output logic                                   out_msg_header_v_o
   , input logic                                    out_msg_header_ready_and_i

   // ready-valid-and
   , output logic [out_data_width_p-1:0]            out_msg_data_o
   , output logic                                   out_msg_data_v_o
   , input                                          out_msg_data_ready_and_i
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);

  bp_bedrock_out_msg_header_s in_msg_header_cast_o;
  assign in_msg_header_cast_o = in_msg_header_i;
  
  logic streaming_r;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
   streaming_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_v_i & in_msg_ready_and_o)
    ,.clear_i(in_msg_last_i & in_msg_v_i & in_msg_ready_and_o)
    ,.data_o(streaming_r)
    );

  assign in_msg_ready_and_o = streaming_r ? out_msg_data_ready_and_i : (out_msg_header_ready_and_i & out_msg_data_ready_and_i);

  assign out_msg_header_o = in_msg_header_cast_o;
  assign out_msg_header_v_o = in_msg_v_i & ~streaming_r; // keep out_msg_header_v_o low after the header is acked

  // has_data: send the first stream header, with N stream data pkt
  // ~has_data: send the only stream header only
  wire has_data = payload_mask_p[in_msg_header_cast_o.msg_type];

  // passthrough data,
  assign out_msg_data_o = in_msg_data_i;
  assign out_msg_data_v_o = streaming_r 
                            ? in_msg_v_i 
                            : in_msg_v_i & has_data;

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p == out_data_width_p)
        else $error("Input data width should be identical with output data width");
    end
  //synopsys translate_on

endmodule
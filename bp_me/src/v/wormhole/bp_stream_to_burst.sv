
module bp_stream_to_burst
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // in_data_width_p == out_data_width_p, then add sipo/piso out of the module to change the burst_data_width
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
  bp_bedrock_in_msg_header_s in_msg_header_cast_i;
  assign in_msg_header_cast_i = in_msg_header_i;

  logic streaming_r;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
   streaming_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_v_i & in_msg_ready_and_o)
    ,.clear_i(in_msg_last_i)
    ,.data_o(streaming_r)
    );

  // has_data: send the first stream header, with N stream data pkt
  // ~has_data: send the only stream header only
  wire has_data = payload_mask_p[in_msg_header_cast_i.msg_type];
  
  // in_msg_ready_and_o rely on header for ~has_data msg, and on data for has_data_msg
  logic header_ready_lo, data_ready_lo;
  assign in_msg_ready_and_o = has_data ? data_ready_lo : header_ready_lo;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_msg_header_i)
     ,.v_i(in_msg_ready_and_o & in_msg_v_i ~streaming_r)  // Accept the 1st header only
     ,.ready_o(header_ready_lo)

     ,.data_o(out_msg_header_o)
     ,.v_o(out_msg_header_v_o)
     ,.yumi_i(out_msg_header_ready_and_i & out_msg_header_v_o)
     );
  
  bsg_one_fifo
   #(.width_p(in_data_width_p))
   data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_msg_data_i)
     ,.v_i(in_msg_ready_and_o & in_msg_v_i & has_data)
     ,.ready_o(data_ready_lo)

     ,.data_o(out_msg_data_o)
     ,.v_o(out_msg_data_v_o)
     ,.yumi_i(out_msg_data_ready_and_i & out_msg_data_v_o)
     );

endmodule
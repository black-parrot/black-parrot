
module bp_burst_to_stream
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

  // in_data_width_p == out_data_width_p, then add sipo/piso out of the module to change the burst_data_width
   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = "inv"
   , parameter payload_width_p  = "inv"

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)

   )
  (input                                            clk_i
   , input                                          reset_i

   // Master BP Burst
   // ready-valid-and
   , input [in_msg_header_width_lp-1:0]      in_msg_header_i
   , input                                   in_msg_header_v_i
   , output logic                            in_msg_header_ready_and_o

   // ready-valid-and
   , input [in_data_width_p-1:0]             in_msg_data_i
   , input                                   in_msg_data_v_i
   , output logic                            in_msg_data_ready_and_o

   // Client BP Stream
   // ready-valid-and
   , output logic [out_msg_header_width_lp-1:0]     out_msg_header_o
   , output logic [out_data_width_p-1:0]            out_msg_data_o
   , output logic                                   out_msg_v_o
   , input                                          out_msg_ready_and_i
   , output logic                                   out_msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam burst_words_lp = out_data_width_p/in_data_width_p;
  localparam burst_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(burst_words_lp);

  //out_msg_v_o rely on both header and data
  bp_bedrock_in_msg_header_s header_lo;
  logic header_v_lo, header_yumi_li;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_msg_header_i)
     ,.ready_o(in_msg_header_ready_and_o)
     ,.v_i(in_msg_header_v_i)

     ,.data_o(header_lo)
     ,.v_o(header_v_lo)
     ,.yumi_i(out_msg_ready_and_i & out_msg_v_o) //TODO: yumi if the header is done
     );

  bp_bedrock_in_msg_header_s msg_header_cast_i;
  assign msg_header_cast_i = in_msg_header_i;
  wire has_data = payload_mask_p[msg_header_cast_i.msg_type]







endmodule


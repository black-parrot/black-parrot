
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_to_lite
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(in_data_width_p  )
   , parameter `BSG_INV_PARAM(out_data_width_p )
   , parameter `BSG_INV_PARAM(payload_width_p  )

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
   , input                                   in_msg_lock_i

   // Client BP Lite
   // ready-valid-and
   , output logic [out_msg_width_lp-1:0]     out_msg_o
   , output logic                            out_msg_v_o
   , input                                   out_msg_ready_and_i
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam stream_words_lp = out_data_width_p/in_data_width_p;
  localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  bp_bedrock_in_msg_header_s header_lo;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_msg_header_i)
     // We ready on ready/and failing on the stream after the first
     ,.v_i(in_msg_v_i)

     ,.data_o(header_lo)
     ,.yumi_i(out_msg_ready_and_i & out_msg_v_o)

     // We use the sipo ready/valid
     ,.ready_o(/* Unused */)
     ,.v_o(/* Unused */)
     );

  bp_bedrock_in_msg_header_s msg_header_cast_i;
  assign msg_header_cast_i = in_msg_header_i;
  wire has_data = payload_mask_p[msg_header_cast_i.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [data_len_width_lp-1:0] num_stream_cmds = has_data
    ? `BSG_MAX(((1'b1 << msg_header_cast_i.size) / in_data_bytes_lp), 1'b1)
    : 1'b1;
  logic [out_data_width_p-1:0] data_lo;
  logic data_ready_lo, len_ready_lo;
  bsg_serial_in_parallel_out_dynamic
   #(.width_p(in_data_width_p), .max_els_p(stream_words_lp))
   sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_msg_data_i)
     ,.len_i(num_stream_cmds-1'b1)
     ,.ready_o(in_msg_ready_and_o)
     ,.v_i(in_msg_v_i)

     ,.data_o(data_lo)
     ,.v_o(out_msg_v_o)
     ,.yumi_i(out_msg_ready_and_i & out_msg_v_o)

     // We rely on fifo ready signal
     ,.len_ready_o(/* Unused */)
     );

  wire unused = &{in_msg_lock_i};

  bp_bedrock_out_msg_s msg_cast_o;
  assign msg_cast_o = '{header: header_lo, data: data_lo};
  assign out_msg_o = msg_cast_o;

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p < out_data_width_p)
        else $error("Master data cannot be larger than client");
      assert (out_data_width_p % in_data_width_p == 0)
        else $error("Client data must be a multiple of master data");
    end

  always_ff @(negedge clk_i)
    begin
    //  if (in_msg_v_i)
    //    $display("[%t] Stream received: %p %x", $time, msg_header_cast_i, in_msg_data_i);

    //  if (out_msg_ready_and_i & out_msg_v_o)
    //    $display("[%t] Msg sent: %p", $time, msg_cast_o);
    end
  //synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bp_stream_to_lite)


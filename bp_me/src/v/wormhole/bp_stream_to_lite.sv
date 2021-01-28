
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_to_lite
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = "inv"
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

  bp_bedrock_in_msg_header_s in_msg_header_lo;
  logic [in_data_width_p-1:0] in_msg_data_lo;
  logic streaming_r, stream_clear;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_v_i)
    ,.data_i(in_msg_header_i)
    ,.data_o(in_msg_header_lo)
    );

  bsg_dff_en_bypass
   #(.width_p(in_data_width_p))
   data_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_v_i)
    ,.data_i(in_msg_data_i)
    ,.data_o(in_msg_data_lo)
    );

  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
    streaming_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_v_i)
    ,.clear_i(stream_clear)
    ,.data_o(streaming_r)
    );

  wire has_data = payload_mask_p[in_msg_header_lo.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [data_len_width_lp-1:0] num_stream_cmds = has_data
    ? `BSG_MAX(((1'b1 << in_msg_header_lo.size) / in_data_bytes_lp), 1'b1)
    : 1'b1;

  logic [out_data_width_p-1:0] sipo_data_lo;
  bsg_serial_in_parallel_out_passthrough_dynamic
   #(.width_p(in_data_width_p)
   ,.max_els_p(stream_words_lp))
   sipo_passthrough
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(in_msg_data_lo)
    ,.v_i(in_msg_v_i | streaming_r)
    ,.ready_and_o(in_msg_ready_and_o)
    ,.len_i(num_stream_cmds-1'b1)
   
    ,.data_o(sipo_data_lo)
    ,.v_o(out_msg_v_o)
    ,.ready_and_i(out_msg_ready_and_i)
    ,.first_o(/* unused */)
    );
  assign stream_clear = in_msg_last_i & out_msg_v_o & out_msg_ready_and_i;

  bp_bedrock_out_msg_s msg_cast_o;
  assign msg_cast_o = '{header: in_msg_header_lo, data: sipo_data_lo};
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
    //    $display("[%t] Stream received: %p %x", $time, in_msg_header_i, in_msg_data_i);

    //  if (out_msg_ready_and_i & out_msg_v_o)
    //    $display("[%t] Msg sent: %p", $time, msg_cast_o);
    end
  //synopsys translate_on

endmodule


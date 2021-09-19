/**
 *
 * Name:
 *   bp_me_stream_to_lite.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_to_lite
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

   // Input channel: BedRock Stream
   // ready-valid-and
   , input [in_msg_header_width_lp-1:0]      in_msg_header_i
   , input [in_data_width_p-1:0]             in_msg_data_i
   , input                                   in_msg_v_i
   , output logic                            in_msg_ready_and_o
   , input                                   in_msg_last_i

   // Output channel: BedRock Lite
   // ready-valid-and
   , output logic [out_msg_width_lp-1:0]     out_msg_o
   , output logic                            out_msg_v_o
   , input                                   out_msg_ready_and_i
   );

  // parameter checks
  if (in_data_width_p >= out_data_width_p)
    $fatal(0,"stream data cannot be larger than lite data");
  if (out_data_width_p % in_data_width_p != 0)
    $fatal(0,"lite data must be a multiple of stream data");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam stream_words_lp = out_data_width_p/in_data_width_p;
  localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  bp_bedrock_in_msg_header_s in_msg_header_lo;
  logic streaming_r, stream_clear;
  // Accept no header when in streaming state (We want to latch the header with critical address)
  bsg_dff_en_bypass
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_reg
    (.clk_i(clk_i)
    ,.en_i(~streaming_r)
    ,.data_i(in_msg_header_i)
    ,.data_o(in_msg_header_lo)
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
  assign stream_clear = in_msg_last_i & out_msg_v_o & out_msg_ready_and_i;

  // For messages that don't actually have data, the SIPO will still register
  // a single data word alongside the last signal and properly output the
  // out_msg_v_o signal.
  logic [out_data_width_p-1:0] sipo_data_lo;
  bsg_serial_in_parallel_out_passthrough_dynamic_last
   #(.width_p(in_data_width_p)
   ,.max_els_p(stream_words_lp))
   sipo_passthrough
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(in_msg_data_i)
    ,.v_i(in_msg_v_i)
    ,.ready_and_o(in_msg_ready_and_o)
    ,.last_i(in_msg_last_i)

    ,.data_o(sipo_data_lo)
    ,.v_o(out_msg_v_o)
    ,.ready_and_i(out_msg_ready_and_i)
    );

  bp_bedrock_out_msg_s msg_cast_o;
  assign msg_cast_o = '{header: in_msg_header_lo, data: sipo_data_lo};
  assign out_msg_o = msg_cast_o;

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
    //  if (in_msg_v_i)
    //    $display("[%t] Stream received: %p %x", $time, in_msg_header_i, in_msg_data_i);

    //  if (out_msg_ready_and_i & out_msg_v_o)
    //    $display("[%t] Msg sent: %p", $time, msg_cast_o);
    end
  //synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bp_stream_to_lite)


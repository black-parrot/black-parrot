/**
 *
 * Name:
 *   bp_me_lite_to_burst.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

// There is no header and data buffer within the lite_to_burst, therefore,
// in_msg_i and in_msg_v_i should be on hold until data burst is done.
// Therefore, the input site of this conversion module should be connected
// to a ready_valid_and link, but not a ready_then_valid link.
module bp_me_lite_to_burst
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(in_data_width_p  )
   , parameter `BSG_INV_PARAM(out_data_width_p )
   , parameter `BSG_INV_PARAM(payload_width_p  )

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter int payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input channel: BedRock Lite
   // ready-valid-and
   , input [in_msg_width_lp-1:0]                    in_msg_i
   , input                                          in_msg_v_i
   , output logic                                   in_msg_ready_and_o

   // Output channel: BedRock Burst
   // ready-valid-and
   , output logic [out_msg_header_width_lp-1:0]     out_msg_header_o
   , output logic                                   out_msg_header_v_o
   , input                                          out_msg_header_ready_and_i
   , output logic                                   out_msg_has_data_o

   // ready-valid-and
   , output logic [out_data_width_p-1:0]            out_msg_data_o
   , output logic                                   out_msg_data_v_o
   , input                                          out_msg_data_ready_and_i

   , output logic                                   out_msg_last_o
   );

  // parameter checks
  if (in_data_width_p < out_data_width_p)
    $fatal(0,"lite data cannot be smaller than burst data");
  if (in_data_width_p % out_data_width_p != 0)
    $fatal(0,"lite data must be a multiple of burst data");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);
  bp_bedrock_in_msg_s in_msg_cast_i;
  assign in_msg_cast_i = in_msg_i;

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam burst_words_lp = in_data_width_p/out_data_width_p;
  localparam burst_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  // This keeps out_msg_header_v_o low after the header is acked
  logic header_sent_r, head_sent_set, header_sent_clear;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
    header_sent_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.set_i(head_sent_set)
    ,.clear_i(header_sent_clear)
    ,.data_o(header_sent_r)
    );
  assign head_sent_set     = out_msg_header_ready_and_i & out_msg_header_v_o;   // set when the header is acked
  assign header_sent_clear = in_msg_v_i & in_msg_ready_and_o; // clear when the lite packet is acked

  assign out_msg_header_o   = in_msg_cast_i.header;
  assign out_msg_header_v_o = in_msg_v_i & ~header_sent_r;

  wire has_data = payload_mask_p[in_msg_cast_i.header.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(burst_words_lp);
  wire [data_len_width_lp-1:0] num_burst_cmds = `BSG_MAX(1, (1'b1 << in_msg_cast_i.header.size) / out_data_bytes_lp);

  assign out_msg_has_data_o = in_msg_v_i & ~header_sent_r & has_data;

  logic data_ready_and_lo;
  bsg_parallel_in_serial_out_passthrough_dynamic_last
   #(.width_p(out_data_width_p), .max_els_p(burst_words_lp))
   piso_passthrough
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.ready_and_o(data_ready_and_lo)
    ,.v_i(in_msg_v_i & has_data)
    ,.data_i(in_msg_cast_i.data)
    ,.len_i(num_burst_cmds - 1'b1)

    ,.data_o(out_msg_data_o)
    ,.v_o(out_msg_data_v_o)
    ,.ready_and_i(out_msg_data_ready_and_i)
    ,.first_o(/* unused */)
    ,.last_o(out_msg_last_o)
    );

  // If has data, data takes the control of the upstream handshake due to multi-cycle burst,
  // otherwise, simply pass through the header
  assign in_msg_ready_and_o = has_data ? data_ready_and_lo : out_msg_header_ready_and_i;

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      //if (in_msg_ready_and_o & in_msg_v_i)
      //  $display("[%t] Msg received: %p", $time, in_msg_cast_i);

      //if (out_msg_header_ready_and_i & out_msg_header_v_o)
      //  $display("[%t] Stream sent: %p %x CNT: %x", $time, msg_header_cast_o, out_msg_data_o, num_burst_cmds);
    end
  //synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bp_lite_to_burst)


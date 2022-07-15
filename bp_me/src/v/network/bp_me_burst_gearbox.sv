// Copyright (c) 2022, University of Washington
// Copyright and related rights are licensed under the BSD 3-Clause
// License (the “License”); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
// https://github.com/black-parrot/black-parrot/LICENSE.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed
// on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language
// governing permissions and limitations under the License.

/**
 *
 * Name:
 *   bp_me_burst_gearbox.sv
 *
 * Description:
 *   This module changes the width of a bedrock burst interface.
 *   The ratio of input to output data widths must be power of two, but either the input or output
 *   may be larger than the other.
 *
 *   If input data width > output data width, header and data cannot be processed at the same time
 *   since the message size from the header is required to control the number of output data beats.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_gearbox
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(in_data_width_p)
   , parameter `BSG_INV_PARAM(out_data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out)
   )
  (input                                     clk_i
   , input                                   reset_i

   // Input BedRock Burst
   , input [in_header_width_lp-1:0]          msg_header_i
   , input                                   msg_header_v_i
   , output logic                            msg_header_ready_and_o
   , input                                   msg_has_data_i

   // ready-valid-and
   , input [in_data_width_p-1:0]             msg_data_i
   , input                                   msg_data_v_i
   , output logic                            msg_data_ready_and_o
   , input                                   msg_last_i

   // Output BedRock Burst
   , output logic [out_header_width_lp-1:0]  msg_header_o
   , output logic                            msg_header_v_o
   , input                                   msg_header_ready_and_i
   , output logic                            msg_has_data_o

   // ready-valid-and
   , output logic [out_data_width_p-1:0]     msg_data_o
   , output logic                            msg_data_v_o
   , input                                   msg_data_ready_and_i
   , output logic                            msg_last_o
   );

  if (!(`BSG_IS_POW2(in_data_width_p)) || (in_data_width_p < 8))
    $error("In data width must be a power of two and at least 8 bits");
  if (!(`BSG_IS_POW2(out_data_width_p)) || (out_data_width_p < 8))
    $error("Out data width must be a power of two and at least 8 bits");
  if ((in_data_width_p > out_data_width_p) && !(`BSG_IS_POW2(in_data_width_p/out_data_width_p)))
    $error("In/Out must be a power of two");
  if ((out_data_width_p > in_data_width_p) && !(`BSG_IS_POW2(out_data_width_p/in_data_width_p)))
    $error("Out/In must be a power of two");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, out);
  `bp_cast_i(bp_bedrock_in_header_s, msg_header);
  `bp_cast_o(bp_bedrock_out_header_s, msg_header);

  // header is passed through unmodified
  assign msg_header_cast_o = msg_header_cast_i;
  assign msg_header_v_o = msg_header_v_i;
  assign msg_header_ready_and_o = msg_header_ready_and_i;
  assign msg_has_data_o = msg_has_data_i;

  // simple 1-bit FSM used by narrow (in > out) conversion
  enum logic {e_hdr, e_data} state_n, state_r;
  wire is_hdr = (state_r == e_hdr);
  wire is_data = (state_r == e_data);
  wire e_hdr_to_e_data = (msg_header_v_o & msg_header_ready_and_i & msg_has_data_o);
  wire e_data_to_e_hdr = (msg_data_v_o & msg_data_ready_and_i & msg_last_o);

  always_comb begin
    case (state_r)
      e_hdr: state_n =  (e_hdr_to_e_data) ? e_data : state_r;
      e_data: state_n = (e_data_to_e_hdr) ? e_hdr : state_r;
      default: state_n = e_hdr;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (reset_i)
      state_r <= e_hdr;
    else
      state_r <= state_n;
  end

  // gearbox data
  if (in_data_width_p == out_data_width_p) begin : passthrough
    assign msg_data_o = msg_data_i;
    assign msg_data_v_o = msg_data_v_i;
    assign msg_last_o = msg_last_i;
    assign msg_data_ready_and_o = msg_data_ready_and_i;
  end
  else if (in_data_width_p > out_data_width_p) begin : narrow
    // if input message size is < in data width, the full number of serial output beats from
    // the PISO are not required. The number of output beats is equal to CDIV(msg size, out width),
    // and is tracked by a counter to dynamically control the PISO.

    // maximum number of output beats for max sized input message
    localparam max_len_lp = `BSG_CDIV((1<<e_bedrock_msg_size_128)*8,out_data_width_p);
    localparam len_width_lp = `BSG_SAFE_CLOG2(max_len_lp);

    // compute zero-based output data length
    logic [len_width_lp-1:0] out_data_len;
    bp_bedrock_size_to_len
      #(.len_width_p(len_width_lp)
        ,.beat_width_p(out_data_width_p)
        )
      size_to_len
       (.size_i(msg_header_cast_i.size)
        ,.len_o(out_data_len)
        );

    // counter tracking number of output data beats to send
    // capture on valid header
    logic [len_width_lp-1:0] out_data_cnt;
    wire out_data_sent = (out_data_cnt == '0);
    bsg_counter_set_down
     #(.width_p(len_width_lp)
       ,.init_val_p('0)
       ,.set_and_down_exclusive_p(0)
       )
     data_out_counter
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.set_i(is_hdr & msg_header_v_i & msg_header_ready_and_o)
       ,.val_i(out_data_len)
       ,.down_i(~out_data_sent & msg_data_v_o & msg_data_ready_and_i)
       ,.count_r_o(out_data_cnt)
       );

    // max number output beats per input beat
    localparam max_els_lp = in_data_width_p / out_data_width_p;
    localparam lg_max_els_lp = `BSG_SAFE_CLOG2(max_els_lp);
    // zero-based length of serial outs per full parallel in
    localparam [lg_max_els_lp-1:0] piso_full_len_lp = max_els_lp - 1;
    // PISO signals
    logic piso_last_lo;
    logic [lg_max_els_lp-1:0] piso_len_li;
    assign piso_len_li = (out_data_cnt >= piso_full_len_lp)
                         ? piso_full_len_lp
                         : lg_max_els_lp'(out_data_cnt);

    wire msg_data_v_li = is_data & msg_data_v_i;
    logic msg_data_ready_and_lo;
    assign msg_data_ready_and_o = is_data & msg_data_ready_and_lo;
    bsg_parallel_in_serial_out_passthrough_dynamic_last
     #(.width_p(out_data_width_p)
       ,.max_els_p(max_els_lp)
       )
     data_piso
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.data_i(msg_data_i)
       ,.v_i(msg_data_v_li)
       ,.ready_and_o(msg_data_ready_and_lo)

       ,.data_o(msg_data_o)
       ,.v_o(msg_data_v_o)
       ,.ready_and_i(msg_data_ready_and_i)

       // must be presented when (v_o & ready_and_i)
       ,.len_i(piso_len_li)
       ,.last_o(piso_last_lo)
       );
    assign msg_last_o = msg_last_i & piso_last_lo;

  end
  else begin : wide
    // if input message size < out data width, then SIPO will not completely fill,
    // and the SIPO uses the last signal to send the output early
    localparam max_els_lp = out_data_width_p / in_data_width_p;
    bsg_serial_in_parallel_out_passthrough_last
      #(.width_p(in_data_width_p), .max_els_p(max_els_lp))
      data_sipo
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.data_i(msg_data_i)
        ,.v_i(msg_data_v_i)
        ,.ready_and_o(msg_data_ready_and_o)
        ,.last_i(msg_data_v_i & msg_last_i)

        ,.data_o(msg_data_o)
        ,.v_o(msg_data_v_o)
        ,.ready_and_i(msg_data_ready_and_i)
        );
    assign msg_last_o = msg_last_i;
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_gearbox)


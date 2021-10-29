/**
 *
 * Name:
 *   bp_me_stream_gearbox.sv
 *
 * Description:
 *   This module changes the width of a bedrock stream. Ratio must be POT between the two
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_gearbox
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(in_data_width_p)
   , parameter `BSG_INV_PARAM(out_data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Stream
   , input [in_header_width_lp-1:0]                 msg_header_i
   , input [in_data_width_p-1:0]                    msg_data_i
   , input                                          msg_v_i
   , output logic                                   msg_ready_and_o
   , input                                          msg_last_i

   // Output BedRock Stream
   , input [out_header_width_lp-1:0]                msg_header_o
   , output logic [out_data_width_p-1:0]            msg_data_o
   , output logic                                   msg_v_o
   , input                                          msg_ready_and_i
   , output logic                                   msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);
  `bp_cast_i(bp_bedrock_in_header_s, msg_header);
  `bp_cast_o(bp_bedrock_out_header_s, msg_header);

  localparam narrow_ratio_lp = in_data_width_p / out_data_width_p;
  localparam wide_ratio_lp = out_data_width_p / in_data_width_p;
  if (narrow_ratio_lp >= 1)
    begin : narrow
      bsg_parallel_in_serial_out_passthrough
       #(.width_p(out_data_width_p), .els_p(narrow_ratio_lp))
       pisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_data_i)
         ,.v_i(msg_v_i)
         ,.ready_and_o(msg_ready_and_o)

         ,.data_o(msg_data_o)
         ,.v_o(msg_v_o)
         ,.ready_and_i(msg_ready_and_i)
         );
      assign msg_last_o = msg_last_i & msg_v_o;
    end
  else
    begin : wide
      bsg_serial_in_parallel_out_passthrough
       #(.width_p(in_data_width_p), .els_p(wide_ratio_lp))
       sisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_data_i)
         ,.v_i(msg_v_i)
         ,.ready_and_o(msg_ready_and_o)

         ,.data_o(msg_data_o)
         ,.v_o(msg_v_o)
         ,.ready_and_i(msg_ready_and_i)
         );
      assign msg_last_o = msg_last_i & msg_v_o;
    end

  localparam out_words_lp = `BSG_MAX(narrow_ratio_lp, wide_ratio_lp);
  localparam cnt_width_lp = `BSG_SAFE_CLOG2(out_words_lp);
  localparam offset_width_lp = `BSG_SAFE_CLOG2(out_data_width_p>>3);

  logic [cnt_width_lp-1:0] cnt;
  bsg_counter_clear_up
   #(.max_val_p(out_words_lp), .init_val_p('0))
   counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(msg_v_o & msg_ready_and_i & msg_last_o)
     ,.up_i(msg_v_o & msg_ready_i & ~msg_last_o)
     ,.count_o(cnt)
     );
  wire [cnt_width_lp-1:0] wrap = cnt + msg_header_cast_i.addr[offset_width_lp+:cnt_width_lp];

  always_comb
    begin
      msg_header_cast_o = msg_header_cast_i;
      msg_header_cast_o.addr = {msg_header_cast_i.addr[paddr_width_p-1:offset_width_lp+cnt_width_lp]
                                ,wrap
                                ,msg_header_cast_i.addr[0+:offset_width_lp]
                                };
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_gearbox)


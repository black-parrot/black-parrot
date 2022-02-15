/**
 *
 * Name:
 *   bp_me_burst_gearbox.sv
 *
 * Description:
 *   This module changes the width of a bedrock burst. Ratio must be POT between the two
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

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, out);
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
         ,.v_i(msg_data_v_i)
         ,.ready_and_o(msg_data_ready_and_o)

         ,.data_o(msg_data_o)
         ,.v_o(msg_data_v_o)
         ,.ready_and_i(msg_data_ready_and_i)
         );
      assign msg_last_o = msg_last_i & msg_data_v_o;
    end
  else
    begin : wide
      bsg_serial_in_parallel_out_passthrough
       #(.width_p(in_data_width_p), .els_p(wide_ratio_lp))
       sisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_data_i)
         ,.v_i(msg_data_v_i)
         ,.ready_and_o(msg_data_ready_and_o)

         ,.data_o(msg_data_o)
         ,.v_o(msg_data_v_o)
         ,.ready_and_i(msg_data_ready_and_i)
         );
      assign msg_last_o = msg_last_i & msg_data_v_o;
    end

  assign msg_header_cast_o = msg_header_i;
  assign msg_header_v_o = msg_header_v_i;
  assign msg_header_ready_and_o = msg_header_ready_and_i;
  assign msg_has_data_o = msg_has_data_i;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_gearbox)


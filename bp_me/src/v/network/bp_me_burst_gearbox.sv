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

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Burst
   , input [in_header_width_lp-1:0]          in_msg_header_i
   , input                                   in_msg_header_v_i
   , output logic                            in_msg_header_ready_and_o
   , input                                   in_msg_has_data_i

   // ready-valid-and
   , input [in_data_width_p-1:0]             in_msg_data_i
   , input                                   in_msg_data_v_i
   , output logic                            in_msg_data_ready_and_o
   , input                                   in_msg_last_i

   // Input BedRock Burst
   , input [in_header_width_lp-1:0]          in_msg_header_i
   , input                                   in_msg_header_v_i
   , output logic                            in_msg_header_ready_and_o
   , input                                   in_msg_has_data_i

   // ready-valid-and
   , input [in_data_width_p-1:0]             in_msg_data_i
   , input                                   in_msg_data_v_i
   , output logic                            in_msg_data_ready_and_o
   , input                                   in_msg_last_i
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);
  `bp_cast_i(bp_bedrock_in_header_s, msg_header);
  `bp_cast_o(bp_bedrock_out_header_s, msg_header);

  localparam narrow_ratio_lp = in_data_width_p / out_data_width_p;
  localparam wide_ratio_lp = out_data_width_p / in_data_width_p;
  if (narrow_ratio_lp >= 1)
    begin : narrow
    end
  else
    begin : wide
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_gearbox)


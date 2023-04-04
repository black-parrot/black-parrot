/**
 *
 * Name:
 *   bp_me_burst_bidi_lite.sv
 *
 * Description:
 *   Bi-directional Burst-Lite conversion. This module wraps the unidirectional burst-lite
 *   converters into one module, as a common paradigm is to use this in front of a Lite
 *   endpoint connected to a Burst network.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_bidi_lite
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(block_width_p)

   // Bitmask which determines which INPUT message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter burst_payload_mask_p = 0
   , parameter lite_payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, bp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Burst
   // ready-valid-and
   , input [bp_header_width_lp-1:0]                 burst_header_i
   , input                                          burst_header_v_i
   , output logic                                   burst_header_ready_and_o
   , input                                          burst_has_data_i

   // ready-valid-and
   , input [data_width_p-1:0]                       burst_data_i
   , input                                          burst_data_v_i
   , output logic                                   burst_data_ready_and_o
   , input                                          burst_last_i

   // Input BedRock Lite
   // ready-valid-and
   , input [bp_header_width_lp-1:0]                 lite_header_i
   , input [data_width_p-1:0]                       lite_data_i
   , input                                          lite_v_i
   , output logic                                   lite_ready_and_o

   // Output BedRock Burst
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          burst_header_o
   , output logic                                   burst_header_v_o
   , input                                          burst_header_ready_and_i
   , output logic                                   burst_has_data_o

   // ready-valid-and
   , output logic [data_width_p-1:0]                burst_data_o
   , output logic                                   burst_data_v_o
   , input                                          burst_data_ready_and_i
   , output logic                                   burst_last_o

   // Output BedRock Lite
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          lite_header_o
   , output logic [data_width_p-1:0]                lite_data_o
   , output logic                                   lite_v_o
   , input                                          lite_ready_and_i
   );

  bp_me_burst_to_lite
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_mask_p(burst_payload_mask_p)
     )
   burst_to_lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.in_msg_header_i(burst_header_i)
     ,.in_msg_header_v_i(burst_header_v_i)
     ,.in_msg_header_ready_and_o(burst_header_ready_and_o)
     ,.in_msg_has_data_i(burst_has_data_i)
     ,.in_msg_data_i(burst_data_i)
     ,.in_msg_data_v_i(burst_data_v_i)
     ,.in_msg_data_ready_and_o(burst_data_ready_and_o)
     ,.in_msg_last_i(burst_last_i)
     ,.out_msg_header_o(lite_header_o)
     ,.out_msg_data_o(lite_data_o)
     ,.out_msg_v_o(lite_v_o)
     ,.out_msg_ready_and_i(lite_ready_and_i)
     );

  bp_me_lite_to_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.payload_mask_p(lite_payload_mask_p)
     )
   lite_to_burst
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.in_msg_header_i(lite_header_i)
     ,.in_msg_data_i(lite_data_i)
     ,.in_msg_v_i(lite_v_i)
     ,.in_msg_ready_and_o(lite_ready_and_o)
     ,.out_msg_header_o(burst_header_o)
     ,.out_msg_header_v_o(burst_header_v_o)
     ,.out_msg_header_ready_and_i(burst_header_ready_and_i)
     ,.out_msg_has_data_o(burst_has_data_o)
     ,.out_msg_data_o(burst_data_o)
     ,.out_msg_data_v_o(burst_data_v_o)
     ,.out_msg_data_ready_and_i(burst_data_ready_and_i)
     ,.out_msg_last_o(burst_last_o)
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_bidi_lite)


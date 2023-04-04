/**
 *
 * Name:
 *   bp_me_burst_to_lite.sv
 *
 * Description:
 *   Converts BedRock Burst to Lite.
 *
 *   This "cracks" the BedRock Burst message into multiple BedRock Lite beats.
 *   The current implementation should only receive Burst messages that generate
 *   a single Lite message.
 *
 *   BedRock Burst input implementation is minimal and accepts header before accepting data.
 *   Data is not accepted in same cycle as header to avoid a dependence between in_msg_header_v_i
 *   and in_msg_data_ready_and_o.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_to_lite
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(block_width_p)

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, bp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Burst
   // ready-valid-and
   , input [bp_header_width_lp-1:0]                 in_msg_header_i
   , input                                          in_msg_header_v_i
   , output logic                                   in_msg_header_ready_and_o
   , input                                          in_msg_has_data_i

   // ready-valid-and
   , input [data_width_p-1:0]                       in_msg_data_i
   , input                                          in_msg_data_v_i
   , output logic                                   in_msg_data_ready_and_o
   , input                                          in_msg_last_i

   // Output BedRock Stream
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          out_msg_header_o
   , output logic [data_width_p-1:0]                out_msg_data_o
   , output logic                                   out_msg_v_o
   , input                                          out_msg_ready_and_i
   );

  // TODO:
  // buffer header
  // burst pump in to compute header for each output beat and align with data

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_to_lite)


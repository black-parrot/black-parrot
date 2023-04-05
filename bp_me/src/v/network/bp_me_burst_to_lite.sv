/**
 *
 * Name:
 *   bp_me_burst_to_lite.sv
 *
 * Description:
 *   Converts BedRock Burst to Lite using bp_me_burst_pump_in. Multi-beat input messages, i.e.,
 *   those with message size greater than data_width_p are transmitted as multiple independent
 *   beats on the Lite output interface. The Lite client will respond to each Lite beat
 *   individually. This may lead to more responses than expected for the Burst client, and
 *   this module may need to be wrapped with additional logic to reassemble appropriate Burst
 *   protocol responses.
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

   // Output BedRock Lite
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          out_msg_header_o
   , output logic [data_width_p-1:0]                out_msg_data_o
   , output logic                                   out_msg_v_o
   , input                                          out_msg_ready_and_i
   );

  if (data_width_p != 64) $error("Burst-to-Lite data width must be 64-bits");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, msg);
  `bp_cast_o(bp_bedrock_msg_header_s, out_msg_header);

  bp_bedrock_msg_header_s fsm_header_li;
  logic [l2_data_width_p-1:0] fsm_data_li;
  logic fsm_v_li, fsm_yumi_lo;
  logic [paddr_width_p-1:0] fsm_addr_li;

  bp_me_burst_pump_in
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(data_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(payload_width_p)
     ,.msg_stream_mask_p(payload_mask_p)
     ,.header_els_p(2)
     )
    burst_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(in_msg_header_i)
     ,.msg_header_v_i(in_msg_header_v_i)
     ,.msg_header_ready_and_o(in_msg_header_ready_and_o)
     ,.msg_has_data_i(in_msg_has_data_i)
     ,.msg_data_i(in_msg_data_i)
     ,.msg_data_v_i(in_msg_data_v_i)
     ,.msg_data_ready_and_o(in_msg_data_ready_and_o)
     ,.msg_last_i(in_msg_last_i)
     ,.fsm_header_o(fsm_header_li)
     ,.fsm_addr_o(fsm_addr_li)
     ,.fsm_data_o(fsm_data_li)
     ,.fsm_v_o(fsm_v_li)
     ,.fsm_yumi_i(fsm_yumi_lo)
     ,.fsm_cnt_o()
     ,.fsm_new_o()
     ,.fsm_last_o()
     );

  localparam logic [2:0] data_width_size_lp = `BSG_SAFE_CLOG2(data_width_p/8);

  always_comb begin
    out_msg_header_cast_o = fsm_header_li;
    // use the wrapping address for each beat
    out_msg_header_cast_o.addr = fsm_addr_li;
    // clamp size at number of bytes in data_width_p
    out_msg_header_cast_o.size = `BSG_MIN(out_msg_header_cast_o.size, bp_bedrock_msg_size_e'(data_width_size_lp));
    out_msg_data_o = fsm_data_li;
    out_msg_v_o = fsm_v_li;
    fsm_yumi_lo = out_msg_v_o & out_msg_ready_and_i;
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_to_lite)


/**
 *
 * Name:
 *   bp_me_burst_to_stream.sv
 *
 * Description:
 *   Converts BedRock Burst to Stream
 *
 *   BedRock Burst input implementation is minimal and accepts header before accepting data.
 *   Data is not accepted in same cycle as header to avoid a dependence between in_msg_header_v_i
 *   and in_msg_data_ready_and_o.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_to_stream
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
   , input                                          in_msg_has_data_i
   , output logic                                   in_msg_header_ready_and_o

   // ready-valid-and
   , input [data_width_p-1:0]                       in_msg_data_i
   , input                                          in_msg_data_v_i
   , input                                          in_msg_last_i
   , output logic                                   in_msg_data_ready_and_o

   // Output BedRock Stream
   // ready-valid-and
   , output logic [bp_header_width_lp-1:0]          out_msg_header_o
   , output logic [data_width_p-1:0]                out_msg_data_o
   , output logic                                   out_msg_v_o
   , input                                          out_msg_ready_and_i
   , output logic                                   out_msg_last_o
   );

  // Stream pump uses payload mask and size from header instead of last signal
  wire unused = in_msg_last_i;

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, bp);

  bp_bedrock_bp_header_s msg_header_li;
  logic msg_has_data_li;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_bedrock_bp_header_s)+1))
   header_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_header_ready_and_o & in_msg_header_v_i)
    ,.data_i({in_msg_has_data_i, in_msg_header_i})
    ,.data_o({msg_has_data_li, msg_header_li})
    );

  logic header_v_r, header_clear, header_v_lo;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
   header_v_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_header_v_i)
    ,.clear_i(header_clear)
    ,.data_o(header_v_r)
    );
  assign header_v_lo  = in_msg_header_v_i | header_v_r;
  assign header_clear = out_msg_ready_and_i & out_msg_v_o & out_msg_last_o;
  // Accept new header only if there is no header currently buffered
  assign in_msg_header_ready_and_o = ~header_v_r;

  // Stream pump to handle all the details of properly forming the output BedRock stream message
  logic fsm_ready_and_lo, fsm_v_li;
  bp_me_stream_pump_out
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(data_width_p)
      ,.block_width_p(block_width_p)
      ,.payload_width_p(payload_width_p)
      ,.msg_stream_mask_p(payload_mask_p)
      )
     stream_pump_out
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.msg_header_o(out_msg_header_o)
       ,.msg_data_o(out_msg_data_o)
       ,.msg_v_o(out_msg_v_o)
       ,.msg_last_o(out_msg_last_o)
       ,.msg_ready_and_i(out_msg_ready_and_i)
       ,.fsm_header_i(msg_header_li)
       ,.fsm_addr_o()
       ,.fsm_data_i(in_msg_data_i)
       ,.fsm_v_i(fsm_v_li)
       ,.fsm_ready_and_o(fsm_ready_and_lo)
       ,.fsm_new_o()
       ,.fsm_cnt_o()
       ,.fsm_last_o()
       );

  // Stream pump needs valid header and, if required, data in same cycle
  assign fsm_v_li = header_v_r & (~msg_has_data_li | in_msg_data_v_i);
  // Accept data cycle after header arrives, but only if current message has data.
  // This module does not support concurrent burst messages, so data must only be accepted
  // if the buffered header indicates that data exists for the message.
  assign in_msg_data_ready_and_o = header_v_r & msg_has_data_li & fsm_ready_and_lo;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_to_stream)


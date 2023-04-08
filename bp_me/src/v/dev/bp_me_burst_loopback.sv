/**
 *
 * Name:
 *   bp_me_burst_loopback.sv
 *
 * Description:
 *   This module is an active tie-off. That is, requests to this module will return the header
 *   with a zero payload. This is useful to not stall the network in the case of an erroneous
 *   address, or prevent deadlock at network boundaries
 *
 *   The loopback is implemented using two burst pumps connected to each other.
 *   The input pump is responsible for the message beat conversion.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_loopback
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    , parameter `BSG_INV_PARAM(block_width_p)
    , parameter `BSG_INV_PARAM(payload_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, msg)

    // Bitmask which determines which message types have a data payload
    // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
    , parameter in_msg_payload_mask_p = 0
    , parameter out_msg_payload_mask_p = 0
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [msg_header_width_lp-1:0]                in_msg_header_i
    , input                                          in_msg_header_v_i
    , output logic                                   in_msg_header_ready_and_o
    , input logic                                    in_msg_has_data_i
    , input [data_width_p-1:0]                       in_msg_data_i
    , input                                          in_msg_data_v_i
    , output logic                                   in_msg_data_ready_and_o
    , input logic                                    in_msg_last_i

    , output logic [msg_header_width_lp-1:0]         out_msg_header_o
    , output logic                                   out_msg_header_v_o
    , input                                          out_msg_header_ready_and_i
    , output logic                                   out_msg_has_data_o
    , output logic [data_width_p-1:0]                out_msg_data_o
    , output logic                                   out_msg_data_v_o
    , input                                          out_msg_data_ready_and_i
    , output logic                                   out_msg_last_o
    );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, msg);

  bp_bedrock_msg_header_s fsm_header_li;
  logic fsm_v_li, fsm_yumi_lo;
  wire [data_width_p-1:0] fsm_data_li = '0;

  bp_me_burst_pump_in
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(data_width_p)
      ,.block_width_p(block_width_p)
      ,.payload_width_p(payload_width_p)
      ,.msg_stream_mask_p(in_msg_payload_mask_p)
      ,.fsm_stream_mask_p(out_msg_payload_mask_p)
      ,.header_els_p(2)
      ,.data_els_p(2)
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
      ,.fsm_cnt_o()
      ,.fsm_addr_o()
      ,.fsm_data_o()
      ,.fsm_v_o(fsm_v_li)
      ,.fsm_yumi_i(fsm_yumi_lo)
      ,.fsm_new_o()
      ,.fsm_last_o()
      );

  bp_me_burst_pump_out
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(data_width_p)
      ,.block_width_p(block_width_p)
      ,.payload_width_p(payload_width_p)
      ,.msg_stream_mask_p(out_msg_payload_mask_p)
      ,.fsm_stream_mask_p(out_msg_payload_mask_p)
      )
    burst_pump_out
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_o(out_msg_header_o)
      ,.msg_header_v_o(out_msg_header_v_o)
      ,.msg_header_ready_and_i(out_msg_header_ready_and_i)
      ,.msg_has_data_o(out_msg_has_data_o)
      ,.msg_data_o(out_msg_data_o)
      ,.msg_data_v_o(out_msg_data_v_o)
      ,.msg_data_ready_and_i(out_msg_data_ready_and_i)
      ,.msg_last_o(out_msg_last_o)
      ,.fsm_header_i(fsm_header_li)
      ,.fsm_cnt_o()
      ,.fsm_addr_o()
      ,.fsm_data_i(fsm_data_li)
      ,.fsm_v_i(fsm_v_li)
      ,.fsm_yumi_o(fsm_yumi_lo)
      ,.fsm_new_o()
      ,.fsm_last_o()
      );

endmodule


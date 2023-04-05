/**
 *
 * Name:
 *   bp_me_lite_loopback.sv
 *
 * Description:
 *   This module is an active tie-off. That is, requests to this module will return the header
 *   with a zero payload. This is useful to not stall the network in the case of an erroneous
 *   address, or prevent deadlock at network boundaries
 *
 */
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_lite_loopback
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    , parameter `BSG_INV_PARAM(payload_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, bp)
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [bp_header_width_lp-1:0]                 in_msg_header_i
    , input [data_width_p-1:0]                       in_msg_data_i
    , input                                          in_msg_v_i
    , output logic                                   in_msg_ready_and_o

    , output logic [bp_header_width_lp-1:0]          out_msg_header_o
    , output logic [data_width_p-1:0]                out_msg_data_o
    , output logic                                   out_msg_v_o
    , input                                          out_msg_ready_and_i
    );

  wire unused = &{in_msg_data_i};
  assign out_msg_data_o = '0;

  bsg_one_fifo
   #(.width_p(bp_header_width_lp))
   loopback_buffer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_msg_header_i)
     ,.v_i(in_msg_v_i)
     ,.ready_o(in_msg_ready_and_o)

     ,.data_o(out_msg_header_o)
     ,.v_o(out_msg_v_o)
     ,.yumi_i(out_msg_ready_and_i & out_msg_v_o)
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_lite_loopback)

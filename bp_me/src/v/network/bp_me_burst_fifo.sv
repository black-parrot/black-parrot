/*
 * Name:
 *  bp_me_burst_fifo.sv
 *
 * Description:
 *  This module buffers a BP BedRock Burst interface, and converts the handshake
 *  from ready&valid to valid->yumi for demanding consumers.
 *
 *  2 or more elements per FIFO is required to avoid bubbles.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_fifo
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  , parameter `BSG_INV_PARAM(payload_width_p)
  , parameter `BSG_INV_PARAM(data_width_p)
  , parameter header_els_p = 2
  , parameter data_els_p = 2
  `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, msg)
  )
 (
  input                                        clk_i
  , input                                      reset_i

  , input [msg_header_width_lp-1:0]            msg_header_i
  , input                                      msg_header_v_i
  , input                                      msg_has_data_i
  , output logic                               msg_header_ready_and_o
  , input [data_width_p-1:0]                   msg_data_i
  , input                                      msg_data_v_i
  , input                                      msg_last_i
  , output logic                               msg_data_ready_and_o

  , output logic [msg_header_width_lp-1:0]     msg_header_o
  , output logic                               msg_header_v_o
  , output logic                               msg_has_data_o
  , input                                      msg_header_yumi_i
  , output logic [data_width_p-1:0]            msg_data_o
  , output logic                               msg_data_v_o
  , output logic                               msg_last_o
  , input                                      msg_data_yumi_i
  );

  if (header_els_p < 1 || data_els_p < 1)
    $error("Header and Data buffer size must be non-zero");
  if (data_width_p < 1)
    $error("Data width must be non-zero");
  if (payload_width_p < 1)
    $error("Payload width must be non-zero");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, msg);

  bsg_fifo_1r1w_small
   #(.width_p(msg_header_width_lp+1)
     ,.els_p(header_els_p)
     )
    header_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({msg_has_data_i, msg_header_i})
      ,.v_i(msg_header_v_i)
      ,.ready_o(msg_header_ready_and_o)
      ,.data_o({msg_has_data_o, msg_header_o})
      ,.v_o(msg_header_v_o)
      ,.yumi_i(msg_header_yumi_i)
      );

  bsg_fifo_1r1w_small
   #(.width_p(data_width_p+1)
     ,.els_p(data_els_p)
     )
    data_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({msg_last_i, msg_data_i})
      ,.v_i(msg_data_v_i)
      ,.ready_o(msg_data_ready_and_o)
      ,.data_o({msg_last_o, msg_data_o})
      ,.v_o(msg_data_v_o)
      ,.yumi_i(msg_data_yumi_i)
      );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_to_axil)

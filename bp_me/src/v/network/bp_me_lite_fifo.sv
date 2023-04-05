/*
 * Name:
 *  bp_me_lite_fifo.sv
 *
 * Description:
 *  This module buffers a BP BedRock Lite interface, and converts the handshake
 *  from ready&valid to valid->yumi for demanding consumers.
 *
 */

`include "bsg_defines.v"

module bp_me_lite_fifo
 #(parameter `BSG_INV_PARAM(els_p)
   , parameter `BSG_INV_PARAM(header_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   )
 (
  input                                        clk_i
  , input                                      reset_i

  , input [header_width_p-1:0]                 msg_header_i
  , input [data_width_p-1:0]                   msg_data_i
  , input                                      msg_v_i
  , output logic                               msg_ready_and_o

  , output logic [header_width_p-1:0]          msg_header_o
  , output logic [data_width_p-1:0]            msg_data_o
  , output logic                               msg_v_o
  , input                                      msg_yumi_i
  );

  if (els_p < 1)
    $error("Buffer size must be non-zero");
  if (data_width_p < 1)
    $error("Data width must be non-zero");
  if (header_width_p < 1)
    $error("Header width must be non-zero");

  bsg_fifo_1r1w_small
   #(.width_p(header_width_p+data_width_p)
     ,.els_p(els_p)
     )
    header_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({msg_data_i, msg_header_i})
      ,.v_i(msg_v_i)
      ,.ready_o(msg_ready_and_o)
      ,.data_o({msg_data_o, msg_header_o})
      ,.v_o(msg_v_o)
      ,.yumi_i(msg_yumi_i)
      );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_lite_fifo)


`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_pump
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(in_data_width_p)
   , parameter `BSG_INV_PARAM(in_payload_width_p)

   , parameter `BSG_INV_PARAM(in_msg_stream_mask_p)
   , parameter `BSG_INV_PARAM(in_fsm_stream_mask_p)

   , parameter `BSG_INV_PARAM(out_data_width_p)
   , parameter `BSG_INV_PARAM(out_payload_width_p)

   , parameter `BSG_INV_PARAM(out_msg_stream_mask_p)
   , parameter `BSG_INV_PARAM(out_fsm_stream_mask_p)

   , parameter `BSG_INV_PARAM(metadata_fifo_width_p)
   , parameter `BSG_INV_PARAM(metadata_fifo_els_p)

   `declare_bp_bedrock_generic_if_width(paddr_width_p, in_payload_width_p, in)
   `declare_bp_bedrock_generic_if_width(paddr_width_p, out_payload_width_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input
   , input [in_header_width_lp-1:0]                 in_msg_header_i
   , input [bedrock_fill_width_p-1:0]               in_msg_data_i
   , input                                          in_msg_v_i
   , output logic                                   in_msg_ready_and_o

   , output logic [in_header_width_lp-1:0]          in_fsm_header_o
   , output logic [in_data_width_p-1:0]             in_fsm_data_o
   , output logic                                   in_fsm_v_o
   , input                                          in_fsm_yumi_i

   , input [metadata_fifo_width_p-1:0]              in_fsm_metadata_i
   , output logic [paddr_width_p-1:0]               in_fsm_addr_o
   , output logic                                   in_fsm_new_o
   , output logic                                   in_fsm_critical_o
   , output logic                                   in_fsm_last_o

   , output logic [out_header_width_lp-1:0]         out_msg_header_o
   , output logic [bedrock_fill_width_p-1:0]        out_msg_data_o
   , output logic                                   out_msg_v_o
   , input                                          out_msg_ready_and_i

   , input [out_header_width_lp-1:0]                out_fsm_header_i
   , input [out_data_width_p-1:0]                   out_fsm_data_i
   , input                                          out_fsm_v_i
   , output logic                                   out_fsm_ready_then_o

   , output logic [metadata_fifo_width_p-1:0]       out_fsm_metadata_o
   , output logic [paddr_width_p-1:0]               out_fsm_addr_o
   , output logic                                   out_fsm_new_o
   , output logic                                   out_fsm_last_o
   , output logic                                   out_fsm_critical_o
   );

  logic in_fsm_v_lo, in_fsm_yumi_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(in_data_width_p)
     ,.payload_width_p(in_payload_width_p)
     ,.msg_stream_mask_p(in_msg_stream_mask_p)
     ,.fsm_stream_mask_p(in_fsm_stream_mask_p)
     )
   in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(in_msg_header_i)
     ,.msg_data_i(in_msg_data_i)
     ,.msg_v_i(in_msg_v_i)
     ,.msg_ready_and_o(in_msg_ready_and_o)

     ,.fsm_header_o(in_fsm_header_o)
     ,.fsm_data_o(in_fsm_data_o)
     ,.fsm_v_o(in_fsm_v_lo)
     ,.fsm_yumi_i(in_fsm_yumi_li)
     ,.fsm_addr_o(in_fsm_addr_o)
     ,.fsm_new_o(in_fsm_new_o)
     ,.fsm_critical_o(in_fsm_critical_o)
     ,.fsm_last_o(in_fsm_last_o)
     );

  logic out_fsm_ready_then_lo, out_fsm_v_li;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(out_data_width_p)
     ,.payload_width_p(out_payload_width_p)
     ,.msg_stream_mask_p(out_msg_stream_mask_p)
     ,.fsm_stream_mask_p(out_fsm_stream_mask_p)
     )
   out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(out_msg_header_o)
     ,.msg_data_o(out_msg_data_o)
     ,.msg_v_o(out_msg_v_o)
     ,.msg_ready_and_i(out_msg_ready_and_i)

     ,.fsm_header_i(out_fsm_header_i)
     ,.fsm_data_i(out_fsm_data_i)
     ,.fsm_v_i(out_fsm_v_li)
     ,.fsm_ready_then_o(out_fsm_ready_then_lo)
     ,.fsm_addr_o(out_fsm_addr_o)
     ,.fsm_new_o(out_fsm_new_o)
     ,.fsm_critical_o(out_fsm_critical_o)
     ,.fsm_last_o(out_fsm_last_o)
     );

  logic [metadata_fifo_width_p-1:0] stream_fifo_data_li;
  logic stream_fifo_ready_then_lo, stream_fifo_v_li;
  logic [metadata_fifo_width_p-1:0] stream_fifo_data_lo;
  logic stream_fifo_v_lo, stream_fifo_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p(metadata_fifo_width_p)
     ,.els_p(metadata_fifo_els_p)
     ,.ready_THEN_valid_p(1)
     )
   stream_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(stream_fifo_data_li)
     ,.v_i(stream_fifo_v_li)
     ,.ready_param_o(stream_fifo_ready_then_lo)

     ,.data_o(stream_fifo_data_lo)
     ,.v_o(stream_fifo_v_lo)
     ,.yumi_i(stream_fifo_yumi_li)
     );

  // Handshakes
  assign in_fsm_v_o = in_fsm_v_lo & stream_fifo_ready_then_lo;
  assign in_fsm_yumi_li = in_fsm_yumi_i;

  assign stream_fifo_data_li = in_fsm_metadata_i;
  assign stream_fifo_v_li = in_fsm_yumi_i & in_fsm_new_o;

  assign out_fsm_metadata_o = stream_fifo_data_lo;
  assign out_fsm_ready_then_o = out_fsm_ready_then_lo & stream_fifo_v_lo;
  assign out_fsm_v_li = out_fsm_v_i;

  assign stream_fifo_yumi_li = out_fsm_v_i & out_fsm_last_o;

endmodule


/**
 *
 * Name:
 *   bp_me_stream_pump_in.sv
 *
 * Description:
 *   Provides an FSM with control signals for an inbound BedRock Stream interface.
 *   This module buffers the inbound BedRock Stream channel and exposes it to the FSM.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_pump_in
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(fsm_data_width_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   // width of BedRock message payload
   , parameter `BSG_INV_PARAM(payload_width_p)

   // Bitmasks that specify which message types may have multiple beats on either
   // the msg input side or FSM output side.
   // Each mask is constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   // There are three cases:
   // 1. Message types that are set in msg_stream_mask_p but not in
   //    fsm_stream_mask_p will result in N:1 conversion from msg->FSM ports.
   //    This is rarely used.
   // 2. Message types that are set as part of fsm_stream_mask_p but not set in
   //    msg_stream_mask_p result in a 1:N conversion from msg->FSM ports.
   //    For example, in BlackParrot a read command for 64B to the
   //    cache arriving on the BedRock Stream input can be decomposed into a stream of
   //    8B reads on the FSM output port.
   // 3. Message types set in both will have N:N beats. Every beat on the input
   //    will produce a beat on the output. This is commonly used for all messages
   //    with data payloads.
   // Constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   , parameter `BSG_INV_PARAM(msg_stream_mask_p)
   , parameter `BSG_INV_PARAM(fsm_stream_mask_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xce)

   , localparam fsm_bytes_lp = fsm_data_width_p >> 3
   , localparam fsm_cnt_offset_width_lp = `BSG_SAFE_CLOG2(fsm_bytes_lp)
   , localparam fsm_words_lp = block_width_p / fsm_data_width_p
   , localparam fsm_cnt_width_lp = `BSG_SAFE_CLOG2(fsm_words_lp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Stream
   , input [xce_header_width_lp-1:0]                msg_header_i
   , input [bedrock_fill_width_p-1:0]               msg_data_i
   , input                                          msg_v_i
   , output logic                                   msg_ready_and_o

   // FSM consumer side
   , output logic [xce_header_width_lp-1:0]         fsm_header_o
   , output logic [paddr_width_p-1:0]               fsm_addr_o
   , output logic [fsm_data_width_p-1:0]            fsm_data_o
   , output logic                                   fsm_v_o
   , input                                          fsm_yumi_i
   // FSM control signals
   // fsm_cnt is the current stream word being sent
   , output logic [fsm_cnt_width_lp-1:0]            fsm_cnt_o
   // fsm_new is raised when first beat of every message is acked
   , output logic                                   fsm_new_o
   // fsm_last is raised on last beat of every message
   , output logic                                   fsm_last_o
   // fsm_critical is raised on the critical beat of every message
   , output logic                                   fsm_critical_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, msg_header);
  `bp_cast_o(bp_bedrock_xce_header_s, fsm_header);

  bp_bedrock_xce_header_s msg_header_li;
  logic [fsm_data_width_p-1:0] msg_data_li;
  logic msg_v_li, msg_yumi_lo;
  bp_me_stream_gearbox
   #(.buffered_p(1)
     ,.in_data_width_p(bedrock_fill_width_p)
     ,.out_data_width_p(fsm_data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.stream_mask_p(msg_stream_mask_p)
     )
   gearbox
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(msg_header_cast_i)
     ,.msg_data_i(msg_data_i)
     ,.msg_v_i(msg_v_i)
     ,.msg_ready_and_o(msg_ready_and_o)

     ,.msg_header_o(msg_header_li)
     ,.msg_data_o(msg_data_li)
     ,.msg_v_o(msg_v_li)
     ,.msg_ready_param_i(msg_yumi_lo)
     );

  wire [fsm_cnt_width_lp-1:0] stream_size =
    `BSG_MAX((1'b1 << msg_header_li.size) / fsm_bytes_lp, 1'b1) - 1'b1;
  wire nz_stream  = stream_size > '0;
  wire fsm_stream = fsm_stream_mask_p[msg_header_li.msg_type];
  wire msg_stream = msg_stream_mask_p[msg_header_li.msg_type];

  logic cnt_up;
  bp_me_stream_pump_control
   #(.bp_params_p(bp_params_p)
     ,.max_val_p(fsm_words_lp-1)
     ,.stream_mask_p(fsm_stream_mask_p)
     ,.data_width_p(fsm_data_width_p)
     ,.payload_width_p(payload_width_p)
     )
   pump_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.header_i(fsm_header_cast_o)
     ,.en_i(cnt_up)

     ,.wrap_o(fsm_cnt_o)
     ,.first_o(fsm_new_o)
     ,.last_o(fsm_last_o)
     ,.critical_o(fsm_critical_o)
     );

  localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3);
  wire [paddr_width_p-1:0] wrap_addr =
    {msg_header_li.addr[paddr_width_p-1:block_offset_width_lp]
     ,{fsm_words_lp>1{fsm_cnt_o}}
     ,msg_header_li.addr[0+:fsm_cnt_offset_width_lp]
     };

  assign fsm_header_cast_o = msg_header_li;
  assign fsm_data_o = msg_data_li;
  assign fsm_addr_o = wrap_addr;

  always_comb
    if (~msg_stream & fsm_stream & nz_stream)
      begin
        // 1:N
        // convert one msg message into stream of N FSM messages
        fsm_v_o = msg_v_li;
        msg_yumi_lo = fsm_last_o & fsm_yumi_i;
        cnt_up = fsm_yumi_i;
      end
    else if (msg_stream & ~fsm_stream & nz_stream)
      begin
        // N:1
        // consume all but first msg input beat silently
        fsm_v_o = msg_v_li & fsm_new_o;
        msg_yumi_lo = msg_v_li & (fsm_yumi_i | ~fsm_new_o);
        cnt_up = msg_yumi_lo;
      end
    else
      begin
        // 1:1
        fsm_v_o = msg_v_li;
        msg_yumi_lo = fsm_yumi_i;
        cnt_up = fsm_yumi_i;
      end

  // parameter checks
  if (block_width_p % fsm_data_width_p != 0)
    $error("block_width_p must be evenly divisible by fsm_data_width_p");
  if (block_width_p < fsm_data_width_p)
    $error("block_width_p must be at least as large as fsm_data_width_p");

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_pump_in)


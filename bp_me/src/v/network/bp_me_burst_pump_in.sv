/**
 *
 * Name:
 *   bp_me_burst_pump_in.sv
 *
 * Description:
 *   Provides an FSM with control signals for an inbound BedRock Stream interface.
 *   This module buffers the inbound BedRock Stream channel and exposes it to the FSM.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_pump_in
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(stream_data_width_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   // width of BedRock message payload
   , parameter `BSG_INV_PARAM(payload_width_p)

   // Bitmasks that specify which message types may have multiple beats on either
   // the msg input side or FSM output side.
   // Each mask is constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   // There are two cases:
   // 1. Message types that are set as part of fsm_stream_mask_p but not set in
   //    msg_stream_mask_p result in a 1:N conversion from msg->FSM ports.
   //    For example, in BlackParrot a read command for 64B to the
   //    cache arriving on the BedRock Stream input can be decomposed into a stream of
   //    8B reads on the FSM output port.
   // 2. Message types set in both will have N:N beats. Every beat on the input
   //    will produce a beat on the output. This is commonly used for all messages
   //    with data payloads.
   // Constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   , parameter msg_stream_mask_p = 0
   , parameter fsm_stream_mask_p = msg_stream_mask_p

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xce)

   , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3)
   , localparam stream_bytes_lp = stream_data_width_p >> 3
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_bytes_lp)
   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam stream_cnt_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)

   // number of messages that can be buffered
   , parameter header_els_p = 2
   , parameter data_els_p   = header_els_p * stream_words_lp
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Stream
   , input [xce_header_width_lp-1:0]                msg_header_i
   , input                                          msg_header_v_i
   , output logic                                   msg_header_ready_and_o
   , input                                          msg_has_data_i

   , input [stream_data_width_p-1:0]                msg_data_i
   , input                                          msg_data_v_i
   , output logic                                   msg_data_ready_and_o
   , input                                          msg_last_i

   // FSM consumer side
   , output logic [xce_header_width_lp-1:0]         fsm_header_o
   , output logic [stream_cnt_width_lp-1:0]         fsm_cnt_o 
   , output logic [paddr_width_p-1:0]               fsm_addr_o
   , output logic [stream_data_width_p-1:0]         fsm_data_o
   , output logic                                   fsm_v_o
   , input                                          fsm_yumi_i
   // FSM control signals
   // fsm_new is raised on first beat of every message
   , output logic                                   fsm_new_o
   // fsm_last is raised on last beat of every message
   , output logic                                   fsm_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, msg_header);
  `bp_cast_o(bp_bedrock_xce_header_s, fsm_header);

  enum logic [1:0]{e_ready, e_spray, e_burst} state_n, state_r;
  wire is_ready = (state_r == e_ready);
  wire is_spray = (state_r == e_spray);
  wire is_burst = (state_r == e_burst);

  bp_bedrock_xce_header_s msg_header_li;
  logic msg_header_v_li, msg_header_yumi_lo, msg_has_data_li;
  bsg_fifo_1r1w_small
   #(.width_p(1+xce_header_width_lp), .els_p(header_els_p))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({msg_has_data_i, msg_header_cast_i})
     ,.v_i(msg_header_v_i)
     ,.ready_o(msg_header_ready_and_o)

     ,.data_o({msg_has_data_li, msg_header_li})
     ,.v_o(msg_header_v_li)
     ,.yumi_i(msg_header_yumi_lo)
     );

  logic [stream_data_width_p-1:0] msg_data_li;
  logic msg_data_v_li, msg_data_yumi_lo, msg_last_li;
  bsg_fifo_1r1w_small
   #(.width_p(1+stream_data_width_p), .els_p(data_els_p))
   data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({msg_last_i, msg_data_i})
     ,.v_i(msg_data_v_i)
     ,.ready_o(msg_data_ready_and_o)

     ,.data_o({msg_last_li, msg_data_li})
     ,.v_o(msg_data_v_li)
     ,.yumi_i(msg_data_yumi_lo)
     );

  wire [stream_cnt_width_lp-1:0] stream_size =
    `BSG_MAX((1'b1 << msg_header_li.size) / stream_bytes_lp, 1'b1) - 1'b1;
  wire nz_stream = stream_size > '0;
  wire fsm_stream = fsm_stream_mask_p[msg_header_li.msg_type];
  wire msg_stream = msg_stream_mask_p[msg_header_li.msg_type];
  wire do_burst = fsm_stream &  msg_stream & nz_stream;
  wire do_spray = fsm_stream & ~msg_stream & nz_stream;

  logic first_lo, last_lo;
  bp_me_burst_wraparound
   #(.max_val_p(stream_words_lp-1)
     ,.addr_width_p(paddr_width_p)
     ,.offset_width_p(stream_cnt_width_lp)
     )
   wraparound
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(fsm_yumi_i)
     ,.size_i(stream_size)
     ,.base_i(msg_header_li.addr)

     ,.addr_o(fsm_addr_o)
     ,.cnt_o(fsm_cnt_o)
     ,.first_o(first_lo)
     ,.last_o(last_lo)
     );

  wire write_v_li = msg_header_v_li & msg_has_data_li & msg_data_v_li;
  wire read_v_li = msg_header_v_li & ~msg_has_data_li;

  always_comb
    begin
      state_n = state_r;

      fsm_header_cast_o = msg_header_li;
      fsm_data_o = msg_data_li;

      fsm_v_o = '0;
      fsm_new_o = '0;
      fsm_last_o = '0;

      msg_header_yumi_lo = '0;
      msg_data_yumi_lo = '0;

      case (state_r)
        e_ready:
          begin
            fsm_v_o            = read_v_li | write_v_li;
            fsm_new_o          = fsm_v_o;
            fsm_last_o         = (read_v_li & ~do_spray) || (write_v_li & ~do_burst);
            msg_header_yumi_lo = fsm_yumi_i & fsm_new_o & fsm_last_o;
            msg_data_yumi_lo   = fsm_yumi_i & msg_has_data_li;

            state_n = fsm_yumi_i
                      ? do_burst
                        ? e_burst
                        : do_spray
                          ? e_spray 
                          : e_ready
                      : e_ready;
          end
        e_burst:
          begin
            fsm_v_o            = msg_data_v_li;
            fsm_last_o         = last_lo;
            msg_data_yumi_lo   = fsm_yumi_i;
            msg_header_yumi_lo = msg_data_yumi_lo & msg_last_li;

            state_n = msg_header_yumi_lo ? e_ready : e_burst;
          end
        e_spray:
          begin
            fsm_v_o            = msg_header_v_li;
            fsm_last_o         = last_lo;
            msg_header_yumi_lo = fsm_yumi_i & last_lo;

            state_n = msg_header_yumi_lo ? e_ready : e_spray;
          end
        default : begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  // parameter checks
  if (block_width_p % stream_data_width_p != 0)
    $error("block_width_p must be evenly divisible by stream_data_width_p");
  if (block_width_p < stream_data_width_p)
    $error("block_width_p must be at least as large as stream_data_width_p");

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_pump_in)


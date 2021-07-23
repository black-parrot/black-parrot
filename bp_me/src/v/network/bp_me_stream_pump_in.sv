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

   , parameter stream_data_width_p = dword_width_gp
   , parameter block_width_p = cce_block_width_p
   // width of BedRock message payload
   , parameter payload_width_p = "inv"

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
   , parameter msg_stream_mask_p = 0
   , parameter fsm_stream_mask_p = msg_stream_mask_p

   , parameter buffer_els_p = 2

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce)

   , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3)
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_data_width_p >> 3)
   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Stream
   , input [xce_msg_header_width_lp-1:0]            msg_header_i
   , input [stream_data_width_p-1:0]                msg_data_i
   , input                                          msg_v_i
   , input                                          msg_last_i
   , output logic                                   msg_ready_and_o

   // FSM consumer side
   , output logic [xce_msg_header_width_lp-1:0]     fsm_base_header_o
   , output logic [paddr_width_p-1:0]               fsm_addr_o
   , output logic [stream_data_width_p-1:0]         fsm_data_o
   , output logic                                   fsm_v_o
   , input                                          fsm_yumi_i
   // FSM control signals
   // fsm_new is raised when first beat of every message is acked
   , output logic                                   fsm_new_o
   // fsm_done is raised when last beat of every message is acked
   , output logic                                   fsm_done_o
   // fsm_last is raised on last beat of every message
   , output logic                                   fsm_last_o
   );


  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce);

  `bp_cast_o(bp_bedrock_xce_msg_header_s, fsm_base_header);

  bp_bedrock_xce_msg_header_s msg_header_lo;
  logic [stream_data_width_p-1:0] msg_data_lo;
  logic msg_v_lo, msg_yumi_li, msg_last_lo;

  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_bedrock_xce_msg_s)+1)
     ,.els_p(buffer_els_p)
     )
   input_fifo
    (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i({msg_last_i, msg_header_i, msg_data_i})
      ,.v_i(msg_v_i)
      ,.ready_o(msg_ready_and_o)

      ,.data_o({msg_last_lo, msg_header_lo, msg_data_lo})
      ,.v_o(msg_v_lo)
      ,.yumi_i(msg_yumi_li)
      );

  wire [data_len_width_lp-1:0] num_stream = `BSG_MAX((1'b1 << msg_header_lo.size) / (stream_data_width_p / 8), 1'b1) - 1'b1;

  logic cnt_up, is_last_cnt, streaming_r;
  logic is_fsm_stream, is_msg_stream;
  wire any_fsm_new = (is_fsm_stream | is_msg_stream) & ~streaming_r;
  // store this addr for stream state
  logic [block_offset_width_lp-1:0] critical_addr_r;

  if (stream_words_lp == 1)
    begin: full_block_stream
      assign is_fsm_stream = '0;
      assign is_msg_stream = '0;
      assign streaming_r = '0;
      assign critical_addr_r = msg_header_lo.addr[0+:block_offset_width_lp];
      assign is_last_cnt = 1'b1;
      assign fsm_addr_o = msg_header_lo.addr;
    end
  else
    begin: sub_block_stream
      logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt, stream_cnt, cnt_val_li;
      wire cnt_set = (any_fsm_new & cnt_up) | fsm_done_o;
      wire cnt_en = (cnt_up | fsm_done_o);
      bsg_counter_set_en
       #(.max_val_p(stream_words_lp-1), .reset_val_p(0))
       data_counter
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.set_i(cnt_set)
        ,.en_i(cnt_en)
        ,.val_i(cnt_val_li)
        ,.count_o(current_cnt)
        );

      bsg_dff_reset_set_clear
       #(.width_p(1)
       ,.clear_over_set_p(1))
       streaming_reg
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.set_i(cnt_up)
        ,.clear_i(fsm_done_o)
        ,.data_o(streaming_r)
        );

      bsg_dff_en_bypass
       #(.width_p(block_offset_width_lp))
       critical_addr_reg
        (.clk_i(clk_i)
        ,.data_i(msg_header_lo.addr[0+:block_offset_width_lp])
        ,.en_i(~streaming_r)
        ,.data_o(critical_addr_r)
        );

      always_comb
        begin
          first_cnt = critical_addr_r[stream_offset_width_lp+:data_len_width_lp];
          last_cnt  = first_cnt + num_stream;

          is_fsm_stream = fsm_stream_mask_p[msg_header_lo.msg_type] & ~(first_cnt == last_cnt);
          is_msg_stream = msg_stream_mask_p[msg_header_lo.msg_type] & ~(first_cnt == last_cnt);

          stream_cnt = any_fsm_new ? first_cnt : current_cnt;
          is_last_cnt = (stream_cnt == last_cnt) | (~is_fsm_stream & ~is_msg_stream);
          cnt_val_li = fsm_done_o ? '0 : (first_cnt + cnt_up);
        end

      // Generate proper wrap-around address for different incoming msg size dynamically.
      // __________________________________________________________
      // |                |          block offset                  |  input address
      // |  upper address |________________________________________|
      // |                |     stream count   |  stream offset    |  output address
      // |________________|____________________|___________________|
      // Block size = stream count * stream size, with a request smaller than block_width_p,
      // a narrower stream_cnt is required to generate address for each sub-stream pkt.
      // Eg. block_width_p = 512, stream_data_witdh_p = 64, then counter width = log2(512/64) = 3
      // size = 512: a wrapped around seq: 2, 3, 4, 5, 6, 7, 0, 1  all 3-bit of cnt is used
      // size = 256: a wrapped around seq: 2, 3, 0, 1              only lower 2-bit of cnt is used

      logic [data_len_width_lp-1:0] wrap_around_cnt;

      bsg_mux_bitwise
       #(.width_p(data_len_width_lp))
       sub_block_addr_mux
        (.data0_i(msg_header_lo.addr[stream_offset_width_lp+:data_len_width_lp])
        ,.data1_i(stream_cnt)
        ,.sel_i(num_stream)
        ,.data_o(wrap_around_cnt)
      );

      assign fsm_addr_o = { msg_header_lo.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                          , wrap_around_cnt
                          , msg_header_lo.addr[0+:stream_offset_width_lp]};
    end

  always_comb
    begin
      fsm_base_header_cast_o = msg_header_lo;
      // keep the address to be the critical word address
      fsm_base_header_cast_o.addr[0+:block_offset_width_lp] = critical_addr_r;
      fsm_data_o = msg_data_lo;

      if (~is_msg_stream & is_fsm_stream)
        begin
          // 1:N
          // convert one msg message into stream of N FSM messages
          fsm_v_o = msg_v_lo;
          msg_yumi_li = is_last_cnt & msg_last_lo & fsm_yumi_i;
          cnt_up = fsm_yumi_i & ~is_last_cnt;
        end
      else if (is_msg_stream & ~is_fsm_stream)
        begin
          // N:1
          // consume all but last msg input beat silently, then FSM consumes last beat
          fsm_v_o = msg_v_lo & is_last_cnt;
          msg_yumi_li = (~is_last_cnt & msg_v_lo) | (is_last_cnt & msg_v_lo & msg_last_lo & fsm_yumi_i);
          cnt_up = msg_v_lo & ~is_last_cnt;
        end
      else
        begin
          // 1:1
          fsm_v_o = msg_v_lo;
          msg_yumi_li = fsm_yumi_i;
          cnt_up = fsm_yumi_i & ~is_last_cnt;
        end

      fsm_new_o  = fsm_yumi_i & ~streaming_r;
      fsm_done_o = fsm_yumi_i & is_last_cnt;
      fsm_last_o = fsm_v_o & is_last_cnt;
    end

  //synopsys translate_off
  if (block_width_p % stream_data_width_p != 0)
    $fatal("block_width_p must be evenly divisible by stream_data_width_p");

  if (block_width_p < stream_data_width_p)
    $fatal("block_width_p must be at least as large as stream_data_width_p");
  //synopsys translate_on

endmodule


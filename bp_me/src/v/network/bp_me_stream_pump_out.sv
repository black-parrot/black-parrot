/**
 *
 * Name:
 *   bp_me_stream_pump_out.sv
 *
 * Description:
 *   Generates a BedRock Stream protocol output message from an FSM that provides
 *   a base header and, if required, data words. The base header is held constant
 *   by the FSM throughout the transaction.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_pump_out
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter stream_data_width_p = dword_width_gp
   , parameter block_width_p = cce_block_width_p
   // width of BedRock message payload
   , parameter payload_width_p = "inv"

   // Bitmasks that specify which message types may have multiple beats on either
   // the FSM input side or msg output side.
   // Each mask is constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   // There are three cases:
   // 1. Message types that are set in msg_stream_mask_p but not in
   //    fsm_stream_mask_p will result in 1:N conversion from FSM->msg ports.
   // 2. Message types that are set as part of fsm_stream_mask_p but not set in
   //    msg_stream_mask_p result in a N:1 conversion from FSM->msg ports.
   // 3. Message types set in both will have N:N beats. Every beat on the input
   //    will produce a beat on the output. This is commonly used for all messages
   //    with data payloads.
   // Constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   , parameter msg_stream_mask_p = 0
   , parameter fsm_stream_mask_p = msg_stream_mask_p

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce)

   , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3)
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_data_width_p >> 3)
   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Output BedRock Stream
   , output logic [xce_msg_header_width_lp-1:0]     msg_header_o
   , output logic [stream_data_width_p-1:0]         msg_data_o
   , output logic                                   msg_v_o
   , output logic                                   msg_last_o
   , input                                          msg_ready_and_i

   // FSM producer side
   // FSM must hold fsm_base_header_i constant throughout the transaction
   // (i.e., through cycle fsm_done_o is raised)
   , input        [xce_msg_header_width_lp-1:0]     fsm_base_header_i
   , input        [stream_data_width_p-1:0]         fsm_data_i
   , input                                          fsm_v_i
   , output logic                                   fsm_ready_and_o

   // FSM control signals
   // fsm_cnt is the current stream word being sent
   , output logic [data_len_width_lp-1:0]           fsm_cnt_o
   // fsm_new is raised when first beat of every message is acked
   , output logic                                   fsm_new_o
   // fsm_done is raised when last beat of every message sends
   , output logic                                   fsm_done_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce);

  `bp_cast_i(bp_bedrock_xce_msg_header_s, fsm_base_header);
  `bp_cast_o(bp_bedrock_xce_msg_header_s, msg_header);

  wire [data_len_width_lp-1:0] num_stream = `BSG_MAX((1'b1 << fsm_base_header_cast_i.size) / (stream_data_width_p / 8), 1'b1) - 1'b1;

  logic cnt_up, is_last_cnt, streaming_r;
  logic is_fsm_stream, is_msg_stream;
  logic [data_len_width_lp-1:0] wrap_around_cnt;
  wire any_stream_new = (is_fsm_stream | is_msg_stream) & ~streaming_r;
  // store this addr for stream state
  logic [block_offset_width_lp-1:0] critical_addr_r;

  if (stream_words_lp == 1)
    begin: full_block_stream
      assign is_fsm_stream = '0;
      assign is_msg_stream = '0;
      assign streaming_r = '0;
      assign fsm_cnt_o = fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp];
      assign wrap_around_cnt = fsm_cnt_o;
      assign critical_addr_r = fsm_base_header_cast_i.addr[0+:block_offset_width_lp];
      assign is_last_cnt = 1'b1;
    end
  else
    begin: sub_block_stream
      logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt, cnt_val_li;
      wire cnt_set = (any_stream_new & cnt_up) | fsm_done_o;
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
        ,.data_i(fsm_base_header_cast_i.addr[0+:block_offset_width_lp])
        ,.en_i(~streaming_r)
        ,.data_o(critical_addr_r)
        );

      always_comb
        begin
          first_cnt = fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp];
          last_cnt  = first_cnt + num_stream;

          is_fsm_stream = fsm_stream_mask_p[fsm_base_header_cast_i.msg_type] & ~(first_cnt == last_cnt);
          is_msg_stream = msg_stream_mask_p[fsm_base_header_cast_i.msg_type] & ~(first_cnt == last_cnt);

          fsm_cnt_o = (any_stream_new & cnt_up) ? first_cnt : current_cnt;
          is_last_cnt = (fsm_cnt_o == last_cnt) | (~is_fsm_stream & ~is_msg_stream);
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

      bsg_mux_bitwise
       #(.width_p(data_len_width_lp))
       sub_block_addr_mux
        (.data0_i(fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp])
        ,.data1_i(fsm_cnt_o)
        ,.sel_i(num_stream)
        ,.data_o(wrap_around_cnt)
        );
    end

  logic [stream_offset_width_lp+data_len_width_lp-1:0] sub_block_adddr, sub_block_adddr_tuned;
  always_comb
    begin
      msg_header_cast_o = fsm_base_header_cast_i;

      if (~is_fsm_stream & is_msg_stream)
        begin
          // 1:N
          // send N msg beats, and ack single FSM beat on last msg beat
          msg_v_o = fsm_v_i;
          fsm_ready_and_o = msg_ready_and_i & is_last_cnt;
          cnt_up = msg_v_o & msg_ready_and_i & ~is_last_cnt;
          msg_header_cast_o.addr = { fsm_base_header_cast_i.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                   , wrap_around_cnt
                                   , fsm_base_header_cast_i.addr[0+:stream_offset_width_lp]};
        end
      else if (is_fsm_stream & ~is_msg_stream)
        begin
          // N:1
          // only send msg on last FSM beat
          msg_v_o = is_last_cnt & fsm_v_i;
          // ack all but last FSM beat silently, then ack last FSM beat when msg beat sends
          fsm_ready_and_o = ~is_last_cnt | (is_last_cnt & msg_ready_and_i);
          cnt_up = fsm_v_i & ~is_last_cnt;
          // hold address constant at critical address
          msg_header_cast_o.addr[0+:block_offset_width_lp] = critical_addr_r;
        end
      else
        begin
          // 1:1
          msg_v_o = fsm_v_i;
          fsm_ready_and_o = msg_ready_and_i;
          cnt_up  = fsm_ready_and_o & fsm_v_i & ~is_last_cnt;
          msg_header_cast_o.addr = { fsm_base_header_cast_i.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                   , wrap_around_cnt
                                   , fsm_base_header_cast_i.addr[0+:stream_offset_width_lp]};
        end

      msg_data_o = fsm_data_i;
      msg_last_o = is_last_cnt & msg_v_o;

      fsm_new_o = fsm_ready_and_o & fsm_v_i & ~streaming_r;
      fsm_done_o = fsm_ready_and_o & fsm_v_i & is_last_cnt;
    end

  //synopsys translate_off
  if (block_width_p % stream_data_width_p != 0)
    $fatal("block_width_p must be evenly divisible by stream_data_width_p");

  if (block_width_p < stream_data_width_p)
    $fatal("block_width_p must be at least as large as stream_data_width_p");
  //synopsys translate_on

endmodule


/**
 *
 * Name:
 *   bp_stream_pump_in.sv
 *
 * Description:
 *   Provides an FSM with control signals for an inbound BedRock Stream interface.
 *   This module buffers the inbound BedRock Stream channel and exposes it to the FSM.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_pump_in
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter stream_data_width_p = dword_width_gp
   , parameter block_width_p = cce_block_width_p

   // Bitmasks that specify which message types may have multiple beats on either
   // the memory input side or FSM output side.
   // Each mask is constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   // There are three cases:
   // 1. Message types that are set in mem_stream_mask_p but not in
   //    fsm_stream_mask_p will result in N:1 conversion from mem->FSM ports.
   //    This is rarely used.
   // 2. Message types that are set as part of fsm_stream_mask_p but not set in
   //    mem_stream_mask_p result in a 1:N conversion from mem->FSM ports.
   //    For example, in BlackParrot a read command for 64B to the
   //    cache arriving on the BedRock Stream input can be decomposed into a stream of
   //    8B reads on the FSM output port.
   // 3. Message types set in both will have N:N beats. Every beat on the input
   //    will produce a beat on the output. This is commonly used for all messages
   //    with data payloads.
   // Constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   , parameter mem_stream_mask_p = 0
   , parameter fsm_stream_mask_p = mem_stream_mask_p

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce)
   , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3)
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_data_width_p >> 3)
   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   )
  ( input                                          clk_i
  , input                                          reset_i

  // Input BedRock Stream
  , input [xce_mem_msg_header_width_lp-1:0]        mem_header_i
  , input [stream_data_width_p-1:0]                mem_data_i
  , input                                          mem_v_i
  , input                                          mem_last_i
  , output logic                                   mem_ready_and_o

  // FSM consumer side
  , output logic [xce_mem_msg_header_width_lp-1:0] fsm_base_header_o
  , output logic [paddr_width_p-1:0]               fsm_addr_o
  , output logic [stream_data_width_p-1:0]         fsm_data_o
  , output logic                                   fsm_v_o
  , input                                          fsm_yumi_i

  // FSM control signals
  // stream_new is raised on first beat of a multi-beat message
  , output logic                                   stream_new_o
  // stream_done is raised on last beat of every message
  , output logic                                   stream_done_o
  );

  //synopsys translate_off
  initial begin
    assert((block_width_p % stream_data_width_p == 0)) else
      $error("block_width_p must be evenly divisible by stream_data_width_p");
    assert((block_width_p >= stream_data_width_p == 0)) else
      $error("block_width_p must be at least as large as stream_data_width_p");
  end
  //synopsys translate_on

  `declare_bp_bedrock_mem_if(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce);

  `bp_cast_o(bp_bedrock_xce_mem_msg_header_s, fsm_base_header);

  bp_bedrock_xce_mem_msg_header_s mem_header_lo;
  logic [stream_data_width_p-1:0] mem_data_lo;
  logic mem_v_lo, mem_yumi_li, mem_last_lo;

  bsg_two_fifo
   #(.width_p($bits(bp_bedrock_xce_mem_msg_s)+1))
   input_fifo
    (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i({mem_last_i, mem_header_i, mem_data_i})
      ,.v_i(mem_v_i)
      ,.ready_o(mem_ready_and_o)

      ,.data_o({mem_last_lo, mem_header_lo, mem_data_lo})
      ,.v_o(mem_v_lo)
      ,.yumi_i(mem_yumi_li)
      );

  wire [data_len_width_lp-1:0] num_stream = `BSG_MAX((1'b1 << mem_header_lo.size) / (stream_data_width_p / 8), 1'b1);

  logic cnt_up, is_last_cnt, streaming_r;
  logic is_fsm_stream, is_mem_stream;
  wire any_stream_new = (is_fsm_stream | is_mem_stream) & ~streaming_r;
  // store this addr for stream state
  logic [block_offset_width_lp-1:0] critical_addr_r;

  if (stream_words_lp == 1)
    begin: full_block_stream
      assign is_fsm_stream = '0;
      assign is_mem_stream = '0;
      assign streaming_r = '0;
      assign critical_addr_r = mem_header_lo.addr[0+:block_offset_width_lp];
      assign is_last_cnt = 1'b1;
      assign fsm_addr_o = mem_header_lo.addr;
    end
  else
    begin: sub_block_stream
      logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt, stream_cnt;
      bsg_counter_set_en
       #(.max_val_p(stream_words_lp-1), .reset_val_p(0))
       data_counter
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.set_i(any_stream_new & cnt_up)
        ,.en_i(cnt_up | stream_done_o)
        ,.val_i(first_cnt + cnt_up)
        ,.count_o(current_cnt)
        );

      bsg_dff_reset_set_clear
       #(.width_p(1)
       ,.clear_over_set_p(1))
       streaming_reg
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.set_i(cnt_up)
        ,.clear_i(stream_done_o)
        ,.data_o(streaming_r)
        );

      bsg_dff_en_bypass
       #(.width_p(block_offset_width_lp))
       critical_addr_reg
        (.clk_i(clk_i)
        ,.data_i(mem_header_lo.addr[0+:block_offset_width_lp])
        ,.en_i(~streaming_r)
        ,.data_o(critical_addr_r)
        );

      always_comb
        begin
          first_cnt = critical_addr_r[stream_offset_width_lp+:data_len_width_lp];
          last_cnt  = first_cnt + num_stream - 1'b1;

          is_fsm_stream = fsm_stream_mask_p[mem_header_lo.msg_type] & ~(first_cnt == last_cnt);
          is_mem_stream = mem_stream_mask_p[mem_header_lo.msg_type] & ~(first_cnt == last_cnt);

          stream_cnt = any_stream_new ? first_cnt : current_cnt;
          is_last_cnt = (stream_cnt == last_cnt) | (~is_fsm_stream & ~is_mem_stream);
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

      // sel_mask is generated to determined how many bits of counter is used.
      // For num_stream = x, (x-1) denotes the bits using the counter
      logic [data_len_width_lp-1:0] sel_mask, wrap_around_cnt;
      assign sel_mask = num_stream - 1'b1;

      bsg_mux_bitwise
       #(.width_p(data_len_width_lp))
       sub_block_addr_mux
        (.data0_i(mem_header_lo.addr[stream_offset_width_lp+:data_len_width_lp])
        ,.data1_i(stream_cnt)
        ,.sel_i(sel_mask)
        ,.data_o(wrap_around_cnt)
      );

      assign fsm_addr_o = { mem_header_lo.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                          , wrap_around_cnt
                          , mem_header_lo.addr[0+:stream_offset_width_lp]};
    end

  always_comb
    begin
      fsm_base_header_cast_o = mem_header_lo;
      // keep the address to be the critical word address
      fsm_base_header_cast_o.addr[0+:block_offset_width_lp] = critical_addr_r;
      fsm_data_o = mem_data_lo;

      if (~is_mem_stream & is_fsm_stream)
        begin
          // 1:N
          fsm_v_o = mem_v_lo;
          mem_yumi_li = is_last_cnt & mem_last_lo & fsm_yumi_i;
          cnt_up = fsm_yumi_i & ~is_last_cnt;
        end
      else if (is_mem_stream & ~is_fsm_stream)
        begin
          // N:1
          // consume all but last mem input beat silently, then FSM consumes last beat
          fsm_v_o = mem_v_lo & is_last_cnt;
          mem_yumi_li = ~is_last_cnt ? mem_v_lo : (mem_last_lo & fsm_yumi_i);
          cnt_up = mem_v_lo & ~is_last_cnt;
        end
      else
        begin
          // 1:1
          fsm_v_o = mem_v_lo;
          mem_yumi_li = fsm_yumi_i;
          cnt_up = fsm_yumi_i & ~is_last_cnt;
        end

      stream_done_o = is_last_cnt & fsm_yumi_i;
      stream_new_o = (is_fsm_stream) & ~streaming_r;
    end

endmodule

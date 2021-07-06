
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_stream_pump_out
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter stream_data_width_p = dword_width_gp
   , parameter block_width_p = cce_block_width_p

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce)

   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_data_width_p >> 3)
   )
  (input                                            clk_i
   , input                                          reset_i
 
   // Output BedRock Stream
   , output logic [xce_mem_msg_header_width_lp-1:0] mem_header_o
   , output logic [stream_data_width_p-1:0]         mem_data_o
   , output logic                                   mem_v_o
   , output logic                                   mem_last_o
   , input                                          mem_ready_and_i
 
   // FSM producer side
   // FSM must hold fsm_base_header_i constant throughout the transaction
   // (i.e., through cycle stream_done_o is raised)
   , input [xce_mem_msg_header_width_lp-1:0]        fsm_base_header_i
   , input [stream_data_width_p-1:0]                fsm_data_i
   , input                                          fsm_v_i
   , output logic                                   fsm_ready_and_o
   // FSM control signals
   // fsm_cnt is the current stream word being sent
   , output logic [data_len_width_lp-1:0]           fsm_cnt_o
   // fsm_done is raised when last beat sends
   , output logic                                   fsm_done_o
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce);

  `bp_cast_i(bp_bedrock_xce_mem_msg_header_s, fsm_base_header);
  `bp_cast_o(bp_bedrock_xce_mem_msg_header_s, mem_header);

  wire [data_len_width_lp-1:0] num_stream = `BSG_MAX((1'b1 << fsm_base_header_cast_i.size) / (stream_data_width_p / 8), 1'b1) - 1'b1;

  logic set_cnt, cnt_up, is_last_cnt, is_stream, streaming_r;
  logic [data_len_width_lp-1:0] wrap_around_cnt;

  if (stream_words_lp == 1)
    begin: full_block_stream
      assign is_stream = '0;
      assign streaming_r = '0;
      assign fsm_cnt_o = fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp];
      assign wrap_around_cnt = fsm_cnt_o;
      assign is_last_cnt = 1'b1;
    end
  else
    begin: sub_block_stream
      logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt, cnt_val_li;
      wire cnt_set = (any_stream_new & cnt_up) | stream_done_o;
      wire cnt_en = (cnt_up | stream_done_o);
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

      always_comb
        begin
          first_cnt = fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp];
          last_cnt  = first_cnt + num_stream;

          is_fsm_stream = fsm_stream_mask_p[fsm_base_header_cast_i.msg_type] & ~(first_cnt == last_cnt);
          is_mem_stream = mem_stream_mask_p[fsm_base_header_cast_i.msg_type] & ~(first_cnt == last_cnt);

          stream_cnt_o = (any_stream_new & cnt_up) ? first_cnt : current_cnt;
          is_last_cnt = (stream_cnt_o == last_cnt) | (~is_fsm_stream & ~is_mem_stream);
          cnt_val_li = stream_done_o ? '0 : (first_cnt + cnt_up);
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

  wire has_data = payload_mask_p[fsm_base_header_cast_i.msg_type];

  logic [stream_offset_width_lp+data_len_width_lp-1:0] sub_block_adddr, sub_block_adddr_tuned;
  always_comb
    begin
      mem_header_cast_o = fsm_base_header_cast_i;
      if (~is_stream | has_data)
        begin
          // handle message size <= stream_data_width_p | command w/o data payload | message size > stream_data_width_p w/ data payload
          mem_v_o = fsm_v_i;
          fsm_ready_and_o = mem_ready_and_i;

          cnt_up  = fsm_ready_and_o & fsm_v_i & ~is_last_cnt;
          set_cnt = ~streaming_r;

          mem_header_cast_o.addr = { fsm_base_header_cast_i.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                   , wrap_around_cnt
                                   , fsm_base_header_cast_i.addr[0+:stream_offset_width_lp]};

        end
      else
        begin
          // handle message size > stream_data_width_p w/o data payload (combines write responses into one)
          mem_v_o = is_last_cnt & fsm_v_i;
          fsm_ready_and_o = mem_ready_and_i;

          cnt_up  = fsm_ready_and_o & fsm_v_i & ~is_last_cnt;
          set_cnt = ~streaming_r;
        end

      mem_data_o = fsm_data_i;
      mem_last_o = is_last_cnt & mem_v_o;

      fsm_done_o = mem_ready_and_i & mem_v_o & is_last_cnt;
    end

  //synopsys translate_off
  if (block_width_p % stream_data_width_p != 0)
    $fatal("block_width_p must be evenly divisible by stream_data_width_p");

  if (block_width_p < stream_data_width_p)
    $fatal("block_width_p must be at least as large as stream_data_width_p");
  end
  //synopsys translate_on

endmodule


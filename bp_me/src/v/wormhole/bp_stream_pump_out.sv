
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
   // Bitmask which determines which message types should get streamed
   // Constructed as (1 << e_rd/wr_msg | 1 << e_uc_rd/wr_msg)
   , parameter stream_mask_p = 0

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce)

   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_data_width_p >> 3)
   )
  ( input clk_i
  , input reset_i

  // bus side
  , output logic [xce_mem_msg_header_width_lp-1:0] mem_header_o
  , output logic [stream_data_width_p-1:0]         mem_data_o
  , output logic                                   mem_v_o
  , output logic                                   mem_last_o
  , input                                          mem_ready_and_i
  
  // FSM side
  , input        [xce_mem_msg_header_width_lp-1:0] fsm_base_header_i
  , input        [stream_data_width_p-1:0]         fsm_data_i
  , input                                          fsm_v_i
  , output logic                                   fsm_ready_and_o

  // control signals
  , output logic [data_len_width_lp-1:0]           stream_cnt_o
  , output logic                                   stream_done_o
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce);
  
  `bp_cast_i(bp_bedrock_xce_mem_msg_header_s, fsm_base_header);
  `bp_cast_o(bp_bedrock_xce_mem_msg_header_s, mem_header);

  wire [data_len_width_lp-1:0] num_stream = `BSG_MAX((1'b1 << fsm_base_header_cast_i.size) / (stream_data_width_p / 8), 1'b1);

  logic set_cnt, cnt_up, is_last_cnt, is_stream, streaming_r;
  logic [data_len_width_lp-1:0] wrap_around_cnt;
  
  if (stream_words_lp == 1)
    begin: full_block_stream
      assign is_stream = '0;
      assign streaming_r = '0;
      assign stream_cnt_o = fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp];
      assign wrap_around_cnt = stream_cnt_o;
      assign is_last_cnt = 1'b1;
    end
  else
    begin: sub_block_stream 
      logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt;
      bsg_counter_set_en
       #(.max_val_p(stream_words_lp-1), .reset_val_p(0))
       data_counter
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.set_i(set_cnt) 
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
        
      always_comb
        begin 
          first_cnt = fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp];
          last_cnt  = first_cnt + num_stream - 1'b1;
      
          is_stream = stream_mask_p[fsm_base_header_cast_i.msg_type] & ~(first_cnt == last_cnt);
          stream_cnt_o = set_cnt ? first_cnt : current_cnt;
          is_last_cnt = (stream_cnt_o == last_cnt) | ~is_stream;
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
      logic [data_len_width_lp-1:0] sel_mask;
      assign sel_mask = num_stream - 1'b1;

      bsg_mux_bitwise
       #(.width_p(data_len_width_lp))
       sub_block_addr_mux
        (.data0_i(fsm_base_header_cast_i.addr[stream_offset_width_lp+:data_len_width_lp])
        ,.data1_i(stream_cnt_o)
        ,.sel_i(sel_mask)
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
          fsm_ready_and_o = mem_ready_and_i & mem_v_o;
          
          cnt_up  = fsm_ready_and_o & ~is_last_cnt;
          set_cnt = fsm_ready_and_o & ~streaming_r;

          mem_header_cast_o.addr = { fsm_base_header_cast_i.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                   , wrap_around_cnt
                                   , fsm_base_header_cast_i.addr[0+:stream_offset_width_lp]};
        
        end
      else
        begin
          // handle message size > stream_data_width_p w/o data payload (combines write responses into one)
          mem_v_o = is_last_cnt & fsm_v_i;
          fsm_ready_and_o = is_last_cnt ? (mem_ready_and_i & mem_v_o) : fsm_v_i;

          cnt_up  = fsm_v_i & ~is_last_cnt;
          set_cnt = fsm_v_i & ~streaming_r;
        end
      
      mem_data_o = fsm_data_i;
      mem_last_o = is_last_cnt & mem_v_o;

      stream_done_o = mem_ready_and_i & mem_v_o & is_last_cnt; 
    end

endmodule
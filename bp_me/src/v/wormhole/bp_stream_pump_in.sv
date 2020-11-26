module bp_stream_pump_in
 import bp_cce_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   
   , parameter stream_data_width_p = dword_width_p
   , parameter block_width_p = cce_block_width_p

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, stream_data_width_p, lce_id_width_p, lce_assoc_p, xce)
   , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3)

   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_data_width_p / 8)
   , localparam logic resp_payload_lp  = payload_mask_p[e_bedrock_mem_uc_rd] | payload_mask_p[e_bedrock_mem_rd]
   )
  ( input clk_i
  , input reset_i

  // bus side
  , input         [xce_mem_msg_header_width_lp-1:0] mem_header_i
  , input         [stream_data_width_p-1:0]         mem_data_i
  , input                                           mem_v_i
  , input                                           mem_last_i
  , output logic                                    mem_ready_and_o
  
  // FSM side
  , output logic [xce_mem_msg_header_width_lp-1:0] fsm_base_header_o
  , output logic [paddr_width_p-1:0]               fsm_addr_o
  , output logic [stream_data_width_p-1:0]         fsm_data_o
  , output logic                                   fsm_v_o
  , input                                          fsm_ready_and_i

  // control signals
  , output logic                                   stream_new_o
  , output logic                                   stream_done_o
  );

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
  logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt, stream_cnt;
  if (stream_words_lp == 1)
    begin: full_block_stream
      assign current_cnt = first_cnt;
      assign streaming_r = '0;
    end
  else
    begin: sub_block_stream 
      bsg_counter_set_en
       #(.max_val_p(stream_words_lp-1), .reset_val_p(0))
       data_counter
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.set_i(stream_new_o & cnt_up) 
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
    end
  assign first_cnt = fsm_base_header_cast_o.addr[stream_offset_width_lp+:data_len_width_lp];
  assign last_cnt  = first_cnt + num_stream - 1'b1;
  
  wire has_data = payload_mask_p[mem_header_lo.msg_type];
  wire single_beat = (first_cnt == last_cnt) | (resp_payload_lp & ~has_data);
  
  assign stream_cnt = stream_new_o ? first_cnt : current_cnt;
  assign is_last_cnt = (stream_cnt == last_cnt) | single_beat;

  // store this addr for stream state
  logic [block_offset_width_lp-1:0] critical_addr_r;
  bsg_dff_en_bypass 
   #(.width_p(block_offset_width_lp))
   critical_addr_reg
    (.clk_i(clk_i)
    ,.data_i(mem_header_lo.addr[0+:block_offset_width_lp])
    ,.en_i(stream_new_o)
    ,.data_o(critical_addr_r)
    );

  always_comb
    begin
      fsm_base_header_cast_o = mem_header_lo;
      fsm_data_o = mem_data_lo;
      fsm_v_o = mem_v_lo;
      fsm_addr_o = { mem_header_lo.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                  , {data_len_width_lp!=0{stream_cnt}}
                  , mem_header_lo.addr[0+:stream_offset_width_lp]};   

      cnt_up = fsm_ready_and_i & fsm_v_o & ~is_last_cnt;
      stream_done_o = is_last_cnt & fsm_ready_and_i & fsm_v_o; // also used for credits return

      mem_yumi_li = has_data ? (fsm_ready_and_i & fsm_v_o) : stream_done_o;

      if (single_beat)
        begin
          // handle message size <= stream_data_width_p ｜ response w/o data payload
          stream_new_o = '0;
        end
      else
        begin
          // handle message size > stream_data_width_p w/ data payload ｜ commands reading more than data than stream_data_width_p
          fsm_base_header_cast_o.addr[0+:block_offset_width_lp] = critical_addr_r; // keep the address to be the critical word address

          stream_new_o = fsm_v_o & ~streaming_r;
        end
    end

  // TODO: assertion to identify whether critical_addr is aligned to the bus_data_width/burst_width

endmodule
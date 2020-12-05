
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_burst_to_stream
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   // Assuming in_data_width_p(burst) == out_data_width_p(stream)
   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = in_data_width_p
   , parameter block_width_p = "inv"
   , parameter payload_width_p  = "inv"

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)

   )
  (input                                            clk_i
   , input                                          reset_i

   // Master BP Burst
   // ready-valid-and
   , input [in_msg_header_width_lp-1:0]      in_msg_header_i
   , input                                   in_msg_header_v_i
   , output logic                            in_msg_header_ready_and_o

   // ready-valid-and
   , input [in_data_width_p-1:0]             in_msg_data_i
   , input                                   in_msg_data_v_i
   , output logic                            in_msg_data_ready_and_o

   // Client BP Stream
   // ready-valid-and
   , output logic [out_msg_header_width_lp-1:0]     out_msg_header_o
   , output logic [out_data_width_p-1:0]            out_msg_data_o
   , output logic                                   out_msg_v_o
   , input                                          out_msg_ready_and_i
   , output logic                                   out_msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam stream_words_lp = block_width_p/out_data_width_p;
  localparam data_len_width_lp = (stream_words_lp>0) ? `BSG_SAFE_CLOG2(stream_words_lp) : 0;
  localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(out_data_width_p / 8);

  bp_bedrock_out_msg_header_s out_header_lo;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_header_ready_and_o & in_msg_header_v_i)
    ,.data_i(in_msg_header_i)
    ,.data_o(out_header_lo)
    );

  logic header_v_r, header_clear;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
   header_v_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_header_v_i)
    ,.clear_i(header_clear)
    ,.data_o(header_v_r) 
    );
  assign header_v_lo  = in_msg_header_v_i | header_v_r;
  assign header_clear = out_msg_ready_and_i & out_msg_v_o & out_msg_last_o;

  // Accept no new header as long as a valid header exists
  assign in_msg_header_ready_and_o = ~header_v_r; 

  // has_data: start streaming data, keep the header in fifo and increment the address
  // ~has_data: pass the header
  wire has_data = payload_mask_p[out_header_lo.msg_type];

  // passthrough data
  assign out_msg_data_o = in_msg_data_i;
  assign out_msg_v_o = header_v_lo & (in_msg_data_v_i | ~has_data);
  assign in_msg_data_ready_and_o = out_msg_ready_and_i & out_msg_v_o & has_data;

  bp_bedrock_out_msg_header_s out_msg_header_cast_o;
  // increment the address for bp_stream
  logic is_last_cnt;
  if (stream_words_lp == 1)
   begin: full_block_stream
      assign is_last_cnt = out_msg_v_o;
      assign out_msg_header_cast_o = out_header_lo;
   end
  else 
    begin: sub_block_stream
      logic set_cnt, cnt_up, streaming_r;
      logic [data_len_width_lp-1:0] first_cnt, last_cnt, current_cnt, stream_cnt;
      wire [data_len_width_lp-1:0] num_stream = `BSG_MAX((1'b1 << out_header_lo.size) / out_data_bytes_lp, 1'b1);

      bsg_counter_set_en
       #(.max_val_p(stream_words_lp-1)
       ,.reset_val_p(0))
       data_counter
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.set_i(set_cnt) 
        ,.en_i(cnt_up)
        ,.val_i(first_cnt+cnt_up)
        ,.count_o(current_cnt)
        );

      bsg_dff_reset_set_clear
       #(.width_p(1)
       ,.clear_over_set_p(1))
       streaming_reg
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.set_i(set_cnt)
        ,.clear_i(out_msg_last_o)
        ,.data_o(streaming_r)
        );
      
      assign first_cnt = out_header_lo.addr[stream_offset_width_lp+:data_len_width_lp];
      assign last_cnt  = first_cnt + num_stream - 1'b1;

      assign set_cnt = out_msg_ready_and_i & out_msg_v_o & has_data & ~streaming_r;
      assign cnt_up = out_msg_ready_and_i & out_msg_v_o;

      assign stream_cnt = set_cnt ? first_cnt : current_cnt;

      wire single_beat = ~has_data | (first_cnt == last_cnt);
      assign is_last_cnt = (stream_cnt == last_cnt) | single_beat;

      always_comb
        begin
          out_msg_header_cast_o = out_header_lo;
          out_msg_header_cast_o.addr = { out_header_lo.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                       , {(data_len_width_lp>0){stream_cnt}}
                                       , out_header_lo.addr[0+:stream_offset_width_lp] };
        end 
    end

  assign out_msg_last_o = out_msg_v_o & is_last_cnt;
  assign out_msg_header_o = out_msg_header_cast_o;

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p == out_data_width_p)
        else $error("Input data width should be identical with output data width");
    end
  //synopsys translate_on

endmodule



module bp_lite_to_stream
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = "inv"
   , parameter payload_width_p  = "inv"

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter int payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)

   )
  (input                                            clk_i
   , input                                          reset_i

   // Master BP Lite
   // ready-valid-and
   , input [in_msg_width_lp-1:0]                    in_msg_i
   , input                                          in_msg_v_i
   , output logic                                   in_msg_ready_and_o

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

  bp_bedrock_in_msg_s msg_cast_i;
  assign msg_cast_i = in_msg_i;

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam stream_words_lp = in_data_width_p/out_data_width_p;
  localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  bp_bedrock_in_msg_header_s in_msg_header_lo;
  logic [in_data_width_p-1:0] in_msg_data_lo;
  // Hold the data and header for multi-cycle streaming
  bsg_dff_en_bypass
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_ready_and_o & in_msg_v_i)
    ,.data_i(msg_cast_i.header)
    ,.data_o(in_msg_header_lo)
    );

  bsg_dff_en_bypass
   #(.width_p(in_data_width_p))
   data_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_ready_and_o & in_msg_v_i)
    ,.data_i(msg_cast_i.data)
    ,.data_o(in_msg_data_lo)
    );

  logic streaming_r, stream_clear;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
    streaming_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_ready_and_o & in_msg_v_i)
    ,.clear_i(stream_clear)
    ,.data_o(streaming_r)
    );

  // Accept no new lite pkt with pending valid data
  assign in_msg_ready_and_o = ~streaming_r;

  wire has_data = payload_mask_p[in_msg_header_lo.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [data_len_width_lp-1:0] num_stream_cmds = has_data
    ? `BSG_MAX(((1'b1 << in_msg_header_lo.size) / out_data_bytes_lp), 1'b1)
    : 1'b1;
  
  logic first_lo;
  bsg_parallel_in_serial_out_passthrough_dynamic
   #(.width_p(out_data_width_p)
   ,.max_els_p(stream_words_lp))
   piso_passthrough
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    // data_i and v_i should hold during the entire transcation
    ,.data_i(in_msg_data_lo)
    ,.v_i(in_msg_v_i | streaming_r)
    ,.ready_and_o(/* unused */)
    ,.len_i(num_stream_cmds - 1'b1)

    ,.data_o(out_msg_data_o)
    ,.v_o(out_msg_v_o)
    ,.ready_and_i(out_msg_ready_and_i)
    ,.first_o(first_lo)  
    );

  // We wouldn't need this counter if we could peek into the PISO...
  logic [data_len_width_lp-1:0] first_cnt, last_cnt, last_cnt_r, current_cnt, stream_cnt;
  logic cnt_up;
  assign cnt_up = out_msg_ready_and_i & out_msg_v_o;
  bsg_counter_set_en
   #(.max_val_p(stream_words_lp-1), .reset_val_p(0))
   data_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(in_msg_v_i)
     ,.en_i(cnt_up)
     ,.val_i(first_cnt + cnt_up)
     ,.count_o(current_cnt)
     );
  assign first_cnt = in_msg_header_lo.addr[stream_offset_width_lp+:data_len_width_lp];
  assign last_cnt = first_cnt + num_stream_cmds - 1'b1;
  bsg_dff_en_bypass
   #(.width_p(data_len_width_lp))
   last_cnt_reg
    (.clk_i(clk_i)
    ,.data_i(last_cnt)
    ,.en_i(in_msg_v_i)
    ,.data_o(last_cnt_r)
    );
  
  assign stream_cnt = first_lo ? first_cnt : current_cnt;
  wire cnt_done = (stream_cnt == last_cnt_r);

  bp_bedrock_out_msg_header_s msg_header_cast_o;
  assign out_msg_header_o = msg_header_cast_o;

  always_comb
    begin
      // Autoincrement address
      msg_header_cast_o = in_msg_header_lo;
      msg_header_cast_o.addr = {in_msg_header_lo.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                ,stream_cnt
                                ,in_msg_header_lo.addr[0+:stream_offset_width_lp]
                                };
    end
  assign out_msg_last_o = out_msg_v_o & cnt_done;
  assign stream_clear = cnt_done & cnt_up;

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p >= out_data_width_p)
        else $error("Master data cannot be smaller than client");
      assert (in_data_width_p % out_data_width_p == 0)
        else $error("Master data must be a multiple of client data");
    end

  always_ff @(negedge clk_i)
    begin
      //if (in_msg_ready_and_o & in_msg_v_i)
      //  $display("[%t] Msg received: %p", $time, msg_cast_i);

      //if (out_msg_ready_and_i & out_msg_v_o)
      //  $display("[%t] Stream sent: %p %x CNT: %x", $time, msg_header_cast_o, out_msg_data_o, current_cnt);
    end
  //synopsys translate_on

endmodule


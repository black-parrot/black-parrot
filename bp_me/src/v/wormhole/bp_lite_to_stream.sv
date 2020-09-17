
module bp_lite_to_stream
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = "inv"

   // Bitmask which etermines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter payload_mask_p = 0

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Master BP Lite
   // ready-valid-and
   , input [in_mem_msg_width_lp-1:0]                mem_i
   , input                                          mem_v_i
   , output logic                                   mem_ready_o

   // Client BP Stream
   // ready-valid-and
   , output logic [out_mem_msg_header_width_lp-1:0] mem_header_o
   , output logic [out_data_width_p-1:0]            mem_data_o
   , output logic                                   mem_v_o
   , input                                          mem_ready_i
   , output logic                                   mem_last_o
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, out);
  bp_bedrock_in_mem_msg_s mem_cast_i;
  bp_bedrock_in_mem_msg_header_s mem_header_cast_i;
  assign mem_cast_i = mem_i;
  assign mem_header_cast_i = mem_cast_i.header;

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam stream_words_lp = in_data_width_p/out_data_width_p;
  localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  bp_bedrock_in_mem_msg_header_s header_lo;
  logic mem_v_lo, mem_yumi_li;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_in_mem_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cast_i.header)
     ,.ready_o(mem_ready_o)
     ,.v_i(mem_v_i)

     ,.data_o(header_lo)
     ,.v_o(mem_v_lo)
     ,.yumi_i(mem_yumi_li)
     );

  wire has_data = payload_mask_p[mem_header_cast_i.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [data_len_width_lp-1:0] num_stream_cmds = has_data
    ? `BSG_MAX(((1'b1 << mem_cast_i.header.size) / out_data_bytes_lp), 1'b1)
    : 1'b1;
  logic [out_data_width_p-1:0] data_lo;
  bsg_parallel_in_serial_out_dynamic
   #(.width_p(out_data_width_p), .max_els_p(stream_words_lp))
   piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cast_i.data)
     ,.len_i(num_stream_cmds - 1'b1)
     ,.v_i(mem_v_i)

     ,.data_o(mem_data_o)
     ,.v_o(mem_v_o)
     ,.yumi_i(mem_ready_i & mem_v_o)

     // We rely on the header fifo to handle ready/valid handshaking
     ,.len_v_o(/* Unused */)
     ,.ready_o(/* Unused */)
     );

  // We wouldn't need this counter if we could peek into the PISO...
  logic [data_len_width_lp-1:0] first_cnt, last_cnt, last_cnt_r, current_cnt;
  bsg_counter_set_en
   #(.max_val_p(stream_words_lp-1), .reset_val_p(0))
   data_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(mem_v_i)
     ,.en_i(mem_ready_i & mem_v_o)
     ,.val_i(first_cnt)
     ,.count_o(current_cnt)
     );
  assign first_cnt = mem_cast_i.header.addr[stream_offset_width_lp+:data_len_width_lp];
  assign last_cnt = first_cnt + num_stream_cmds - 1'b1;
  bsg_dff_en_bypass
   #(.width_p(data_len_width_lp))
   last_cnt_reg
    (.clk_i(clk_i)
    ,.data_i(last_cnt)
    ,.en_i(mem_v_i)
    ,.data_o(last_cnt_r)
    );
  
  wire cnt_done = (current_cnt == last_cnt_r);

  bp_bedrock_out_mem_msg_header_s mem_header_cast_o;
  assign mem_header_o = mem_header_cast_o;
  always_comb
    begin
      // Autoincrement address
      mem_header_cast_o = header_lo;
      mem_header_cast_o.addr = {header_lo.addr[paddr_width_p-1:stream_offset_width_lp+data_len_width_lp]
                                ,current_cnt
                                ,header_lo.addr[0+:stream_offset_width_lp]
                                };
    end
  assign mem_last_o = mem_v_o & cnt_done;
  assign mem_yumi_li = cnt_done & mem_ready_i & mem_v_o;

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
      //if (mem_ready_o & mem_v_i)
      //  $display("[%t] Msg received: %p", $time, mem_cast_i);

      //if (mem_ready_i & mem_v_o)
      //  $display("[%t] Stream sent: %p %x CNT: %x", $time, mem_header_cast_o, mem_data_o, data_cnt);
    end
  //synopsys translate_on

endmodule


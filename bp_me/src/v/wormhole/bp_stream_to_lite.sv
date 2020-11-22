
module bp_stream_to_lite
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
  (input                                     clk_i
   , input                                   reset_i

   // Master BP Stream
   // ready-valid-and
   , input [in_mem_msg_header_width_lp-1:0]  mem_header_i
   , input [in_data_width_p-1:0]             mem_data_i
   , input                                   mem_v_i
   , output logic                            mem_ready_o
   , input                                   mem_lock_i

   // Client BP Lite
   // ready-valid-and
   , output logic [out_mem_msg_width_lp-1:0] mem_o
   , output logic                            mem_v_o
   , input                                   mem_ready_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, out);

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam stream_words_lp = out_data_width_p/in_data_width_p;
  localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  bp_bedrock_in_mem_msg_header_s header_lo;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_in_mem_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_header_i)
     // We ready on ready/and failing on the stream after the first
     ,.v_i(mem_v_i)

     ,.data_o(header_lo)
     ,.yumi_i(mem_ready_i & mem_v_o)

     // We use the sipo ready/valid
     ,.ready_o(/* Unused */)
     ,.v_o(/* Unused */)
     );

  bp_bedrock_in_mem_msg_header_s mem_header_cast_i;
  assign mem_header_cast_i = mem_header_i;
  wire has_data = payload_mask_p[mem_header_cast_i.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [data_len_width_lp-1:0] num_stream_cmds = has_data
    ? `BSG_MAX(((1'b1 << mem_header_cast_i.size) / in_data_bytes_lp), 1'b1)
    : 1'b1;
  logic [out_data_width_p-1:0] data_lo;
  logic data_ready_lo, len_ready_lo;
  bsg_serial_in_parallel_out_dynamic
   #(.width_p(in_data_width_p), .max_els_p(stream_words_lp))
   sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_data_i)
     ,.len_i(num_stream_cmds-1'b1)
     ,.ready_o(mem_ready_o)
     ,.v_i(mem_v_i)

     ,.data_o(data_lo)
     ,.v_o(mem_v_o)
     ,.yumi_i(mem_ready_i & mem_v_o)

     // We rely on fifo ready signal
     ,.len_ready_o(/* Unused */)
     );

  wire unused = &{mem_lock_i};

  bp_bedrock_out_mem_msg_s mem_cast_o;
  assign mem_cast_o = '{header: header_lo, data: data_lo};
  assign mem_o = mem_cast_o;

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p < out_data_width_p)
        else $error("Master data cannot be larger than client");
      assert (out_data_width_p % in_data_width_p == 0)
        else $error("Client data must be a multiple of master data");
    end

  always_ff @(negedge clk_i)
    begin
    //  if (mem_v_i)
    //    $display("[%t] Stream received: %p %x", $time, mem_header_cast_i, mem_data_i);

    //  if (mem_ready_i & mem_v_o)
    //    $display("[%t] Msg sent: %p", $time, mem_cast_o);
    end
  //synopsys translate_on

endmodule


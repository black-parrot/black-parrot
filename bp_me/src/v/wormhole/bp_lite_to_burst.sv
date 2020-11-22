
module bp_lite_to_burst
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
   , output logic                                   mem_ready_and_o

   // Client BP Burst
   // ready-valid-and
   , output logic [out_mem_msg_header_width_lp-1:0] mem_header_o
   , output logic                                   mem_header_v_o
   , input logic                                    mem_header_ready_and_i

   // ready-valid-and
   , output logic [out_data_width_p-1:0]            mem_data_o
   , output logic                                   mem_data_v_o
   , input                                          mem_data_ready_and_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, out);
  bp_bedrock_in_mem_msg_s mem_cast_i;
  assign mem_cast_i = mem_i;

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam burst_words_lp = in_data_width_p/out_data_width_p;
  localparam burst_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  // We could make this a two fifo to get more throughput
  bp_bedrock_in_mem_msg_header_s header_lo;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_in_mem_msg_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cast_i.header)
     ,.v_i(mem_v_i)
     ,.ready_o(mem_ready_and_o)

     ,.data_o(mem_header_o)
     ,.v_o(mem_header_v_o)
     ,.yumi_i(mem_header_ready_and_i & mem_header_v_o)
     );

  wire has_data = payload_mask_p[mem_cast_i.header.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(burst_words_lp);
  wire [data_len_width_lp-1:0] num_burst_cmds = `BSG_MAX(1, (1'b1 << mem_cast_i.header.size) / out_data_bytes_lp);
  logic [out_data_width_p-1:0] data_lo;
  bsg_parallel_in_serial_out_dynamic
   #(.width_p(out_data_width_p), .max_els_p(burst_words_lp))
   piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cast_i.data)
     ,.len_i(num_burst_cmds - 1'b1)
     ,.v_i(mem_ready_and_o & mem_v_i & has_data)

     ,.data_o(mem_data_o)
     ,.v_o(mem_data_v_o)
     ,.yumi_i(mem_data_ready_and_i & mem_data_v_o)

     // We rely on the header fifo to handle ready/valid handshaking
     ,.len_v_o(/* Unused */)
     ,.ready_o(/* Unused */)
     );

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
      //if (mem_ready_and_o & mem_v_i)
      //  $display("[%t] Msg received: %p", $time, mem_cast_i);

      //if (mem_header_ready_and_i & mem_header_v_o)
      //  $display("[%t] Stream sent: %p %x CNT: %x", $time, mem_header_cast_o, mem_data_o, num_burst_cmds);
    end
  //synopsys translate_on

endmodule


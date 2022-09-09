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

   , parameter `BSG_INV_PARAM(stream_data_width_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   // width of BedRock message payload
   , parameter `BSG_INV_PARAM(payload_width_p)

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

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xce)

   , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_width_p >> 3)
   , localparam stream_bytes_lp = stream_data_width_p >> 3
   , localparam stream_offset_width_lp = `BSG_SAFE_CLOG2(stream_bytes_lp)
   , localparam stream_words_lp = block_width_p / stream_data_width_p
   , localparam stream_cnt_width_lp = `BSG_SAFE_CLOG2(stream_words_lp)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Output BedRock Stream
   , output logic [xce_header_width_lp-1:0]         msg_header_o
   , output logic [stream_data_width_p-1:0]         msg_data_o
   , output logic                                   msg_v_o
   , output logic                                   msg_last_o
   , input                                          msg_ready_and_i

   // FSM producer side
   // FSM must hold fsm_header_i constant throughout the transaction
   // (i.e., through cycle fsm_last_o is raised)
   , input [xce_header_width_lp-1:0]                fsm_header_i
   , output logic [paddr_width_p-1:0]               fsm_addr_o
   , input [stream_data_width_p-1:0]                fsm_data_i
   , input                                          fsm_v_i
   , output logic                                   fsm_ready_and_o

   // FSM control signals
   // fsm_cnt is the current stream word being sent
   , output logic [stream_cnt_width_lp-1:0]         fsm_cnt_o
   // fsm_new is raised when first beat of every message is acked
   , output logic                                   fsm_new_o
   // fsm_last is raised on last beat of every message
   , output logic                                   fsm_last_o
   );

  if (block_width_p % stream_data_width_p != 0)
    $error("Stream pump block width must be multiple of stream data width");

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, fsm_header);
  `bp_cast_o(bp_bedrock_xce_header_s, msg_header);

  wire [stream_cnt_width_lp-1:0] stream_size =
    `BSG_MAX((1'b1 << fsm_header_cast_i.size) / stream_bytes_lp, 1'b1) - 1'b1;
  wire nz_stream  = stream_size > '0;
  wire fsm_stream = fsm_stream_mask_p[fsm_header_cast_i.msg_type] & nz_stream;
  wire msg_stream = msg_stream_mask_p[fsm_header_cast_i.msg_type] & nz_stream;
  wire any_stream = fsm_stream | msg_stream;

  logic cnt_up;
  wire [stream_cnt_width_lp-1:0] size_li = fsm_stream ? stream_size : '0;
  wire [stream_cnt_width_lp-1:0] first_cnt = fsm_header_cast_i.addr[stream_offset_width_lp+:stream_cnt_width_lp];
  bp_me_stream_pump_control
   #(.max_val_p(stream_words_lp-1))
   pump_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.size_i(size_li)
     ,.val_i(first_cnt)
     ,.en_i(cnt_up)

     ,.wrap_o(fsm_cnt_o)
     ,.first_o(fsm_new_o)
     ,.last_o(fsm_last_o)
     );

  wire [paddr_width_p-1:0] wrap_addr =
    {fsm_header_cast_i.addr[paddr_width_p-1:block_offset_width_lp]
     ,{stream_words_lp>1{fsm_cnt_o}}
     ,fsm_header_cast_i.addr[0+:stream_offset_width_lp]
     };
  assign fsm_addr_o = wrap_addr;

  always_comb
    begin
      msg_header_cast_o = fsm_header_cast_i;
      msg_data_o = fsm_data_i;

      if (~fsm_stream & msg_stream)
        begin
          // 1:N
          // send N msg beats, and ack single FSM beat on last msg beat
          msg_v_o = fsm_v_i;
          fsm_ready_and_o = fsm_last_o & msg_ready_and_i;
          cnt_up = msg_v_o & msg_ready_and_i;
          msg_header_cast_o.addr = wrap_addr;
        end
      else if (fsm_stream & ~msg_stream)
        begin
          // N:1
          // only send msg on last FSM beat
          msg_v_o = fsm_v_i & fsm_last_o;
          // ack all but last FSM beat silently, then ack last FSM beat when msg beat sends
          fsm_ready_and_o = (fsm_v_i & ~fsm_last_o) | msg_ready_and_i;
          cnt_up = fsm_ready_and_o & fsm_v_i;
          // hold address constant at critical address
          msg_header_cast_o.addr = fsm_header_cast_i.addr;
        end
      else
        begin
          // 1:1
          msg_v_o = fsm_v_i;
          fsm_ready_and_o = msg_ready_and_i;
          cnt_up  = fsm_ready_and_o & fsm_v_i;
          msg_header_cast_o.addr = wrap_addr;
        end

      msg_last_o = fsm_last_o;
    end

  // parameter checks
  if (block_width_p % stream_data_width_p != 0)
    $error("block_width_p must be evenly divisible by stream_data_width_p");
  if (block_width_p < stream_data_width_p)
    $error("block_width_p must be at least as large as stream_data_width_p");

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_pump_out)


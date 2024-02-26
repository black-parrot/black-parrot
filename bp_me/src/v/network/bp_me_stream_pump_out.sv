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

   , parameter `BSG_INV_PARAM(data_width_p)
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
   , parameter `BSG_INV_PARAM(msg_stream_mask_p)
   , parameter `BSG_INV_PARAM(fsm_stream_mask_p)

   `declare_bp_bedrock_generic_if_width(paddr_width_p, payload_width_p, xce)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Output BedRock Stream
   , output logic [xce_header_width_lp-1:0]         msg_header_o
   , output logic [bedrock_fill_width_p-1:0]        msg_data_o
   , output logic                                   msg_v_o
   , input                                          msg_ready_and_i

   // FSM producer side
   // FSM must hold fsm_header_i constant throughout the transaction
   // (i.e., through cycle fsm_last_o is raised)
   , input [xce_header_width_lp-1:0]                fsm_header_i
   , input [data_width_p-1:0]                       fsm_data_i
   , input                                          fsm_v_i
   , output logic                                   fsm_ready_then_o

   // FSM control signals
   // fsm_addr is the effective address of the beat
   , output logic [paddr_width_p-1:0]               fsm_addr_o
   // fsm_new is raised when first beat of every message is acked
   , output logic                                   fsm_new_o
   // fsm_last is raised on last beat of every message
   , output logic                                   fsm_last_o
   // fsm_critical is raised on critical beat of every message
   , output logic                                   fsm_critical_o
   );

  `declare_bp_bedrock_generic_if(paddr_width_p, payload_width_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, fsm_header);
  `bp_cast_o(bp_bedrock_xce_header_s, msg_header);

  localparam fsm_bytes_lp = data_width_p >> 3;
  localparam fsm_words_lp = bedrock_block_width_p / data_width_p;
  localparam fsm_cnt_width_lp = `BSG_SAFE_CLOG2(fsm_words_lp);

  bp_bedrock_xce_header_s msg_header_lo;
  logic [data_width_p-1:0] msg_data_lo;
  logic msg_v_lo, msg_ready_and_li;
  bp_me_stream_gearbox
   #(.bp_params_p(bp_params_p)
     ,.in_data_width_p(data_width_p)
     ,.out_data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(payload_width_p)
     ,.stream_mask_p(msg_stream_mask_p)
     )
   gearbox
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(msg_header_lo)
     ,.msg_data_i(msg_data_lo)
     ,.msg_v_i(msg_v_lo)
     ,.msg_ready_and_o(msg_ready_and_li)

     ,.msg_header_o(msg_header_cast_o)
     ,.msg_data_o(msg_data_o)
     ,.msg_v_o(msg_v_o)
     ,.msg_ready_param_i(msg_ready_and_i)
     );

  wire [fsm_cnt_width_lp-1:0] stream_size =
    `BSG_MAX((1'b1 << fsm_header_cast_i.size) / fsm_bytes_lp, 1'b1) - 1'b1;
  wire nz_stream  = stream_size > '0;
  wire fsm_stream = fsm_stream_mask_p[fsm_header_cast_i.msg_type];
  wire msg_stream = msg_stream_mask_p[fsm_header_cast_i.msg_type];

  // TODO: This could be dynamically adjusted depending on target
  localparam widest_beat_width_lp =
    `BSG_MAX(icache_fill_width_p, `BSG_MAX(dcache_fill_width_p, bedrock_fill_width_p));
  localparam widest_beat_size_lp = `BSG_SAFE_CLOG2(widest_beat_width_lp)-1;
  logic cnt_up;
  bp_me_stream_pump_control
   #(.bp_params_p(bp_params_p)
     ,.stream_mask_p(fsm_stream_mask_p)
     ,.data_width_p(data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.widest_beat_size_p(widest_beat_size_lp)
     )
   pump_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.header_i(fsm_header_cast_i)
     ,.ack_i(cnt_up)

     ,.addr_o(fsm_addr_o)
     ,.first_o(fsm_new_o)
     ,.last_o(fsm_last_o)
     ,.critical_o(fsm_critical_o)
     );

  assign msg_header_lo = fsm_header_cast_i;
  assign msg_data_lo = fsm_data_i;

  always_comb
    if (fsm_stream & ~msg_stream & nz_stream)
      begin
        // N:1
        // ack all but first FSM beat silently
        fsm_ready_then_o = msg_ready_and_li;
        msg_v_lo = fsm_v_i & fsm_new_o;
        cnt_up = fsm_v_i;
      end
    else
      begin
        // 1:1
        fsm_ready_then_o = msg_ready_and_li;
        msg_v_lo = fsm_v_i;
        cnt_up = msg_v_lo;
      end

  // parameter checks
  if (bedrock_block_width_p % data_width_p != 0)
    $error("bedrock_block_width_p must be evenly divisible by data_width_p");
  if (bedrock_block_width_p < data_width_p)
    $error("bedrock_block_width_p must be at least as large as data_width_p");

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_pump_out)


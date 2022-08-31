/**
 *
 * Name:
 *   bp_me_burst_pump_out.sv
 *
 * Description:
 *   Generates a BedRock Stream protocol output message from an FSM that provides
 *   a base header and, if required, data words. The base header is held constant
 *   by the FSM throughout the transaction.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_pump_out
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
   , output logic                                   msg_header_v_o
   , input                                          msg_header_ready_and_i
   , output logic                                   msg_has_data_o

   , output logic [stream_data_width_p-1:0]         msg_data_o
   , output logic                                   msg_data_v_o
   , input                                          msg_data_ready_and_i
   , output logic                                   msg_last_o

   // FSM producer side
   // FSM must hold fsm_header_i constant throughout the transaction
   // (i.e., through cycle fsm_last_o is raised)
   , input        [xce_header_width_lp-1:0]         fsm_header_i
   , input        [stream_data_width_p-1:0]         fsm_data_i
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

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, fsm_header);
  `bp_cast_o(bp_bedrock_xce_header_s, msg_header);
  
  enum logic [1:0] {e_ready, e_burst, e_aggregate} state_n, state_r;
  wire is_ready     = (state_r == e_ready);
  wire is_burst     = (state_r == e_burst);
  wire is_aggregate = (state_r == e_aggregate);
  wire fsm_stream = fsm_stream_mask_p[fsm_header_cast_i.msg_type];

  wire [stream_cnt_width_lp-1:0] stream_size = fsm_stream
    ? `BSG_MAX((1'b1 << fsm_header_cast_i.size) / stream_bytes_lp, 1'b1) - 1'b1
    : '0;

  logic first_lo, last_lo;
  bp_me_burst_wraparound
   #(.max_val_p(stream_words_lp-1)
     ,.addr_width_p(paddr_width_p)
     ,.offset_width_p(stream_cnt_width_lp)
     )
   wraparound
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
 
     ,.en_i(fsm_ready_and_o & fsm_v_i)
     ,.size_i(stream_size)
     ,.base_i(fsm_header_cast_i.addr)
 
     ,.addr_o()
     ,.cnt_o(fsm_cnt_o)
     ,.first_o(fsm_new_o)
     ,.last_o(fsm_last_o)
     );

  logic header_v_li, header_ready_lo;
  bsg_two_fifo
   #(.width_p(1+$bits(bp_bedrock_xce_header_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({fsm_stream, fsm_header_cast_i})
     ,.v_i(header_v_li)
     ,.ready_o(header_ready_lo)

     ,.data_o({msg_has_data_o, msg_header_cast_o})
     ,.v_o(msg_header_v_o)
     ,.yumi_i(msg_header_ready_and_i & msg_header_v_o)
     );

  logic data_v_li, data_ready_lo;
  bsg_two_fifo
   #(.width_p(1+stream_data_width_p))
   data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({fsm_last_o, fsm_data_i})
     ,.v_i(data_v_li)
     ,.ready_o(data_ready_lo)

     ,.data_o({msg_last_o, msg_data_o})
     ,.v_o(msg_data_v_o)
     ,.yumi_i(msg_data_ready_and_i & msg_data_v_o)
     );

  always_comb
    begin
      state_n = state_r;

      fsm_ready_and_o = '0;
      header_v_li = '0;
      data_v_li = '0;

      case (state_r)
        e_ready:
          begin
            // Need data to be ready to maintain helpfulness
            // Unlikely to cause performance issues
            fsm_ready_and_o = header_ready_lo & data_ready_lo;
            header_v_li = fsm_ready_and_o & fsm_v_i;
            data_v_li = fsm_ready_and_o & fsm_v_i & fsm_stream;

            state_n = (data_v_li & ~fsm_last_o) ? e_burst : e_ready;
          end
        e_burst:
          begin
            fsm_ready_and_o = data_ready_lo;
            data_v_li = fsm_ready_and_o & fsm_v_i;

            state_n = (data_v_li & fsm_last_o) ? e_ready : e_burst;
          end
        default : begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_pump_out)


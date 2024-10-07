/**
 *
 * Name:
 *   bp_cce_hybrid_uc_pipe.sv
 *
 * Description:
 *   This module processes uncached LCE requests targeting uncacheable memory.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_uc_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter lce_data_width_p = dword_width_gp
    , parameter mem_data_width_p = dword_width_gp
    , parameter header_fifo_els_p = 2
    , parameter data_fifo_els_p = 2

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control signals
   , output logic                                   empty_o

   // LCE Request
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_ready_and_o
   , input                                          lce_req_has_data_i
   , input [lce_data_width_p-1:0]                   lce_req_data_i
   , input                                          lce_req_data_v_i
   , output logic                                   lce_req_data_ready_and_o
   , input                                          lce_req_last_i

   // Memory command
   // BedRock Stream protocol: ready&valid
   , output logic [cce_mem_header_width_lp-1:0]     mem_cmd_header_o
   , output logic [mem_data_width_p-1:0]            mem_cmd_data_o
   , output logic                                   mem_cmd_v_o
   , input                                          mem_cmd_ready_and_i
   , output logic                                   mem_cmd_last_o
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

  // Header Buffer
  logic lce_req_header_v_li, lce_req_header_yumi_lo, lce_req_has_data_li;
  bp_bedrock_lce_req_header_s lce_req_header_li;
  bsg_fifo_1r1w_small
    #(.width_p(lce_req_header_width_lp+1)
      ,.els_p(header_fifo_els_p)
      )
    header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      ,.v_i(lce_req_header_v_i)
      ,.ready_o(lce_req_header_ready_and_o)
      ,.data_i({lce_req_has_data_i, lce_req_header_i})
      // output
      ,.v_o(lce_req_header_v_li)
      ,.yumi_i(lce_req_header_yumi_lo)
      ,.data_o({lce_req_has_data_li, lce_req_header_li})
      );

  // Data buffer
  logic lce_req_data_v_li, lce_req_data_yumi_lo, lce_req_last_li;
  logic [lce_data_width_p-1:0] lce_req_data_li;
  bsg_fifo_1r1w_small
    #(.width_p(lce_data_width_p+1)
      ,.els_p(data_fifo_els_p)
      )
    data_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      ,.v_i(lce_req_data_v_i)
      ,.ready_o(lce_req_data_ready_and_o)
      ,.data_i({lce_req_last_i, lce_req_data_i})
      // output
      ,.v_o(lce_req_data_v_li)
      ,.yumi_i(lce_req_data_yumi_lo)
      ,.data_o({lce_req_last_li, lce_req_data_li})
      );

  // Memory Command Stream Pump
  localparam stream_words_lp = cce_block_width_p / mem_data_width_p;
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  bp_bedrock_cce_mem_header_s mem_cmd_base_header_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li;
  logic mem_cmd_stream_new_li, mem_cmd_stream_done_li;
  logic [mem_data_width_p-1:0] mem_cmd_data_lo;
  logic [data_len_width_lp-1:0] mem_cmd_stream_cnt_li;
  bp_me_stream_pump_out
    #(.bp_params_p(bp_params_p)
      ,.stream_data_width_p(mem_data_width_p)
      ,.block_width_p(cce_block_width_p)
      ,.payload_width_p(cce_mem_payload_width_lp)
      ,.msg_stream_mask_p(mem_cmd_payload_mask_gp)
      ,.fsm_stream_mask_p(mem_cmd_payload_mask_gp)
      )
    mem_cmd_stream_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // to memory command output
      ,.msg_header_o(mem_cmd_header_o)
      ,.msg_data_o(mem_cmd_data_o)
      ,.msg_v_o(mem_cmd_v_o)
      ,.msg_last_o(mem_cmd_last_o)
      ,.msg_ready_and_i(mem_cmd_ready_and_i)
      // from uncacheable pipe
      ,.fsm_base_header_i(mem_cmd_base_header_lo)
      ,.fsm_data_i(mem_cmd_data_lo)
      ,.fsm_v_i(mem_cmd_v_lo)
      ,.fsm_ready_and_o(mem_cmd_ready_and_li)
      ,.fsm_cnt_o(mem_cmd_stream_cnt_li)
      ,.fsm_new_o(mem_cmd_stream_new_li)
      ,.fsm_last_o(/* unused */)
      ,.fsm_done_o(mem_cmd_stream_done_li)
      );

  // FSM states
  // e_ready: process LCE request header
  // e_data: forward data if required
  enum logic {e_ready, e_data} state_r, state_n;

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  assign empty_o = (state_r == e_ready) & ~lce_req_header_v_li & ~lce_req_data_v_li;

  // Combinational Logic
  always_comb begin
    // header is dequeued on last beat of every message
    lce_req_header_yumi_lo = mem_cmd_stream_done_li;
    // data will be dequeued with each beat for data carrying messages
    lce_req_data_yumi_lo = '0;
    // memory command defaults
    mem_cmd_base_header_lo = '0;
    mem_cmd_base_header_lo.addr = lce_req_header_li.addr;
    mem_cmd_base_header_lo.size = lce_req_header_li.size;
    mem_cmd_base_header_lo.subop = lce_req_header_li.subop;
    mem_cmd_base_header_lo.payload.lce_id = lce_req_header_li.payload.src_id;
    mem_cmd_base_header_lo.payload.way_id = lce_req_header_li.payload.lru_way_id;
    mem_cmd_base_header_lo.payload.uncached = 1'b1;
    mem_cmd_data_lo = lce_req_data_li;
    mem_cmd_v_lo = 1'b0;

    state_n = state_r;

    unique case (state_r)
      // send first beat (header or header+data)
      e_ready: begin
        unique case (lce_req_header_li.msg_type.req)
          e_bedrock_req_uc_rd : begin
            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_rd;
            mem_cmd_v_lo = lce_req_header_v_li;
          end
          e_bedrock_req_uc_wr: begin
            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_wr;
            mem_cmd_v_lo = lce_req_header_v_li & lce_req_data_v_li;
            lce_req_data_yumi_lo = mem_cmd_v_lo & mem_cmd_ready_and_li;
            state_n = (mem_cmd_v_lo & mem_cmd_ready_and_li) & ~mem_cmd_stream_done_li
                      ? e_data : e_ready;
          end
          // LCE sent cacheable read/write miss (cache block fetches)
          // do not set uncached access bit in payload to indicate that LCE request was cacheable
          // set state based on read or write miss type - this allows the response to set a valid
          // state when it returns and is forwarded to LCE, but no coherence is enforced.
          e_bedrock_req_rd_miss
          ,e_bedrock_req_wr_miss: begin
            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_rd;
            mem_cmd_base_header_lo.payload.uncached = 1'b0;
            mem_cmd_base_header_lo.payload.state = (lce_req_header_li.msg_type.req == e_bedrock_req_rd_miss)
                                                   ? e_COH_S
                                                   : e_COH_M;
            mem_cmd_v_lo = lce_req_header_v_li;
          end
          e_bedrock_req_uc_amo: begin
            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_amo;
            mem_cmd_v_lo = lce_req_header_v_li & lce_req_data_v_li;
            lce_req_data_yumi_lo = mem_cmd_v_lo & mem_cmd_ready_and_li;
            state_n = (mem_cmd_v_lo & mem_cmd_ready_and_li) & ~mem_cmd_stream_done_li
                      ? e_data : e_ready;
          end
          default: begin
          end
        endcase
      end // e_ready
      // send remaining data beats
      e_data: begin
        unique case (lce_req_header_li.msg_type.req)
          e_bedrock_req_uc_wr: begin
            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_uc_wr;
            mem_cmd_v_lo = lce_req_header_v_li & lce_req_data_v_li;
            lce_req_data_yumi_lo = mem_cmd_v_lo & mem_cmd_ready_and_li;
            state_n = mem_cmd_stream_done_li ? e_ready : e_data;
          end
          e_bedrock_req_uc_amo: begin
            mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_amo;
            mem_cmd_v_lo = lce_req_header_v_li & lce_req_data_v_li;
            lce_req_data_yumi_lo = mem_cmd_v_lo & mem_cmd_ready_and_li;
            state_n = mem_cmd_stream_done_li ? e_ready : e_data;
          end
          default: begin
          end
        endcase
      end // e_data
      default: begin
        state_n = e_ready;
      end
    endcase
  end // combinational logic

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
    end
  end
  if (lce_data_width_p != mem_data_width_p) begin
    $fatal("LCE and Memory data widths must match");
  end
  //synopsys translate_on


endmodule

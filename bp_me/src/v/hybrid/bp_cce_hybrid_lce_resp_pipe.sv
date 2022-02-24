/**
 *
 * Name:
 *   bp_cce_hybrid_lce_resp_pipe.sv
 *
 * Description:
 *   This module processes LCE responses. Writebacks are automatically forwarded
 *   to the memory command output. Other responses generate control signals that are
 *   routed to other modules in the hybrid CCE.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_lce_resp_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter lce_data_width_p           = dword_width_gp
    , parameter mem_data_width_p           = dword_width_gp
    , parameter header_els_p               = 2

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , output logic                                   lce_resp_header_ready_and_o
   , input                                          lce_resp_has_data_i
   , input [lce_data_width_p-1:0]                   lce_resp_data_i
   , input                                          lce_resp_data_v_i
   , output logic                                   lce_resp_data_ready_and_o
   , input                                          lce_resp_last_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , output logic [cce_mem_header_width_lp-1:0]     mem_cmd_header_o
   , output logic [mem_data_width_p-1:0]            mem_cmd_data_o
   , output logic                                   mem_cmd_v_o
   , input                                          mem_cmd_ready_and_i
   , output logic                                   mem_cmd_last_o

   // Pending bits write port
   // only for coherence ack response
   // memory command arbiter initiates pending write for all memory commands
   , output logic                                   pending_w_v_o
   , input                                          pending_w_yumi_i
   , output logic [paddr_width_p-1:0]               pending_w_addr_o
   , output logic                                   pending_w_addr_bypass_hash_o
   , output logic                                   pending_up_o
   , output logic                                   pending_down_o
   , output logic                                   pending_clear_o

   // Control outputs
   , output logic                                   sync_yumi_o
   , output logic                                   inv_yumi_o
   , output logic                                   coh_yumi_o
   , output logic                                   wb_yumi_o
   );

  // stream pump does not require last signal from input LCE response
  wire unused = lce_resp_last_i;

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

  `bp_cast_i(bp_bedrock_lce_resp_header_s, lce_resp_header);
  `bp_cast_o(bp_bedrock_cce_mem_header_s, mem_cmd_header);

  // LCE Response Header Buffer
  // Required for handshaking since FSM needs to examine valid input to determine whether
  // to raise control signal or consume header
  logic lce_resp_header_v_li, lce_resp_header_yumi_lo, lce_resp_has_data_li;
  bp_bedrock_lce_resp_header_s  lce_resp_header_li;
  bsg_fifo_1r1w_small
    #(.width_p(lce_resp_header_width_lp+1)
      ,.els_p(header_els_p)
      )
    header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      ,.v_i(lce_resp_header_v_i)
      ,.ready_o(lce_resp_header_ready_and_o)
      ,.data_i({lce_resp_has_data_i, lce_resp_header_cast_i})
      // output
      ,.v_o(lce_resp_header_v_li)
      ,.yumi_i(lce_resp_header_yumi_lo)
      ,.data_o({lce_resp_has_data_li, lce_resp_header_li})
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
      ,.msg_header_o(mem_cmd_header_cast_o)
      ,.msg_data_o(mem_cmd_data_o)
      ,.msg_v_o(mem_cmd_v_o)
      ,.msg_last_o(mem_cmd_last_o)
      ,.msg_ready_and_i(mem_cmd_ready_and_i)
      // from LCE response pipe
      ,.fsm_base_header_i(mem_cmd_base_header_lo)
      ,.fsm_data_i(mem_cmd_data_lo)
      ,.fsm_v_i(mem_cmd_v_lo)
      ,.fsm_ready_and_o(mem_cmd_ready_and_li)
      ,.fsm_cnt_o(mem_cmd_stream_cnt_li)
      ,.fsm_new_o(mem_cmd_stream_new_li)
      ,.fsm_last_o(/* unused */)
      ,.fsm_done_o(mem_cmd_stream_done_li)
      );

  enum logic {e_ready, e_write_pending} state_n, state_r;
  logic [paddr_width_p-1:0] resp_addr_r, resp_addr_n;
  logic pending_up_not_down_r, pending_up_not_down_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
      resp_addr_r <= '0;
      pending_up_not_down_r <= 1'b0;
    end else begin
      state_r <= state_n;
      resp_addr_r <= resp_addr_n;
      pending_up_not_down_r <= pending_up_not_down_n;
    end
  end

  // Combinational Logic
  always_comb begin
    // state
    state_n = state_r;
    resp_addr_n = resp_addr_r;
    pending_up_not_down_n = pending_up_not_down_r;
    // memory command output
    mem_cmd_base_header_lo = '0;
    mem_cmd_base_header_lo.addr = lce_resp_header_li.addr;
    mem_cmd_base_header_lo.size = lce_resp_header_li.size;
    mem_cmd_base_header_lo.subop = lce_resp_header_li.subop;
    mem_cmd_base_header_lo.msg_type.mem = e_bedrock_mem_wr;
    mem_cmd_base_header_lo.payload.lce_id = lce_resp_header_li.payload.src_id;
    mem_cmd_data_lo = lce_resp_data_i;
    mem_cmd_v_lo = 1'b0;
    // input
    lce_resp_header_yumi_lo = '0;
    lce_resp_data_ready_and_o = '0;
    // control
    sync_yumi_o = 1'b0;
    inv_yumi_o = 1'b0;
    coh_yumi_o = 1'b0;
    wb_yumi_o = 1'b0;

    // pending write port
    pending_w_v_o = 1'b0;
    pending_w_addr_o = resp_addr_r;
    pending_w_addr_bypass_hash_o = 1'b0;
    pending_up_o = 1'b0;
    pending_down_o = 1'b0;
    pending_clear_o = 1'b0;

    unique case (state_r)
      e_ready: begin
        // all responses except wb are sunk
        // wb is forwarded to memory command output
        unique case (lce_resp_header_li.msg_type)
          e_bedrock_resp_sync_ack: begin
            lce_resp_header_yumi_lo = lce_resp_header_v_li;
            sync_yumi_o = lce_resp_header_yumi_lo;
          end
          e_bedrock_resp_inv_ack: begin
            lce_resp_header_yumi_lo = lce_resp_header_v_li;
            inv_yumi_o = lce_resp_header_yumi_lo;
          end
          e_bedrock_resp_coh_ack: begin
            resp_addr_n = lce_resp_header_li.addr;
            pending_up_not_down_n = 1'b0;
            lce_resp_header_yumi_lo = lce_resp_header_v_li;
            coh_yumi_o = lce_resp_header_yumi_lo;
            state_n = coh_yumi_o ? e_write_pending : state_r;
          end
          e_bedrock_resp_wb: begin
            resp_addr_n = lce_resp_header_li.addr;
            pending_up_not_down_n = 1'b1;
            mem_cmd_v_lo = lce_resp_header_v_li & lce_resp_data_v_i;
            // can only consume if header is valid, too
            lce_resp_data_ready_and_o = lce_resp_header_v_li & mem_cmd_ready_and_li;
            lce_resp_header_yumi_lo = mem_cmd_stream_done_li;
            wb_yumi_o = lce_resp_header_yumi_lo;
            state_n = wb_yumi_o ? e_write_pending : state_r;
          end
          e_bedrock_resp_null_wb: begin
            lce_resp_header_yumi_lo = lce_resp_header_v_li;
            wb_yumi_o = lce_resp_header_yumi_lo;
          end
          default: begin
            // do nothing
          end
        endcase
      end
      e_write_pending: begin
        pending_w_v_o = 1'b1;
        pending_down_o = ~pending_up_not_down_r;
        pending_up_o = pending_up_not_down_r;
        state_n = pending_w_yumi_i ? e_ready : state_r;
      end
      default: begin
        state_n = e_ready;
      end
    endcase
  end // always_comb
endmodule


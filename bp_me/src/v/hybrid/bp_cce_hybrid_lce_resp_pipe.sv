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
    // interface width
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // LCE-CCE Interface
   // BedRock Stream protocol: ready&valid
   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input [bedrock_fill_width_p-1:0]               lce_resp_data_i
   , input                                          lce_resp_v_i
   , output logic                                   lce_resp_ready_and_o

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i

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

  // Define structure variables for output queues
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_lce_resp_header_s, lce_resp_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);

  // LCE Response Stream Pump
  bp_bedrock_lce_resp_header_s fsm_resp_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_resp_data_li;
  logic fsm_resp_v_li, fsm_resp_yumi_lo;
  logic [paddr_width_p-1:0] fsm_resp_addr_li;
  logic fsm_resp_new_li, fsm_resp_critical_li, fsm_resp_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_resp_payload_width_lp)
     ,.msg_stream_mask_p(lce_resp_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_resp_stream_mask_gp)
     )
   lce_resp_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_resp_header_cast_i)
     ,.msg_data_i(lce_resp_data_i)
     ,.msg_v_i(lce_resp_v_i)
     ,.msg_ready_and_o(lce_resp_ready_and_o)

     ,.fsm_header_o(fsm_resp_header_li)
     ,.fsm_data_o(fsm_resp_data_li)
     ,.fsm_v_o(fsm_resp_v_li)
     ,.fsm_yumi_i(fsm_resp_yumi_lo)
     ,.fsm_addr_o(fsm_resp_addr_li)
     ,.fsm_new_o(fsm_resp_new_li)
     ,.fsm_critical_o(fsm_resp_critical_li)
     ,.fsm_last_o(fsm_resp_last_li)
     );

  // Memory Fwd Stream Pump
  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_ready_then_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_li;
  logic fsm_fwd_new_li, fsm_fwd_critical_li, fsm_fwd_last_li;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   fwd_stream_pump
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // to memory command output
     ,.msg_header_o(mem_fwd_header_cast_o)
     ,.msg_data_o(mem_fwd_data_o)
     ,.msg_v_o(mem_fwd_v_o)
     ,.msg_ready_and_i(mem_fwd_ready_and_i)
     // from FSM CCE
     ,.fsm_header_i(fsm_fwd_header_lo)
     ,.fsm_data_i(fsm_fwd_data_lo)
     ,.fsm_v_i(fsm_fwd_v_lo)
     ,.fsm_ready_then_o(fsm_fwd_ready_then_li)
     ,.fsm_addr_o(fsm_fwd_addr_li)
     ,.fsm_new_o(fsm_fwd_new_li)
     ,.fsm_critical_o(fsm_fwd_critical_li)
     ,.fsm_last_o(fsm_fwd_last_li)
     );

  // FSM states
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
    fsm_fwd_header_lo = '0;
    fsm_fwd_header_lo.addr = fsm_resp_header_li.addr;
    fsm_fwd_header_lo.size = fsm_resp_header_li.size;
    fsm_fwd_header_lo.subop = fsm_resp_header_li.subop;
    fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_wr;
    fsm_fwd_header_lo.payload.src_did =fsm_resp_header_li.payload.src_did;
    fsm_fwd_header_lo.payload.lce_id = fsm_resp_header_li.payload.src_id;
    fsm_fwd_data_lo = fsm_resp_data_li;
    fsm_fwd_v_lo = 1'b0;

    // LCE response input
    fsm_resp_yumi_lo = '0;

    // control outputs
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
        unique case (fsm_resp_header_li.msg_type)
          e_bedrock_resp_sync_ack: begin
            fsm_resp_yumi_lo = fsm_resp_v_li;
            sync_yumi_o = fsm_resp_yumi_lo;
          end
          e_bedrock_resp_inv_ack: begin
            fsm_resp_yumi_lo = fsm_resp_v_li;
            inv_yumi_o = fsm_resp_yumi_lo;
          end
          e_bedrock_resp_coh_ack: begin
            resp_addr_n = fsm_resp_header_li.addr;
            pending_up_not_down_n = 1'b0;
            fsm_resp_yumi_lo = fsm_resp_v_li;
            coh_yumi_o = fsm_resp_yumi_lo;
            state_n = coh_yumi_o ? e_write_pending : state_r;
          end
          e_bedrock_resp_wb: begin
            resp_addr_n = fsm_resp_header_li.addr;
            pending_up_not_down_n = 1'b1;
            fsm_fwd_v_lo = fsm_resp_v_li & fsm_fwd_ready_then_li;
            fsm_resp_yumi_lo = fsm_fwd_v_lo;
            wb_yumi_o = fsm_resp_yumi_lo & fsm_resp_last_li;
            state_n = wb_yumi_o ? e_write_pending : state_r;
          end
          e_bedrock_resp_null_wb: begin
            fsm_resp_yumi_lo = fsm_resp_v_li;
            wb_yumi_o = fsm_resp_yumi_lo;
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


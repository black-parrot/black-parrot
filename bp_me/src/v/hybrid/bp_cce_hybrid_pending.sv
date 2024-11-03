/**
 *
 * Name:
 *   bp_cce_hybrid_pending.sv
 *
 * Description:
 *   Pending bit read stage and pending queue management.
 *
 *   New requests arrive on the lce_req_*_i interface. Blocked requests are stored
 *   in the pending queue.
 *
 *   FSM logic:
 *   if pending queue not blocked, send pending request to output
 *   else if new request not blocked, send new request to output
 *   else if new request blocked, send to pending queue
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_pending
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter buffer_els_p     = 2

    , localparam num_way_groups_lp = `BSG_CDIV(cce_way_groups_p, num_cce_p)

    // interface width
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i
   , input [cce_id_width_p-1:0]                     cce_id_i

   // LCE Request
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o

   // Uncached or Cached to cacheable memory
   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
   , output logic                                   lce_req_v_o
   , input                                          lce_req_ready_and_i

   // Pending bit write port
   , input                                          pending_w_v_i
   , output logic                                   pending_w_yumi_o
   , input [paddr_width_p-1:0]                      pending_w_addr_i
   , input                                          pending_w_addr_bypass_hash_i
   , input                                          pending_up_i
   , input                                          pending_down_i
   , input                                          pending_clear_i

   // control output
   , output logic                                   empty_o
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);

  // LCE Request Stream Pump
  bp_bedrock_lce_req_header_s fsm_req_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_req_data_li;
  logic fsm_req_v_li, fsm_req_yumi_lo;
  logic [paddr_width_p-1:0] fsm_req_addr_li;
  logic fsm_req_new_li, fsm_req_critical_li, fsm_req_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.msg_stream_mask_p(lce_req_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_req_stream_mask_gp)
     )
   lce_req_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_req_header_cast_i)
     ,.msg_data_i(lce_req_data_i)
     ,.msg_v_i(lce_req_v_i)
     ,.msg_ready_and_o(lce_req_ready_and_o)

     ,.fsm_header_o(fsm_req_header_li)
     ,.fsm_data_o(fsm_req_data_li)
     ,.fsm_v_o(fsm_req_v_li)
     ,.fsm_yumi_i(fsm_req_yumi_lo)
     ,.fsm_addr_o(fsm_req_addr_li)
     ,.fsm_new_o(fsm_req_new_li)
     ,.fsm_critical_o(fsm_req_critical_li)
     ,.fsm_last_o(fsm_req_last_li)
     );

  // Pending Queue
  logic pending_v_li, pending_ready_and_lo;
  logic pending_v_lo, pending_yumi_li;
  logic pending_last_li, pending_last_lo;
  bp_bedrock_lce_req_header_s pending_header_li, pending_header_lo;
  logic [bedrock_fill_width_p-1:0] pending_data_li, pending_data_lo;
  bp_cce_hybrid_pending_queue
    #(.bp_params_p(bp_params_p)
      ,.buffer_els_p(buffer_els_p)
      )
    pending_queue
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // in
      ,.lce_req_header_i(pending_header_li)
      ,.lce_req_data_i(pending_data_li)
      ,.lce_req_v_i(pending_v_li)
      ,.lce_req_last_i(pending_last_li)
      ,.lce_req_ready_and_o(pending_ready_and_lo)
      // out
      ,.lce_req_header_o(pending_header_lo)
      ,.lce_req_data_o(pending_data_lo)
      ,.lce_req_v_o(pending_v_lo)
      ,.lce_req_last_o(pending_last_lo)
      ,.lce_req_yumi_i(pending_yumi_li)
      );

  assign empty_o = ~pending_v_lo & ~fsm_req_v_li;

  // Pending Bits
  logic                     pending_w_v_li;
  logic [paddr_width_p-1:0] pending_w_addr_li;
  logic                     pending_w_addr_bypass_hash_li;
  logic                     pending_up_li;
  logic                     pending_down_li;
  logic                     pending_clear_li;
  logic fsm_req_pending_lo, pending_queue_pending_lo;
  bp_cce_hybrid_pending_bits
    #(.num_way_groups_p(num_way_groups_lp)
      ,.cce_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.cce_id_width_p(cce_id_width_p)
      ,.block_width_p(bedrock_block_width_p)
     )
    pending_bits
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.cce_id_i(cce_id_i)
      // write port - from internal or external
      ,.w_v_i(pending_w_v_li)
      ,.w_addr_i(pending_w_addr_li)
      ,.w_addr_bypass_hash_i(pending_w_addr_bypass_hash_li)
      ,.up_i(pending_up_li)
      ,.down_i(pending_down_li)
      ,.clear_i(pending_clear_li)
      // read port A - new LCE requests
      ,.ra_v_i(fsm_req_v_li)
      ,.ra_addr_i(fsm_req_header_li.addr)
      ,.ra_addr_bypass_hash_i('0)
      ,.pending_a_o(fsm_req_pending_lo)
      // read port B - pending queue
      ,.rb_v_i(pending_v_lo)
      ,.rb_addr_i(pending_header_lo.addr)
      ,.rb_addr_bypass_hash_i('0)
      ,.pending_b_o(pending_queue_pending_lo)
      );

  enum logic [1:0] {e_ready, e_pending_to_out, e_req_to_out, e_req_to_pending} state_r, state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  // Combinational Logic
  always_comb begin
    // state
    state_n = state_r;

    // Request stream pump
    fsm_req_yumi_lo = 1'b0;

    // output - from either pending queue or stream pump
    // default to from stream pump
    lce_req_header_cast_o = fsm_req_header_li;
    lce_req_data_o = fsm_req_data_li;
    lce_req_v_o = 1'b0;

    // pending queue input - from stream pump
    pending_v_li = 1'b0;
    pending_header_li = fsm_req_header_li;
    pending_data_li = fsm_req_data_li;
    pending_last_li = fsm_req_last_li;

    // pending queue output
    pending_yumi_li = 1'b0;

    // pending write
    // external writes accepted by default, but lower priority than this FSM
    // FSM sets pending_w_yumi_o to 0 as needed to block external write
    pending_w_v_li = pending_w_v_i;
    pending_w_yumi_o = pending_w_v_i;
    pending_w_addr_li = pending_w_addr_i;
    pending_w_addr_bypass_hash_li = pending_w_addr_bypass_hash_i;
    pending_up_li = pending_up_i;
    pending_down_li = pending_down_i;
    pending_clear_li = pending_clear_i;

    unique case (state_r)
      // pick operation, write pending bit if required
      // pending bit is written only when preparing to send a message to output
      // this state does not forward any message beats
      e_ready: begin
        // send pending queue to output if no longer blocked
        if (pending_v_lo & ~pending_queue_pending_lo & lce_req_ready_and_i) begin
          state_n = e_pending_to_out;
          // block external pending write
          pending_w_yumi_o = 1'b0;
          // perform internal pending write
          pending_w_v_li = 1'b1;
          pending_w_addr_li = pending_header_lo.addr;
          pending_w_addr_bypass_hash_li = 1'b0;
          pending_up_li = 1'b1;
          pending_down_li = 1'b0;
          pending_clear_li = 1'b0;
        end
        // send new request to output if not blocked
        else if (fsm_req_v_li & ~fsm_req_pending_lo & lce_req_ready_and_i) begin
          state_n = e_req_to_out;
          // block external pending write
          pending_w_yumi_o = 1'b0;
          // perform internal pending write
          pending_w_v_li = 1'b1;
          pending_w_addr_li = fsm_req_header_li.addr;
          pending_w_addr_bypass_hash_li = 1'b0;
          pending_up_li = 1'b1;
          pending_down_li = 1'b0;
          pending_clear_li = 1'b0;
        end
        // send new request to pending if blocked
        else if (fsm_req_v_li & fsm_req_pending_lo & pending_ready_and_lo) begin
          state_n = e_req_to_pending;
        end
      end
      // forward from pending queue to output
      e_pending_to_out: begin
        // header and data
        lce_req_header_cast_o = pending_header_lo;
        lce_req_data_o = pending_data_lo;
        // handshake
        lce_req_v_o = pending_v_lo;
        pending_yumi_li = lce_req_v_o & lce_req_ready_and_i;
        // next state
        state_n = (pending_yumi_li & pending_last_lo)
                  ? e_ready
                  : state_r;
      end
      // forward from input (stream pump) to output
      e_req_to_out: begin
        // header and data
        lce_req_header_cast_o = fsm_req_header_li;
        lce_req_data_o = fsm_req_data_li;
        // handshake
        lce_req_v_o = fsm_req_v_li;
        fsm_req_yumi_lo = lce_req_v_o & lce_req_ready_and_i;
        // next state
        state_n = (fsm_req_yumi_lo & fsm_req_last_li)
                  ? e_ready
                  : state_r;
      end
      // forward from input (stream pump) to pending queue
      e_req_to_pending: begin
        // header and data
        // set by defaults
        // handshake
        pending_v_li = fsm_req_v_li;
        fsm_req_yumi_lo = fsm_req_v_li & pending_ready_and_lo;
        // next state
        state_n = (fsm_req_yumi_lo & fsm_req_last_li)
                  ? e_ready
                  : state_r;
      end
      default: begin
        state_n = e_ready;
      end
    endcase // case (state_r)
  end // combinational logic

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
    end
  end
  //synopsys translate_on

endmodule

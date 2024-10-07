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
 *   FSM finishes sending data for requests with data before processing next header from new
 *   request input or pending queue.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_pending
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter lce_data_width_p = dword_width_gp
    , parameter header_els_p     = 2
    , parameter data_els_p       = 2

    , localparam num_way_groups_lp = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
  )
  (input                                            clk_i
   , input                                          reset_i
   , input [cce_id_width_p-1:0]                     cce_id_i

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

   // Uncached or Cached to cacheable memory
   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic                                   lce_req_header_v_o
   , input                                          lce_req_header_ready_and_i
   , output logic                                   lce_req_has_data_o
   , output logic [lce_data_width_p-1:0]            lce_req_data_o
   , output logic                                   lce_req_data_v_o
   , input                                          lce_req_data_ready_and_i
   , output logic                                   lce_req_last_o

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

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);

  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);

  // Pending Queue
  logic pending_header_v_li, pending_header_ready_and_lo;
  logic pending_header_v_lo, pending_header_yumi_li;
  logic pending_has_data_li, pending_has_data_lo;
  logic pending_data_v_li, pending_data_ready_and_lo;
  logic pending_data_v_lo, pending_data_yumi_li;
  logic pending_last_li, pending_last_lo;
  logic pending_full_lo;
  bp_bedrock_lce_req_header_s pending_header_li, pending_header_lo;
  logic [lce_data_width_p-1:0] pending_data_li, pending_data_lo;
  // input to pending queue comes from new LCE request input
  assign pending_header_li = lce_req_header_cast_i;
  assign pending_data_li = lce_req_data_i;
  assign pending_has_data_li = lce_req_has_data_i;
  assign pending_last_li = lce_req_last_i;
  bp_cce_hybrid_pending_queue
    #(.bp_params_p(bp_params_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.header_els_p(header_els_p)
      ,.data_els_p(data_els_p)
      )
    pending_queue
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.lce_req_header_i(pending_header_li)
      ,.lce_req_header_v_i(pending_header_v_li)
      ,.lce_req_header_ready_and_o(pending_header_ready_and_lo)
      ,.lce_req_has_data_i(pending_has_data_li)
      ,.lce_req_data_i(pending_data_li)
      ,.lce_req_data_v_i(pending_data_v_li)
      ,.lce_req_data_ready_and_o(pending_data_ready_and_lo)
      ,.lce_req_last_i(pending_last_li)
      ,.full_o(pending_full_lo)
      ,.lce_req_header_o(pending_header_lo)
      ,.lce_req_header_v_o(pending_header_v_lo)
      ,.lce_req_header_yumi_i(pending_header_yumi_li)
      ,.lce_req_has_data_o(pending_has_data_lo)
      ,.lce_req_data_o(pending_data_lo)
      ,.lce_req_data_v_o(pending_data_v_lo)
      ,.lce_req_data_yumi_i(pending_data_yumi_li)
      ,.lce_req_last_o(pending_last_lo)
      );
  assign empty_o = ~pending_header_v_lo & ~pending_data_v_lo;

  // Pending Bits
  logic                     pending_w_v_li;
  logic [paddr_width_p-1:0] pending_w_addr_li;
  logic                     pending_w_addr_bypass_hash_li;
  logic                     pending_up_li;
  logic                     pending_down_li;
  logic                     pending_clear_li;
  logic pending_a_lo, pending_b_lo;
  bp_cce_hybrid_pending_bits
    #(.num_way_groups_p(num_way_groups_lp)
      ,.cce_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.addr_offset_p(lg_block_size_in_bytes_lp)
      ,.cce_id_width_p(cce_id_width_p)
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
      ,.ra_v_i(lce_req_header_v_i)
      ,.ra_addr_i(lce_req_header_cast_i.addr)
      ,.ra_addr_bypass_hash_i('0)
      ,.pending_a_o(pending_a_lo)
      // read port B - pending queue
      ,.rb_v_i(pending_header_v_lo)
      ,.rb_addr_i(pending_header_lo.addr)
      ,.rb_addr_bypass_hash_i('0)
      ,.pending_b_o(pending_b_lo)
      );

  logic pending_not_lce_en_li;
  logic pending_not_lce_n, pending_not_lce_r;
  bsg_dff_reset_en
    #(.width_p(1)
      ,.reset_val_p(0)
      )
    arbiter_dff
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(pending_not_lce_en_li)
      ,.data_i(pending_not_lce_n)
      ,.data_o(pending_not_lce_r)
      );

  enum logic [1:0] {e_ready, e_data_to_out, e_data_to_pending} state_r, state_n;

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
    // input
    lce_req_header_ready_and_o = 1'b0;
    lce_req_data_ready_and_o = 1'b0;
    // output
    lce_req_header_cast_o = '0;
    lce_req_header_v_o = 1'b0;
    lce_req_has_data_o = 1'b0;
    lce_req_data_o = '0;
    lce_req_data_v_o = 1'b0;
    lce_req_last_o = 1'b0;
    // pending queue input
    pending_header_v_li = 1'b0;
    pending_data_v_li = 1'b0;
    // pending queue output
    pending_header_yumi_li = 1'b0;
    pending_data_yumi_li = 1'b0;
    // arbitration
    pending_not_lce_n = 1'b0;
    pending_not_lce_en_li = 1'b0;
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
      // process header from new input or pending queue
      e_ready: begin
        // send pending queue to output if no longer blocked
        if (pending_header_v_lo & ~pending_b_lo) begin
          pending_not_lce_en_li = 1'b1;
          pending_not_lce_n = 1'b1;
          lce_req_header_cast_o = pending_header_lo;
          lce_req_header_v_o = pending_header_v_lo;
          lce_req_has_data_o = pending_has_data_lo;
          pending_header_yumi_li = lce_req_header_v_o & lce_req_header_ready_and_i;
          // write pending bits only if message is actually sending
          if (pending_header_yumi_li) begin
            pending_w_v_li = pending_header_yumi_li;
            pending_w_addr_li = pending_header_lo.addr;
            pending_w_addr_bypass_hash_li = 1'b0;
            pending_up_li = 1'b1;
            pending_down_li = 1'b0;
            pending_clear_li = 1'b0;
            pending_w_yumi_o = 1'b0;
          end
          state_n = (lce_req_header_v_o & lce_req_header_ready_and_i & lce_req_has_data_o)
                    ? e_data_to_out
                    : state_r;
        end
        // send new request to output if not blocked
        else if (lce_req_header_v_i & ~pending_a_lo) begin
          pending_not_lce_en_li = 1'b1;
          lce_req_header_cast_o = lce_req_header_cast_i;
          lce_req_header_v_o = lce_req_header_v_i;
          lce_req_has_data_o = lce_req_has_data_i;
          lce_req_header_ready_and_o = lce_req_header_ready_and_i;
          // write pending bits only if message is actually sending
          if (lce_req_header_ready_and_i) begin
            pending_w_v_li = lce_req_header_v_o & lce_req_header_ready_and_o;
            pending_w_addr_li = lce_req_header_cast_i.addr;
            pending_w_addr_bypass_hash_li = 1'b0;
            pending_up_li = 1'b1;
            pending_down_li = 1'b0;
            pending_clear_li = 1'b0;
            pending_w_yumi_o = 1'b0;
          end
          state_n = (lce_req_header_v_o & lce_req_header_ready_and_i & lce_req_has_data_o)
                    ? e_data_to_out
                    : state_r;
        end
        // send new request to pending if blocked
        else if (lce_req_header_v_i & pending_a_lo) begin
          pending_header_v_li = lce_req_header_v_i;
          lce_req_header_ready_and_o = pending_header_ready_and_lo;
          state_n = (pending_header_v_li & pending_header_ready_and_lo & pending_has_data_li)
                    ? e_data_to_pending
                    : state_r;
        end
      end
      // send data from new input or pending queue to output
      e_data_to_out: begin
        // from pending queue
        if (pending_not_lce_r) begin
          lce_req_data_o = pending_data_lo;
          lce_req_data_v_o = pending_data_v_lo;
          lce_req_last_o = pending_last_lo;
          pending_data_yumi_li = lce_req_data_v_o & lce_req_data_ready_and_i;
        end
        // from new request input
        else begin
          lce_req_data_o = lce_req_data_i;
          lce_req_data_v_o = lce_req_data_v_i;
          lce_req_last_o = lce_req_last_i;
          lce_req_data_ready_and_o = lce_req_data_ready_and_i;
        end
        // back to ready after last beat sends
        state_n = (lce_req_data_v_o & lce_req_data_ready_and_i & lce_req_last_o)
                  ? e_ready
                  : state_r;
      end
      // send data from new input to pending queue
      e_data_to_pending: begin
        pending_data_v_li = lce_req_data_v_i;
        lce_req_data_ready_and_o = pending_data_ready_and_lo;
        state_n = (pending_data_v_li & pending_data_ready_and_lo & pending_last_li)
                  ? e_ready
                  : state_r;
      end
      default: begin
        state_n = e_ready;
      end
    endcase // state_r
  end // combinational logic

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
    end
  end
  //synopsys translate_on

endmodule

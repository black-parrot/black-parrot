/**
 *
 * Name:
 *   bp_cce_pending.v
 *
 * Description:
 *   This module contains the pending bits.
 *
 *   The pending bits are stored in flops and may be read asynchronously.
 *
 *   Write to Read forwarding is supported.
 *
 *   Pending bits are actually small counters. The pending bit is unset if the count is 0, and
 *   set if the count is > 0.
 *
 *   NOTE: pending bit count can over/underflow.
 *
 */

module bp_cce_pending
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_way_groups_p            = "inv"

    // Default parameters
    , parameter width_p                   = 2

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)

  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input                                                        w_v_i
   , input [lg_num_way_groups_lp-1:0]                             w_way_group_i
   , input                                                        pending_i

   , input                                                        r_v_i
   , input [lg_num_way_groups_lp-1:0]                             r_way_group_i

   , output logic                                                 pending_o
   , output logic                                                 pending_v_o

  );

  // pending bits
  logic [num_way_groups_p-1:0][width_p-1:0] pending_bits_r, pending_bits_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pending_bits_r <= '0;
    end else begin
      pending_bits_r <= pending_bits_n;
    end
  end

  always_comb begin
    if (reset_i) begin
      pending_bits_n = '0;
    end else begin
      pending_bits_n = pending_bits_r;
      if (w_v_i) begin
        if (pending_i) begin // increment count
          pending_bits_n[w_way_group_i] = pending_bits_r[w_way_group_i] + 'd1;
        end else begin // decrement count
          pending_bits_n[w_way_group_i] = pending_bits_r[w_way_group_i] - 'd1;
        end
      end
    end
  end

  // Pending bit output
  // Normally, the output is determined by the read way group and comes from the flopped values
  // If reading from the same way group that is being written, output the next value
  assign pending_o = (r_v_i & w_v_i & (w_way_group_i == r_way_group_i))
    ? ~(pending_bits_n[r_way_group_i] == 0)
    : ~(pending_bits_r[r_way_group_i] == 0);

  // Output is valid if read signal is asserted
  assign pending_v_o = r_v_i;

endmodule

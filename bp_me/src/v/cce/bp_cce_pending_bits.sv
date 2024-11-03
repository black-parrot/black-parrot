/**
 *
 * Name:
 *   bp_cce_pending_bits.sv
 *
 * Description:
 *   This module contains the pending bits. Pending bits are actually small counters.
 *   The pending bit is unset if the count is 0, and set if the count is > 0.
 *
 *   The pending bits are stored in flops and may be read asynchronously. Write to Read
 *   forwarding is supported. If both clear_i and pending_i are asserted, only the clear
 *   to 0 is processed.
 *
 *   WARNING: the pending bit counters do not saturate and may over/underflow. Be careful!
 *
 *   cce_way_groups_p is the total number of way groups in the system.
 *   num_way_groups_p is the number of way groups managed by this CCE.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_pending_bits
  import bp_common_pkg::*;
  #(parameter `BSG_INV_PARAM(num_way_groups_p)
    , parameter `BSG_INV_PARAM(cce_way_groups_p)
    , parameter `BSG_INV_PARAM(num_cce_p)
    , parameter `BSG_INV_PARAM(paddr_width_p)
    , parameter `BSG_INV_PARAM(cce_id_width_p)
    , parameter `BSG_INV_PARAM(block_width_p)

    // Default parameters
    , parameter width_p = 3  // pending bit counter width

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam lg_cce_way_groups_lp     = `BSG_SAFE_CLOG2(cce_way_groups_p)
  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input                                                        w_v_i
   , input [paddr_width_p-1:0]                                    w_addr_i
   , input                                                        w_addr_bypass_hash_i
   , input                                                        pending_i
   , input                                                        clear_i

   , input                                                        r_v_i
   , input [paddr_width_p-1:0]                                    r_addr_i
   , input                                                        r_addr_bypass_hash_i

   , output logic                                                 pending_o

   // Debug
   , input [cce_id_width_p-1:0]                                   cce_id_i
  );

  // Address to way group hashing
  logic [lg_num_way_groups_lp-1:0] r_wg_lo, w_wg_lo;
  logic [lg_num_way_groups_lp-1:0] r_wg, w_wg;

  bp_me_addr_to_cce_wg_id
    #(.paddr_width_p(paddr_width_p)
      ,.num_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.block_width_p(block_width_p)
      ,.dir_sets_p(1)
      )
    r_addr_hash
     (.addr_i(r_addr_i)
      ,.cce_id_o()
      ,.wg_id_o()
      ,.dir_set_id_o()
      ,.dir_wg_id_o(r_wg_lo)
      );

  bp_me_addr_to_cce_wg_id
    #(.paddr_width_p(paddr_width_p)
      ,.num_way_groups_p(cce_way_groups_p)
      ,.num_cce_p(num_cce_p)
      ,.block_width_p(block_width_p)
      ,.dir_sets_p(1)
      )
    w_addr_hash
     (.addr_i(w_addr_i)
      ,.cce_id_o()
      ,.wg_id_o()
      ,.dir_set_id_o()
      ,.dir_wg_id_o(w_wg_lo)
      );

  assign r_wg = (r_addr_bypass_hash_i) ? r_addr_i[0+:lg_num_way_groups_lp]
                                       : r_wg_lo[0+:lg_num_way_groups_lp];
  assign w_wg = (w_addr_bypass_hash_i) ? w_addr_i[0+:lg_num_way_groups_lp]
                                       : w_wg_lo[0+:lg_num_way_groups_lp];

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
    pending_bits_n = pending_bits_r;
    if (w_v_i) begin
      if (clear_i) begin
        pending_bits_n[w_wg] = '0;
      end
      else begin
        if (pending_i) begin // increment count
          pending_bits_n[w_wg] = pending_bits_r[w_wg] + 'd1;
        end else begin // decrement count
          pending_bits_n[w_wg] = pending_bits_r[w_wg] - 'd1;
        end
      end
    end
  end

  // Pending bit output
  // Normally, the output is determined by the read way group and comes from the flopped values
  // If reading from the same way group that is being written, output the next value
  assign pending_o = (r_v_i & w_v_i & (w_wg == r_wg))
    ? ~(pending_bits_n[r_wg] == 0)
    : ~(pending_bits_r[r_wg] == 0);

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_pending_bits)

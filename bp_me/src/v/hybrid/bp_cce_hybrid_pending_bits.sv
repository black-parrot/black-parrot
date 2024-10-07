/**
 *
 * Name:
 *   bp_cce_hybrid_pending_bits.sv
 *
 * Description:
 *   This module contains the pending bits. Pending bits are actually small counters.
 *   The pending bit is unset if the count is 0, and set if the count is > 0.
 *
 *   There are two read ports and a single write port. Writes are NOT forwarded to reads
 *   that occur in the same cycle.
 *
 *   The pending bits are stored in flops and may be read asynchronously.
 *   If both clear_i and up_i are asserted the up happens after clear.
 *
 *   WARNING: the pending bit counters do not saturate and may over/underflow. Be careful!
 *
 *   The width of address into bsg_hash_bank is log2(cce_way_groups_p), where cce_way_groups_p
 *   is the total number of way groups in the system.
 *   num_way_groups_p is the number of way groups managed by this CCE (or that number
 *   plus one in the event that there is not an even number of way groups per CCE).
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_pending_bits
  import bp_common_pkg::*;
  #(parameter `BSG_INV_PARAM(num_way_groups_p)
    , parameter `BSG_INV_PARAM(cce_way_groups_p)
    , parameter `BSG_INV_PARAM(num_cce_p)
    , parameter `BSG_INV_PARAM(paddr_width_p)
    , parameter `BSG_INV_PARAM(addr_offset_p)
    , parameter `BSG_INV_PARAM(cce_id_width_p)

    // Default parameters
    // pending bit counter width
    , parameter width_p                   = 3

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam lg_cce_way_groups_lp     = `BSG_SAFE_CLOG2(cce_way_groups_p)
    // formula comes from bsg_hash_bank module
    , localparam hash_idx_width_lp = $clog2((2**lg_cce_way_groups_lp+num_cce_p-1)/num_cce_p)

  )
  (input                                                          clk_i
   , input                                                        reset_i
   , input [cce_id_width_p-1:0]                                   cce_id_i

   , input                                                        w_v_i
   , input [paddr_width_p-1:0]                                    w_addr_i
   , input                                                        w_addr_bypass_hash_i
   , input                                                        up_i
   , input                                                        down_i
   , input                                                        clear_i

   , input                                                        ra_v_i
   , input [paddr_width_p-1:0]                                    ra_addr_i
   , input                                                        ra_addr_bypass_hash_i
   , output logic                                                 pending_a_o

   , input                                                        rb_v_i
   , input [paddr_width_p-1:0]                                    rb_addr_i
   , input                                                        rb_addr_bypass_hash_i
   , output logic                                                 pending_b_o
  );

  // Pending Bits Registers
  logic [num_way_groups_p-1:0][width_p-1:0] pending_bits_r, pending_bits_n;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pending_bits_r <= '0;
    end else begin
      pending_bits_r <= pending_bits_n;
    end
  end

  // Read port A
  logic [hash_idx_width_lp-1:0] ra_wg_lo;
  // The address to use as input starts at addr_offset_p and is lg_cce_way_groups_lp bits in length
  wire [lg_cce_way_groups_lp-1:0] ra_addr_rev = {<< {ra_addr_i[addr_offset_p+:lg_cce_way_groups_lp]}};
  logic [lg_num_way_groups_lp-1:0] ra_wg;

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_cce_way_groups_lp) // width of address input
      )
    ra_addr_hash
     (.i(ra_addr_rev)
      ,.bank_o()
      ,.index_o(ra_wg_lo)
      );

  assign ra_wg = (ra_addr_bypass_hash_i) ? ra_addr_i[0+:lg_num_way_groups_lp]
                                         : ra_wg_lo[0+:lg_num_way_groups_lp];
  assign pending_a_o = ra_v_i ? ~(pending_bits_r[ra_wg] == 0) : 1'b0;


  // Read port B
  logic [hash_idx_width_lp-1:0] rb_wg_lo;
  // The address to use as input starts at addr_offset_p and is lg_cce_way_groups_lp bits in length
  wire [lg_cce_way_groups_lp-1:0] rb_addr_rev = {<< {rb_addr_i[addr_offset_p+:lg_cce_way_groups_lp]}};
  logic [lg_num_way_groups_lp-1:0] rb_wg;

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_cce_way_groups_lp) // width of address input
      )
    rb_addr_hash
     (.i(rb_addr_rev)
      ,.bank_o()
      ,.index_o(rb_wg_lo)
      );

  assign rb_wg = (rb_addr_bypass_hash_i) ? rb_addr_i[0+:lg_num_way_groups_lp]
                                         : rb_wg_lo[0+:lg_num_way_groups_lp];
  assign pending_b_o = rb_v_i ? ~(pending_bits_r[rb_wg] == 0) : 1'b0;

  // Write Port
  logic [hash_idx_width_lp-1:0] w_wg_lo;
  wire [lg_cce_way_groups_lp-1:0] w_addr_rev = {<< {w_addr_i[addr_offset_p+:lg_cce_way_groups_lp]}};
  logic [lg_num_way_groups_lp-1:0] w_wg;

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_cce_way_groups_lp) // width of address input
      )
    w_addr_hash
     (.i(w_addr_rev)
      ,.bank_o()
      ,.index_o(w_wg_lo)
      );

  assign w_wg = (w_addr_bypass_hash_i) ? w_addr_i[0+:lg_num_way_groups_lp]
                                       : w_wg_lo[0+:lg_num_way_groups_lp];

  // write combinational logic
  always_comb begin
    pending_bits_n = pending_bits_r;
    if (w_v_i) begin
      if (clear_i) begin
        if (up_i) begin
          pending_bits_n[w_wg] = 'd1;
        end else begin
          pending_bits_n[w_wg] = '0;
        end
      end
      else begin
        if (up_i) begin // increment count
          pending_bits_n[w_wg] = pending_bits_r[w_wg] + 'd1;
        end else if (down_i) begin // decrement count
          pending_bits_n[w_wg] = pending_bits_r[w_wg] - 'd1;
        end
      end
    end
  end

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      assert(!(w_v_i & clear_i & down_i)) else
        $error("%12t |: pending bit decrement lost - clear occurred", $time);
      assert(!(w_v_i & !(clear_i | up_i | down_i))) else
        $error("%12t |: pending bit write with no clear, up, or down detected", $time);
      assert(!(w_v_i & up_i & (pending_bits_r[w_wg] == '1))) else
        $error("%12t |: pending bit write overflow detected wg[%d]", $time, w_wg);
      assert(!(w_v_i & down_i & (pending_bits_r[w_wg] == '0))) else
        $error("%12t |: pending bit write underflow detected wg[%d]", $time, w_wg);
    end
  end
  //synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_hybrid_pending_bits)

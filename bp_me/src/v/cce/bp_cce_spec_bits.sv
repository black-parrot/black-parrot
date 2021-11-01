/**
 *
 * Name:
 *   bp_cce_spec_bits.sv
 *
 * Description:
 *   This module contains the metadata required for speculative memory accesses.
 *
 *   These bits are stored in flops and may be read asynchronously.
 *
 *   The width of address into bsg_hash_bank is log2(cce_way_groups_p), where cce_way_groups_p
 *   is the total number of way groups in the system.
 *   num_way_groups_p is the number of way groups managed by this CCE (or that number
 *   plus one in the event that there is not an even number of way groups per CCE).
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_spec_bits
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter `BSG_INV_PARAM(num_way_groups_p)
    , parameter `BSG_INV_PARAM(cce_way_groups_p)
    , parameter `BSG_INV_PARAM(num_cce_p)
    , parameter `BSG_INV_PARAM(paddr_width_p)
    , parameter `BSG_INV_PARAM(addr_offset_p)

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam lg_cce_way_groups_lp     = `BSG_SAFE_CLOG2(cce_way_groups_p)
    , localparam hash_idx_width_lp = $clog2((2**lg_cce_way_groups_lp+num_cce_p-1)/num_cce_p)

  )
  (input                                                          clk_i
   , input                                                        reset_i

   // Write port
   , input                                                        w_v_i
   , input [paddr_width_p-1:0]                                    w_addr_i
   , input                                                        w_addr_bypass_hash_i

   , input                                                        spec_v_i
   , input                                                        squash_v_i
   , input                                                        fwd_mod_v_i
   , input                                                        state_v_i
   , input bp_cce_spec_s                                          spec_i

   // Read port
   , input                                                        r_v_i
   , input [paddr_width_p-1:0]                                    r_addr_i
   , input                                                        r_addr_bypass_hash_i

   , output bp_cce_spec_s                                         spec_o

  );

  // Address to way group hashing
  logic [hash_idx_width_lp-1:0] r_wg_lo, w_wg_lo;
  wire [lg_cce_way_groups_lp-1:0] r_addr_rev = {<< {r_addr_i[addr_offset_p+:lg_cce_way_groups_lp]}};
  wire [lg_cce_way_groups_lp-1:0] w_addr_rev = {<< {w_addr_i[addr_offset_p+:lg_cce_way_groups_lp]}};
  logic [lg_num_way_groups_lp-1:0] r_wg, w_wg;

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_cce_way_groups_lp) // width of address input
      )
    r_addr_hash
     (.i(r_addr_rev)
      ,.bank_o()
      ,.index_o(r_wg_lo)
      );

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_cce_way_groups_lp) // width of address input
      )
    w_addr_hash
     (.i(w_addr_rev)
      ,.bank_o()
      ,.index_o(w_wg_lo)
      );

  assign r_wg = (r_addr_bypass_hash_i) ? r_addr_i[0+:lg_num_way_groups_lp]
                                       : r_wg_lo[0+:lg_num_way_groups_lp];
  assign w_wg = (w_addr_bypass_hash_i) ? w_addr_i[0+:lg_num_way_groups_lp]
                                       : w_wg_lo[0+:lg_num_way_groups_lp];

  // speculation metadata bits
  bp_cce_spec_s [num_way_groups_p-1:0] spec_bits_r, spec_bits_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      spec_bits_r <= '0;
    end else begin
      spec_bits_r <= spec_bits_n;
    end
  end

  always_comb begin
    if (reset_i) begin
      spec_bits_n = '0;
    end else begin
      spec_bits_n = spec_bits_r;
      if (w_v_i) begin
        if (spec_v_i) begin
          spec_bits_n[w_wg].spec = spec_i.spec;
        end
        if (squash_v_i) begin
          spec_bits_n[w_wg].squash = spec_i.squash;
        end
        if (fwd_mod_v_i) begin
          spec_bits_n[w_wg].fwd_mod = spec_i.fwd_mod;
        end
        if (state_v_i) begin
          spec_bits_n[w_wg].state = spec_i.state;
        end
      end
    end
  end

  // Output
  wire unused0 = r_v_i;
  assign spec_o = spec_bits_r[r_wg];

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_spec_bits)

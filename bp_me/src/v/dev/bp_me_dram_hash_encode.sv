/*
 * Name:
 *   bp_me_dram_hash_encode.sv
 *
 * Description:
 *   This module swizzles bits in an address, primarily to enable uniform access to L2/memory
 *   in a BlackParrot multicore.
 *
 *   Unicore designs do not swizzle addresses.
 *
 *   Encode takes an address of form {A, b...bb, c...cc, D} and outputs
 *   address of {A, c...cc, b...bb, D}. The bit widths of b and c bits may differ and are
 *   specified by the offset_widths_p parameter.
 *
 */

`include "bp_common_defines.svh"

module bp_me_dram_hash_encode
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam lg_l2_banks_lp = `BSG_SAFE_CLOG2(l2_banks_p)
   )
  (input [daddr_width_p-1:0]           daddr_i
   , output logic [daddr_width_p-1:0]  daddr_o
   , output logic [lg_l2_banks_lp-1:0] bank_o
   );

  localparam l2_block_offset_width_lp = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam lg_l2_sets_lp            = `BSG_SAFE_CLOG2(l2_sets_p);

  if (cce_type_p == e_cce_uce) begin : unicore
    // unicore does not apply an address swizzle
    assign daddr_o = daddr_i;
    // bank selection uses the low order tag bits
    localparam l2_bank_offset_width_lp  = l2_block_offset_width_lp+lg_l2_sets_lp;
    assign bank_o = (l2_banks_p > 1) ? daddr_i[l2_bank_offset_width_lp+:lg_l2_banks_lp] : '0;
  end
  else begin : multicore
    localparam lg_num_cce_lp            = `BSG_SAFE_CLOG2(num_cce_p);
    localparam int hash_offset_widths_lp[2:0] = '{(lg_l2_sets_lp-lg_num_cce_lp), lg_num_cce_lp, l2_block_offset_width_lp};
    localparam offset_width_lp = hash_offset_widths_lp[0] + hash_offset_widths_lp[1] + hash_offset_widths_lp[2];
    // swizzle the address
    wire [hash_offset_widths_lp[2]+hash_offset_widths_lp[1]-1:0] encoded_bits =
      {daddr_i[hash_offset_widths_lp[0]+:hash_offset_widths_lp[1]]
       ,daddr_i[(hash_offset_widths_lp[0]+hash_offset_widths_lp[1])+:hash_offset_widths_lp[2]]
       };
    assign daddr_o =
      {daddr_i[daddr_width_p-1:offset_width_lp]
       ,encoded_bits
       ,daddr_i[0+:hash_offset_widths_lp[0]]
       };
    // bank selection
    localparam l2_bank_offset_width_lp  = (num_cce_p > 1) ? l2_block_offset_width_lp+lg_num_cce_lp : l2_block_offset_width_lp;
    assign bank_o = (l2_banks_p > 1) ? daddr_i[l2_bank_offset_width_lp+:lg_l2_banks_lp] : '0;
  end

endmodule


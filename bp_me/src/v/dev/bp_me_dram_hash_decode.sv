/*
 * Name:
 *   bp_me_dram_hash_decode.sv
 *
 * Description:
 *   This module reverses the bit swizzling applied by bp_me_dram_hash_encode.
 *
 *   Unicore designs do not swizzle addresses.
 *
 *   Encode takes an address of form {A, b...bb, c...cc, D} and outputs
 *   address of {A, c...cc, b...bb, D}. The bit widths of b and c bits may differ and are
 *   specified by the offset_widths_p parameter.
 *   Decode reverses this swizzle operation, transforming {A, c...cc, b...bb, D} to
 *   {A, b...bb, c...cc, D}.
 *
 */

`include "bp_common_defines.svh"

module bp_me_dram_hash_decode
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [daddr_width_p-1:0]          daddr_i
   , output logic [daddr_width_p-1:0] daddr_o
   );

  if (cce_type_p == e_cce_uce) begin : unicore
    assign daddr_o = daddr_i;
  end else begin : multicore
    localparam l2_block_offset_width_lp = `BSG_SAFE_CLOG2(l2_block_width_p/8);
    localparam lg_l2_sets_lp            = `BSG_SAFE_CLOG2(l2_sets_p);
    localparam lg_l2_banks_lp           = `BSG_SAFE_CLOG2(l2_banks_p);
    localparam lg_num_cce_lp            = `BSG_SAFE_CLOG2(num_cce_p);
    localparam int hash_offset_widths_lp[2:0] = '{(lg_l2_sets_lp-lg_num_cce_lp), lg_num_cce_lp, l2_block_offset_width_lp};
    localparam offset_width_lp = hash_offset_widths_lp[0] + hash_offset_widths_lp[1] + hash_offset_widths_lp[2];

    wire [hash_offset_widths_lp[2]+hash_offset_widths_lp[1]-1:0] decoded_bits =
      {daddr_i[hash_offset_widths_lp[0]+:hash_offset_widths_lp[2]]
       ,daddr_i[(hash_offset_widths_lp[0]+hash_offset_widths_lp[2])+:hash_offset_widths_lp[1]]
       };

    assign daddr_o =
      {daddr_i[daddr_width_p-1:offset_width_lp]
       ,decoded_bits
       ,daddr_i[0+:hash_offset_widths_lp[0]]
       };
  end

endmodule


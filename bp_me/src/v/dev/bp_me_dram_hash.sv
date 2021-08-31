/*
 * Name:
 *   bp_me_dram_hash.sv
 *
 * Description:
 *   This module swizzles bits in an address, primarily to enable uniform access to L2/memory
 *   in a BlackParrot multicore. The decode_p parameter determines whether the module applies
 *   or reverts the swizzle operation.
 *
 *   Encode takes an address of form {A, b...bb, c...cc, D} and outputs
 *   address of {A, c...cc, b...bb, D}. The bit widths of b and c bits may differ and are
 *   specified by the offset_widths_p parameter.
 *   Decode reverses the swizzle operation.
 *
 */

`include "bp_common_defines.svh"

module bp_me_dram_hash
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , localparam block_offset_lp = `BSG_SAFE_CLOG2(cce_block_width_p/8)
   , localparam lg_lce_sets_lp = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam lg_num_cce_lp = `BSG_SAFE_CLOG2(num_cce_p)
   , parameter int offset_widths_p[2:0] = '{ (lg_lce_sets_lp-lg_num_cce_lp), lg_num_cce_lp, block_offset_lp }
   , localparam offset_width_lp = offset_widths_p[0] + offset_widths_p[1] + offset_widths_p[2]
   , parameter addr_width_p = paddr_width_p
   , parameter decode_p = 0
   )
  (input [addr_width_p-1:0]         addr_i
   , output logic [addr_width_p-1:0] addr_o
   );

  if (decode_p == 0) begin : encode
    wire [offset_widths_p[2]+offset_widths_p[1]-1:0] encoded_bits =
      {addr_i[offset_widths_p[0]+:offset_widths_p[1]]
       ,addr_i[(offset_widths_p[0]+offset_widths_p[1])+:offset_widths_p[2]]
       };

    assign addr_o =
      {addr_i[addr_width_p-1:offset_width_lp]
       ,encoded_bits
       ,addr_i[0+:offset_widths_p[0]]
       };
  end
  else begin : decode
    wire [offset_widths_p[2]+offset_widths_p[1]-1:0] decoded_bits =
      {addr_i[offset_widths_p[0]+:offset_widths_p[2]]
       ,addr_i[(offset_widths_p[0]+offset_widths_p[2])+:offset_widths_p[1]]
       };

    assign addr_o =
      {addr_i[addr_width_p-1:offset_width_lp]
       ,decoded_bits
       ,addr_i[0+:offset_widths_p[0]]
       };
  end

endmodule


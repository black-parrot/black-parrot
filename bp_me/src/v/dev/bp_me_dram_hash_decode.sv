/*
 * Name:
 *   bp_me_dram_hash_decode.sv
 *
 * Description:
 *   This module reverses the bit swizzling applied by bp_me_dram_hash_encode.
 *
 *   Encode takes an address of form {A, b...bb, c...cc, D} and outputs
 *   address of {A, c...cc, b...bb, D}. The bit widths of b and c bits may differ and are
 *   specified by the offset_widths_p parameter.
 *   Decode reverses this swizzle operation, transforming {A, c...cc, b...bb, D} to
 *   {A, b...bb, c...cc, D}.
 *
 *   The offset_widths_p parameter specifies the bit widths of b, c, and D bitfields as they
 *   are defined in the decoded address (addr_o).
 *
 */

`include "bp_common_defines.svh"

module bp_me_dram_hash_decode
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter int offset_widths_p[2:0] = '{-1, -1, -1}
   , parameter addr_width_p = paddr_width_p
   )
  (input [addr_width_p-1:0]         addr_i
   , output logic [addr_width_p-1:0] addr_o
   );

  localparam offset_width_lp = offset_widths_p[0] + offset_widths_p[1] + offset_widths_p[2];

  wire [offset_widths_p[2]+offset_widths_p[1]-1:0] decoded_bits =
    {addr_i[offset_widths_p[0]+:offset_widths_p[2]]
     ,addr_i[(offset_widths_p[0]+offset_widths_p[2])+:offset_widths_p[1]]
     };

  assign addr_o =
    {addr_i[addr_width_p-1:offset_width_lp]
     ,decoded_bits
     ,addr_i[0+:offset_widths_p[0]]
     };

endmodule


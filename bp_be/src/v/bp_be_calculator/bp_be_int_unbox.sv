
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_int_unbox
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dpath_width_gp-1:0]           reg_i
   , input [$bits(bp_be_int_tag_e)-1:0] tag_i
   , input                              unsigned_i
   , output logic [dword_width_gp-1:0]  val_o
   );

 `bp_cast_i(bp_be_int_reg_s, reg);
  wire [dword_width_gp-1:0] val = reg_cast_i.val;

  logic [dword_width_gp-1:0] raw;
  always_comb
    case (reg_cast_i.tag)
      e_int_byte : raw = {{56{reg_cast_i.val[63]}}, val[0+:8]};
      e_int_hword: raw = {{48{reg_cast_i.val[63]}}, val[0+:16]};
      e_int_word : raw = {{32{reg_cast_i.val[63]}}, val[0+:32]};
      // e_int_dword
      default: raw = val;
    endcase

  wire sig = ~unsigned_i & raw[63];
  always_comb
    case (tag_i)
      e_int_word: val_o = {{32{sig}}, raw[0+:32]};
      // e_int_dword
      default: val_o = raw;
    endcase

endmodule


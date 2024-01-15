
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_int_box
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dword_width_gp-1:0]           raw_i
   , input [$bits(bp_be_int_tag_e)-1:0] tag_i
   , input                              unsigned_i
   , output logic [dpath_width_gp-1:0]  reg_o
   );

 `bp_cast_o(bp_be_int_reg_s, reg);

  logic sig;
  always_comb
    case (tag_i)
      e_int_byte : sig = raw_i[7];
      e_int_hword: sig = raw_i[15];
      e_int_word : sig = raw_i[31];
      // e_int_dword
      default: sig = raw_i[63];
    endcase

  always_comb
    begin
      reg_cast_o.tag = tag_i;
      reg_cast_o.val = raw_i;
      if (tag_i != e_int_dword)
        reg_cast_o.val[63] = sig & ~unsigned_i;
    end

endmodule


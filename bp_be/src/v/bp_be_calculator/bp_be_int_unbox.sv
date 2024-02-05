
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
      e_int_byte : raw = {{56{val[63]}}, val[0+: 8]};
      e_int_hword: raw = {{48{val[63]}}, val[0+:16]};
      e_int_word : raw = {{32{val[63]}}, val[0+:32]};
      // e_int_dword
      default: raw = val;
    endcase

  wire invbox = tag_i > reg_cast_i.tag;
  always_comb
    unique casez ({unsigned_i, invbox, tag_i})
      {2'b1?, e_int_byte }: val_o = {{56{1'b0   }}, raw[0+: 8]};
      {2'b01, e_int_byte }: val_o = {{56{raw[ 7]}}, raw[0+: 8]};
      {2'b1?, e_int_hword}: val_o = {{48{1'b0   }}, raw[0+:16]};
      {2'b01, e_int_hword}: val_o = {{48{raw[15]}}, raw[0+:16]};
      {2'b1?, e_int_word }: val_o = {{32{1'b0   }}, raw[0+:32]};
      {2'b01, e_int_word }: val_o = {{32{raw[31]}}, raw[0+:32]};
      // {2'b??, e_int_dword}
      default: val_o = raw;
    endcase

endmodule


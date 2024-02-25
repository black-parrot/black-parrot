
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_int_unbox
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dpath_width_gp-1:0]            reg_i
   , input [$bits(bp_be_int_tag_e)-1:0]  tag_i
   , input                               unsigned_i
   , output logic [int_rec_width_gp-1:0] val_o
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
      default: raw = {{0{val[63]}}, val[0+:64]};
    endcase

  wire sigbox = tag_i >= reg_cast_i.tag;
  always_comb
    unique casez ({unsigned_i, sigbox, tag_i})
      // Unsigned output always zero extends
      {2'b1?, e_int_dword}: val_o = {{ 1{1'b0   }}, raw[0+:64]};
      {2'b1?, e_int_word }: val_o = {{33{1'b0   }}, raw[0+:32]};
      {2'b1?, e_int_hword}: val_o = {{49{1'b0   }}, raw[0+:16]};
      {2'b1?, e_int_byte }: val_o = {{57{1'b0   }}, raw[0+: 8]};

      // sigboxes uses the wider sign extension
      {2'b01, e_int_dword}: val_o = {{ 1{raw[63]}}, raw[0+:64]};
      {2'b01, e_int_word }: val_o = {{33{raw[31]}}, raw[0+:32]};
      {2'b01, e_int_hword}: val_o = {{49{raw[15]}}, raw[0+:16]};
      {2'b01, e_int_byte }: val_o = {{57{raw[ 7]}}, raw[0+: 8]};

      // Valid boxes use the raw sign extension
      {2'b00, e_int_dword}: val_o = {{ 1{raw[63]}}, raw[0+:64]};
      {2'b00, e_int_word }: val_o = {{33{raw[63]}}, raw[0+:32]};
      {2'b00, e_int_hword}: val_o = {{49{raw[63]}}, raw[0+:16]};
      {2'b00, e_int_byte }: val_o = {{57{raw[63]}}, raw[0+: 8]};

      default: begin end
    endcase

endmodule


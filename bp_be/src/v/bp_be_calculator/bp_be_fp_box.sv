
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_fp_box
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (// RAW floating point input
   input [dword_width_gp-1:0]          raw_i
   , input [$bits(bp_be_fp_tag_e)-1:0] tag_i
   , output [dpath_width_gp-1:0]       reg_o
   );

  `bp_cast_o(bp_be_fp_reg_s, reg);

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;
  // We also convert from 32 bit inputs to 64 bit recoded inputs.
  //   This double rounding behavior was formally proved correct in
  //   "Innocuous Double Rounding of Basic Arithmetic Operations" by Pierre Roux

  bp_hardfloat_rec_sp_s in_sp_rec_li;
  wire [sp_float_width_gp-1:0] in_sp_li = raw_i[0+:sp_float_width_gp];
  fNToRecFN
   #(.expWidth(sp_exp_width_gp)
     ,.sigWidth(sp_sig_width_gp)
     )
   in32_rec
    (.in(in_sp_li)
     ,.out(in_sp_rec_li)
     );

  bp_hardfloat_rec_dp_s in_dp_rec_li;
  wire [dp_float_width_gp-1:0] in_dp_li = raw_i[0+:dp_float_width_gp];
  fNToRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   in64_rec
    (.in(in_dp_li)
     ,.out(in_dp_rec_li)
     );

  //
  // Unsafe upconvert
  //
  localparam bias_adj_lp = (1 << dp_exp_width_gp) - (1 << sp_exp_width_gp);
  bp_hardfloat_rec_sp_s sp_rec;
  bp_hardfloat_rec_dp_s sp2dp_rec;
  assign sp_rec = in_sp_rec_li;

  wire [dp_exp_width_gp:0] adjusted_exp = sp_rec.exp + bias_adj_lp;
  wire [2:0]                   exp_code = sp_rec.exp[sp_exp_width_gp-:3];
  wire                          special = (exp_code == '0) || (exp_code >= 3'd6);

  assign sp2dp_rec = '{sign  : sp_rec.sign
                       ,exp  : special ? {exp_code, adjusted_exp[0+:dp_exp_width_gp-2]} : adjusted_exp
                       ,fract: {sp_rec.fract, (dp_sig_width_gp-sp_sig_width_gp)'(0)}
                       };

  wire nanbox_v_li = &raw_i[word_width_gp+:word_width_gp];
  wire encode_as_sp = nanbox_v_li | (tag_i == e_fp_sp);

  bp_be_fp_reg_s reg32, reg64;
  assign reg32 = '{tag: e_fp_sp, rec: sp2dp_rec};
  assign reg64 = '{tag: e_fp_dp, rec: in_dp_rec_li};

  assign reg_cast_o = encode_as_sp ? reg32 : reg64;

endmodule


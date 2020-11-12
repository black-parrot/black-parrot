
module bp_be_fp_to_rec
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (// RAW floating point input
   input [dword_width_p-1:0]      raw_i
   // Precision of the raw input value
   , input                        raw_sp_not_dp_i

   , output                       rec_sp_not_dp_o
   , output [dp_rec_width_gp-1:0] rec_o
   );

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
                       ,fract: sp_rec.fract << (dp_sig_width_gp-sp_sig_width_gp)
                       };

  wire nanbox_v_li = &raw_i[word_width_p+:word_width_p];
  wire encode_as_sp = nanbox_v_li | raw_sp_not_dp_i;

  assign rec_sp_not_dp_o = encode_as_sp;
  assign rec_o           = encode_as_sp ? sp2dp_rec : in_dp_rec_li;

endmodule


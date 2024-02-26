
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_rec_to_raw
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam raw_width_lp = $bits(bp_hardfloat_raw_dp_s)
   )
  (input [dp_rec_width_gp-1:0]       rec_i
   , input                           tag_i
   , output logic [raw_width_lp-1:0] raw_o
   );

  `bp_cast_i(bp_hardfloat_rec_dp_s, rec);
  `bp_cast_o(bp_hardfloat_raw_dp_s, raw);

  logic [dp_sig_width_gp:0] raw_sig;
  recFNToRawFN
   #(.expWidth(dp_exp_width_gp) ,.sigWidth(dp_sig_width_gp))
   rec2raw
    (.in(rec_cast_i)
     ,.isNaN(raw_cast_o.is_nan)
     ,.isInf(raw_cast_o.is_inf)
     ,.isZero(raw_cast_o.is_zero)
     ,.sign(raw_cast_o.sign)
     ,.sExp(raw_cast_o.sexp)
     ,.sig(raw_sig)
     );
  assign raw_cast_o.sig = raw_sig << 2'b10;

  isSigNaNRecFN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp))
   is_snan
    (.in(rec_cast_i)
     ,.isSigNaN(raw_cast_o.is_snan)
     );

  localparam [dp_exp_width_gp:0] minNormDpExp = (1<<(dp_exp_width_gp - 1)) + 2;
  localparam [sp_exp_width_gp:0] minNormSpExp = (1<<(sp_exp_width_gp - 1)) + 2;

  localparam bias_adj_lp = (1 << sp_exp_width_gp) - (1 << dp_exp_width_gp);
  wire [sp_exp_width_gp:0] biased_sp = raw_cast_o.sexp + bias_adj_lp;
  wire [dp_exp_width_gp:0] biased_dp = raw_cast_o.sexp + 0;

  assign raw_cast_o.is_sub = tag_i
    ? ~raw_cast_o.is_zero & ~raw_cast_o.is_inf & ~raw_cast_o.is_nan & (biased_sp < minNormSpExp)
    : ~raw_cast_o.is_zero & ~raw_cast_o.is_inf & ~raw_cast_o.is_nan & (biased_dp < minNormDpExp);

endmodule


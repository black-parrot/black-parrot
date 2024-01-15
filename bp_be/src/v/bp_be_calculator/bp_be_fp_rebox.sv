
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_fp_rebox
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dp_raw_width_gp-1:0]         raw_i
   , input [$bits(bp_be_fp_tag_e)-1:0] tag_i
   , input [$bits(rv64_frm_e)-1:0]     frm_i
   , input                             invalid_exc_i
   , input                             infinite_exc_i

   , output logic [dpath_width_gp-1:0] reg_o
   , output logic [4:0]                fflags_o
   );

  `bp_cast_i(bp_hardfloat_raw_dp_s, raw);
  `bp_cast_o(bp_be_fp_reg_s, reg);

  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  logic [dp_rec_width_gp-1:0] result_dp, result_sp;
  rv64_fflags_s fflags_dp, fflags_sp;
  roundRawFNtoRecFN_mixed
   #(.fullExpWidth(dp_exp_width_gp)
     ,.fullSigWidth(dp_sig_width_gp)
     ,.midExpWidth(sp_exp_width_gp)
     ,.midSigWidth(sp_sig_width_gp)
     ,.outExpWidth(dp_exp_width_gp)
     ,.outSigWidth(dp_sig_width_gp)
     )
   round_mixed
    (.control(control_li)
     ,.invalidExc(invalid_exc_i)
     ,.infiniteExc(infinite_exc_i)
     ,.in_isNaN(raw_cast_i.is_nan)
     ,.in_isInf(raw_cast_i.is_inf)
     ,.in_isZero(raw_cast_i.is_zero)
     ,.in_sign(raw_cast_i.sign)
     ,.in_sExp(raw_cast_i.sexp)
     ,.in_sig(raw_cast_i.sig)
     ,.roundingMode(frm_i)
     ,.fullOut(result_dp)
     ,.fullExceptionFlags(fflags_dp)
     ,.midOut(result_sp)
     ,.midExceptionFlags(fflags_sp)
     );

  bp_be_fp_reg_s sp_reg_lo, dp_reg_lo;
  rv64_fflags_s fflags_lo;
  assign sp_reg_lo = '{tag: e_fp_sp, rec: result_sp};
  assign dp_reg_lo = '{tag: e_fp_dp, rec: result_dp};

  assign reg_cast_o = (tag_i == e_fp_sp) ? sp_reg_lo : dp_reg_lo;
  assign fflags_o   = (tag_i == e_fp_sp) ? fflags_sp : fflags_dp;

endmodule


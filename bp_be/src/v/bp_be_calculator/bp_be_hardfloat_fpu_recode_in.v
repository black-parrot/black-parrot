
module bp_be_hardfloat_fpu_recode_in
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 #(parameter latency_p          = 5 // Used for retiming
   , parameter dword_width_p    = 64
   , parameter word_width_p     = 32
   , parameter sp_exp_width_lp  = 8
   , parameter sp_sig_width_lp  = 24
   , parameter sp_width_gp      = sp_exp_width_lp+sp_sig_width_lp
   , parameter dp_exp_width_lp  = 11
   , parameter dp_sig_width_lp  = 53
   , parameter dp_width_gp      = dp_exp_width_lp+dp_sig_width_lp
   , parameter els_p            = 1

   , parameter sp_rec_width_gp = sp_exp_width_lp+sp_sig_width_lp+1
   , parameter dp_rec_width_gp = dp_exp_width_lp+dp_sig_width_lp+1
   )
  (input [els_p-1:0][dword_width_p-1:0]      fp_i

   // Input/output precision of results. Applies to both integer and
   //   floating point operands and results
   , input bp_be_fp_pr_e                     ipr_i

   , output [els_p-1:0][dp_width_gp-1:0]     fp_o
   , output [els_p-1:0][dp_rec_width_gp-1:0] rec_o
   , output [els_p-1:0]                      nan_o
   , output [els_p-1:0]                      snan_o
   , output [els_p-1:0]                      sub_o
   );

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;
 
  // Recode all three inputs from FP
  //   We use a pseudo foreach loop to save verbosity
  //   We also convert from 32 bit inputs to 64 bit recoded inputs. 
  //     This double rounding behavior was formally proved correct in
  //     "Innocuous Double Rounding of Basic Arithmetic Operations" by Pierre Roux
  for (genvar i = 0; i < els_p; i++)
    begin : in_rec
      wire nanbox_v_li = &fp_i[i][dp_width_gp-1:sp_width_gp];

      wire [sp_width_gp-1:0] in_sp_li = nanbox_v_li ? fp_i[i][0+:sp_width_gp] : sp_canonical;
      wire [dp_width_gp-1:0] in_dp_li = fp_i[i];

      logic [sp_rec_width_gp-1:0] in_sp_rec_li;
      fNToRecFN
       #(.expWidth(sp_exp_width_lp)
         ,.sigWidth(sp_sig_width_lp)
         )
       in32_rec
        (.in(in_sp_li)
         ,.out(in_sp_rec_li)
         );

      logic [dp_rec_width_gp-1:0] in_dp_rec_li;
      fNToRecFN
       #(.expWidth(dp_exp_width_lp)
         ,.sigWidth(dp_sig_width_lp)
         )
       in64_rec
        (.in(in_dp_li)
         ,.out(in_dp_rec_li)
         );

      logic [dp_rec_width_gp-1:0] in_sp2dp_rec_li;
      recFNToRecFN
       #(.inExpWidth(sp_exp_width_lp)
         ,.inSigWidth(sp_sig_width_lp)
         ,.outExpWidth(dp_exp_width_lp)
         ,.outSigWidth(dp_sig_width_lp)
         )
       rec_sp_to_dp
        (.control(control_li)
         ,.in(in_sp_rec_li)
         // Rounding mode is irrelevant for up-precision
         ,.roundingMode('0)
         ,.out(in_sp2dp_rec_li)
         // Exception flags should be raised by downstream operations
         ,.exceptionFlags()
         );

      logic dp_is_nan_lo, dp_is_inf_lo, dp_is_zero_lo, dp_is_sub_lo;
      logic dp_sgn_lo;
      logic [dp_exp_width_lp+1:0] dp_exp_lo;
      logic [dp_sig_width_lp:0] dp_sig_lo;
      recFNToRawFN
       #(.expWidth(dp_exp_width_lp)
         ,.sigWidth(dp_sig_width_lp)
         )
       dp_classify
        (.in(in_dp_rec_li)
         ,.isNaN(dp_is_nan_lo)
         ,.isInf(dp_is_inf_lo)
         ,.isZero(dp_is_zero_lo)
         ,.sign(dp_sgn_lo)
         ,.sExp(dp_exp_lo)
         ,.sig(dp_sig_lo)
         );

      logic sp_is_nan_lo, sp_is_inf_lo, sp_is_zero_lo, sp_is_sub_lo;
      logic sp_sgn_lo;
      logic [sp_exp_width_lp+1:0] sp_exp_lo;
      logic [sp_sig_width_lp:0] sp_sig_lo;
      recFNToRawFN
       #(.expWidth(sp_exp_width_lp)
         ,.sigWidth(sp_sig_width_lp)
         )
       sp_classify
        (.in(in_sp_rec_li)
         ,.isNaN(sp_is_nan_lo)
         ,.isInf(sp_is_inf_lo)
         ,.isZero(sp_is_zero_lo)
         ,.sign(sp_sgn_lo)
         ,.sExp(sp_exp_lo)
         ,.sig(sp_sig_lo)
         );

      logic dp_sig_nan_lo;
      isSigNaNRecFN
       #(.expWidth(dp_exp_width_lp)
         ,.sigWidth(dp_sig_width_lp)
         )
       in_dp_sig_nan
        (.in(in_dp_rec_li)
         ,.isSigNaN(dp_sig_nan_lo)
         );

      logic sp_sig_nan_lo;
      isSigNaNRecFN
       #(.expWidth(sp_exp_width_lp)
         ,.sigWidth(sp_sig_width_lp)
         )
       in_sp_sig_nan
        (.in(in_sp_rec_li)
         ,.isSigNaN(sp_sig_nan_lo)
         );

      assign fp_o[i] = (ipr_i == e_pr_single)
                       ? in_sp_li
                       : in_dp_li;
      assign rec_o[i] = (ipr_i == e_pr_double)
                        ? in_dp_rec_li
                        : in_sp2dp_rec_li;
      assign nan_o[i] = (ipr_i == e_pr_double)
                        ? dp_is_nan_lo
                        : sp_is_nan_lo;
      assign snan_o[i] = (ipr_i == e_pr_double)
                         ? dp_sig_nan_lo
                         : sp_sig_nan_lo;
      assign sub_o[i] = (ipr_i == e_pr_double)
                        ? ~dp_is_nan_lo & ~dp_is_inf_lo & ~dp_is_zero_lo & (dp_exp_lo < (2**(dp_exp_width_lp-1)+2))
                        : ~sp_is_nan_lo & ~sp_is_inf_lo & ~sp_is_zero_lo & (sp_exp_lo < (2**(sp_exp_width_lp-1)+2));
    end

endmodule


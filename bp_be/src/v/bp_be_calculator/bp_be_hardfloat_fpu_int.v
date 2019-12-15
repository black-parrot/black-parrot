
/*
 * Name: bp_be_hardfloat_fpu_int
 *
 * Description:
 *
 * Notes:
 *
 */

module bp_be_hardfloat_fpu_int
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
  (// Operands
   //   Can be either integers, single precision or double precision
   input [long_width_gp-1:0]    a_i
   , input [long_width_gp-1:0]  b_i

   // Floating point operation to perform
   , input bp_be_fp_fu_op_e       op_i

   // Input/output precision of results. Applies to both integer and 
   //   floating point operands and results
   , input bp_be_fp_pr_e          ipr_i
   , input bp_be_fp_pr_e          opr_i
   // The IEEE rounding mode to use
   , input rv64_frm_e             rm_i


   , output logic [long_width_gp-1:0] o
   , output rv64_fflags_s             eflags_o
   );

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;
 
  // Input recoding
  //
  logic [dp_rec_width_gp-1:0] a_rec_li, b_rec_li;
  logic a_is_nan_li, b_is_nan_li;
  logic a_is_snan_li, b_is_snan_li;
  logic a_is_sub_li, b_is_sub_li;
  bp_be_hardfloat_fpu_recode_in
   #(.els_p(2))
   recode_in
    (.fp_i({b_i, a_i})
  
     ,.ipr_i(ipr_i)
  
     ,.fp_o()
     ,.rec_o({b_rec_li, a_rec_li})
     ,.nan_o({b_is_nan_li, a_is_nan_li})
     ,.snan_o({b_is_snan_li, a_is_snan_li})
     ,.sub_o({b_is_sub_li, a_is_sub_li})
     );

  // Generate auxiliary information
  //
  logic a_is_nan_lo, a_is_inf_lo, a_is_zero_lo, a_is_sub_lo;
  logic a_sgn_lo;
  logic [dp_exp_width_gp+1:0] a_exp_lo;
  logic [dp_sig_width_gp:0] a_sig_lo;

  recFNToRawFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   aclass
    (.in(a_rec_li)
     ,.isNaN(a_is_nan_lo)
     ,.isInf(a_is_inf_lo)
     ,.isZero(a_is_zero_lo)
     ,.sign(a_sgn_lo)
     ,.sExp(a_exp_lo)
     ,.sig(a_sig_lo)
     );

  // FEQ/FLT/FLE
  //
  logic [dp_rec_width_gp-1:0] fcompare_lo;
  rv64_fflags_s fcmp_eflags_lo, fcompare_eflags_lo;
  rv64_fflags_s fcmp_nv_eflags_lo;

  logic flt_lo, feq_lo, fgt_lo, unordered_lo;
  wire is_flt_li  = (op_i == e_op_flt);
  wire is_fle_li  = (op_i == e_op_fle);
  wire signaling_li = is_flt_li | is_fle_li;
  compareRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   fcmp
    (.a(a_rec_li)
     ,.b(b_rec_li)
     ,.signaling(signaling_li)
     ,.lt(flt_lo)
     ,.eq(feq_lo)
     ,.gt(fgt_lo)
     // Unordered is currently unused
     ,.unordered(unordered_lo)
     ,.exceptionFlags(fcmp_eflags_lo)
     );
  wire [dp_rec_width_gp-1:0] fle_lo  = ~fgt_lo;

  assign fcmp_nv_eflags_lo = '{nv : (a_is_snan_li | b_is_snan_li), default: '0};
  assign fcompare_eflags_lo = fcmp_eflags_lo | fcmp_nv_eflags_lo;

  always_comb
    begin
      fcompare_lo = '0;
      unique case (op_i)
        e_op_feq : fcompare_lo = dp_rec_width_gp'(~a_is_nan_li & ~b_is_nan_li & ~unordered_lo & feq_lo);
        e_op_flt : fcompare_lo = dp_rec_width_gp'(~a_is_nan_li & ~b_is_nan_li & ~unordered_lo & flt_lo);
        e_op_fle : fcompare_lo = dp_rec_width_gp'(~a_is_nan_li & ~b_is_nan_li & ~unordered_lo & fle_lo);
        default : begin end
      endcase
    end

  // FCVT
  //
  logic [dp_rec_width_gp-1:0] fcvt_lo;
  rv64_fflags_s f2i_eflags_lo;

  logic [long_width_gp-1:0] f2dw_lo;
  rv64_iflags_s f2dw_int_eflags_lo;
  wire is_f2iu = (op_i == e_op_f2iu);
  recFNToIN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     ,.intWidth(long_width_gp)
     )
   f2dw
    (.control(control_li)
     ,.in(a_rec_li)
     ,.roundingMode(rm_i)
     ,.signedOut(~is_f2iu)
     ,.out(f2dw_lo)
     ,.intExceptionFlags(f2dw_int_eflags_lo)
     );

  logic [word_width_gp-1:0] f2w_lo;
  rv64_iflags_s f2w_int_eflags_lo;
  recFNToIN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     ,.intWidth(word_width_gp)
     )
   f2w
    (.control(control_li)
     ,.in(a_rec_li)
     ,.roundingMode(rm_i)
     ,.signedOut(~is_f2iu)
     ,.out(f2w_lo)
     ,.intExceptionFlags(f2w_int_eflags_lo)
     );
  wire [long_width_gp-1:0] f2i_lo = (opr_i == e_pr_double) 
                                    ? f2dw_lo 
                                    : long_width_gp'($signed(f2w_lo));
  assign f2i_eflags_lo = (opr_i == e_pr_double) 
                         ? '{nv: f2dw_int_eflags_lo.nv | f2dw_int_eflags_lo.of, nx: f2dw_int_eflags_lo.nx, default: '0}
                         : '{nv: f2w_int_eflags_lo.nv  | f2w_int_eflags_lo.of , nx: f2w_int_eflags_lo.nx , default: '0};

  // FCLASS
  //
  rv64_fclass_s fclass_lo;
  rv64_fflags_s fclass_eflags_lo;

  assign fclass_lo = '{padding : '0
                       ,q_nan  : a_is_nan_lo & ~a_is_snan_li
                       ,sig_nan: a_is_nan_lo & a_is_snan_li
                       ,p_inf  : ~a_sgn_lo    &  a_is_inf_lo
                       ,p_norm : ~a_sgn_lo    & ~a_is_sub_li & ~a_is_inf_lo & ~a_is_zero_lo & ~a_is_nan_lo
                       ,p_sub  : ~a_sgn_lo    &  a_is_sub_li
                       ,p_zero : ~a_sgn_lo    &  a_is_zero_lo
                       ,n_zero :  a_sgn_lo    &  a_is_zero_lo
                       ,n_sub  :  a_sgn_lo    &  a_is_sub_li
                       ,n_norm :  a_sgn_lo    & ~a_is_sub_li & ~a_is_inf_lo & ~a_is_zero_lo & ~a_is_nan_lo
                       ,n_inf  :  a_sgn_lo    &  a_is_inf_lo
                       };
  assign fclass_eflags_lo = '0;

  // Recoded result selection
  //
  logic [long_width_gp-1:0] direct_result_lo;
  rv64_fflags_s direct_eflags_lo;
  always_comb
    begin
      direct_result_lo = '0;
      direct_eflags_lo = '0;
      unique case (op_i)
        e_op_feq, e_op_flt, e_op_fle:
          begin
            direct_result_lo = fcompare_lo[0];
            direct_eflags_lo = fcompare_eflags_lo;
          end
        e_op_fclass:
          begin
            direct_result_lo = fclass_lo;
            direct_eflags_lo = '0;
          end
        e_op_f2i:
          begin
            direct_result_lo = (opr_i == e_pr_single)
                               ? long_width_gp'($signed(f2i_lo[0+:word_width_gp]))
                               : f2i_lo;
            direct_eflags_lo = f2i_eflags_lo;
          end
        e_op_f2iu:
          begin
            direct_result_lo = (opr_i == e_pr_single)
                               ? long_width_gp'($signed(f2i_lo[0+:word_width_gp]))
                               : f2i_lo;
            direct_eflags_lo = f2i_eflags_lo;
          end
        e_op_fmvi:
          begin
            direct_result_lo = (opr_i == e_pr_single)
                               ? long_width_gp'($signed(a_i[0+:word_width_gp]))
                               : a_i;
            direct_eflags_lo = '0;
          end
        default: begin end
      endcase
    end

  assign o = direct_result_lo;
  assign eflags_o = direct_eflags_lo;

endmodule


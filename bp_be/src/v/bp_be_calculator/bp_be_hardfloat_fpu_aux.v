
/*
 * Name: bp_be_hardfloat_fpu
 *
 * Description: This is a floating-point unit which handles both single and double precision
 *   floating point operations. It relies on cross-boundary flattening and retiming to 
 *   achieve good QoR.
 *
 * Notes:
 *   Could be parameterizable whether the inputs / outputs are recoded or not.
 */

module bp_be_hardfloat_fpu_aux
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 #(parameter latency_p = 2) // Used for retiming
  (input                        clk_i
   , input                      reset_i

   // Operands
   //   Can be either integers, single precision or double precision
   , input [long_width_gp-1:0]  a_i
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
 
  logic [dp_float_width_gp-1:0] a_fp_li, b_fp_li;
  logic [dp_rec_width_gp-1:0] a_rec_li, b_rec_li;
  logic a_is_nan_li, b_is_nan_li;
  logic a_is_snan_li, b_is_snan_li;
  logic a_is_sub_li, b_is_sub_li;
  bp_be_hardfloat_fpu_recode_in
   #(.els_p(2))
   recode_in
    (.fp_i({b_i, a_i})
        
     ,.ipr_i(ipr_i)
  
     ,.fp_o({b_fp_li, a_fp_li})
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
  assign a_is_sub_lo = (ipr_i == e_pr_double)
                       ? ~a_is_nan_lo & ~a_is_inf_lo & ~a_is_zero_lo
                         & (a_rec_li[dp_sig_width_gp-1+:dp_exp_width_gp+1] < (2**(dp_exp_width_gp-1) + 2))
                       : ~a_is_nan_lo & ~a_is_inf_lo & ~a_is_zero_lo
                         & (a_rec_li[sp_sig_width_gp-1+:sp_exp_width_gp+1] < (2**(sp_exp_width_gp-1) + 2));

  logic b_is_nan_lo, b_is_inf_lo, b_is_zero_lo;
  logic b_sgn_lo;
  logic [dp_exp_width_gp+1:0] b_exp_lo;
  logic [dp_sig_width_gp:0] b_sig_lo;

  recFNToRawFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   bclass
    (.in(b_rec_li)
     ,.isNaN(b_is_nan_lo)
     ,.isInf(b_is_inf_lo)
     ,.isZero(b_is_zero_lo)
     ,.sign(b_sgn_lo)
     ,.sExp(b_exp_lo)
     ,.sig(b_sig_lo)
     );

  wire is_fadd_li    = (op_i == e_op_fadd);
  wire is_fsub_li    = (op_i == e_op_fsub);
  wire is_faddsub_li = is_fadd_li | is_fsub_li;
  wire is_fmul_li    = (op_i == e_op_fmul);

  // FMIN/FMAX/FEQ/FLT/FLE
  //
  rv64_fflags_s fcmp_eflags_lo, fcompare_eflags_lo, fminmax_eflags_lo;

  logic [dp_rec_width_gp-1:0] fminmax_lo;
  rv64_fflags_s fcmp_nv_eflags_lo, fminmax_nv_eflags_lo;

  logic flt_lo, feq_lo, fgt_lo, unordered_lo;
  wire is_flt_li  = (op_i == e_op_flt);
  wire is_fle_li  = (op_i == e_op_fle);
  wire is_fmax_li = (op_i == e_op_fmax);
  wire is_fmin_li = (op_i == e_op_fmin);
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

  assign fminmax_nv_eflags_lo = '{nv : (a_is_snan_li | b_is_snan_li), default: '0};
  assign fminmax_eflags_lo  = fcmp_eflags_lo | fminmax_nv_eflags_lo;

  assign fcmp_nv_eflags_lo = '{nv : (a_is_snan_li | b_is_snan_li), default: '0};
  assign fcompare_eflags_lo = fcmp_eflags_lo | fcmp_nv_eflags_lo;

  always_comb
    begin
      fminmax_lo = '0;
      unique case (op_i)
        e_op_fmin: fminmax_lo = ((~unordered_lo & flt_lo) | (feq_lo & a_sgn_lo & ~b_sgn_lo) | b_is_nan_lo)
                                ? a_is_nan_li ? dp_canonical_rec : a_rec_li
                                : b_is_nan_li ? dp_canonical_rec : b_rec_li;
        e_op_fmax: fminmax_lo = ((~unordered_lo & fgt_lo) | (feq_lo & ~a_sgn_lo & b_sgn_lo) | b_is_nan_lo)
                                ? a_is_nan_li ? dp_canonical_rec : a_rec_li
                                : b_is_nan_li ? dp_canonical_rec : b_rec_li;
        default : begin end
      endcase
    end

  // FCVT
  //
  logic [dp_rec_width_gp-1:0] i2f_lo;
  rv64_fflags_s i2f_eflags_lo;
  wire is_iu2f = (op_i == e_op_iu2f);
  wire [long_width_gp-1:0] a_sext_li = (ipr_i == e_pr_double) 
    ? a_i
    : is_iu2f
      ? long_width_gp'($unsigned(a_i[0+:word_width_gp]))
      : long_width_gp'($signed(a_i[0+:word_width_gp]));
  iNToRecFN
   #(.intWidth(long_width_gp)
     ,.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   i2f
    (.control(control_li)
     ,.signedIn(~is_iu2f)
     ,.in(a_sext_li)
     ,.roundingMode(rm_i)
     ,.out(i2f_lo)
     ,.exceptionFlags(i2f_eflags_lo)
     );

  // FSGNJ/FSGNJN/FSGNJX
  //
  logic [dp_float_width_gp-1:0] fsgn_lo;
  rv64_fflags_s fsgn_eflags_lo;

  logic sgn_li;
  always_comb
    if (opr_i == e_pr_double)
      unique case (op_i)
        e_op_fsgnj:  sgn_li =  b_fp_li[dp_float_width_gp-1];
        e_op_fsgnjn: sgn_li = ~b_fp_li[dp_float_width_gp-1];
        e_op_fsgnjx: sgn_li =  b_fp_li[dp_float_width_gp-1] ^ a_fp_li[dp_float_width_gp-1];
        default : sgn_li = '0;
      endcase
    else
      unique case (op_i)
        e_op_fsgnj:  sgn_li =  b_fp_li[sp_float_width_gp-1];
        e_op_fsgnjn: sgn_li = ~b_fp_li[sp_float_width_gp-1];
        e_op_fsgnjx: sgn_li =  b_fp_li[sp_float_width_gp-1] ^ a_fp_li[sp_float_width_gp-1];
        default : sgn_li = '0;
      endcase

  assign fsgn_lo = (opr_i == e_pr_double)
                   ? {sgn_li, a_fp_li[0+:dp_float_width_gp-1]}
                   : {32'hffffffff, sgn_li, a_fp_li[0+:sp_float_width_gp-1]};
  assign fsgn_eflags_lo = '0;

  // Recoded result selection
  //
  logic [dp_rec_width_gp-1:0] rec_result_lo;
  logic [long_width_gp-1:0] direct_result_lo;
  rv64_fflags_s rec_eflags_lo, direct_eflags_lo;
  always_comb
    begin
      rec_result_lo    = '0;
      direct_result_lo = '0;
      rec_eflags_lo    = '0;
      direct_eflags_lo = '0;
      unique case (op_i)
        e_op_f2f:
          begin
            rec_result_lo = a_rec_li;
            rec_eflags_lo = '0;
          end
        e_op_i2f, e_op_iu2f:
          begin
            rec_result_lo = i2f_lo;
            rec_eflags_lo = i2f_eflags_lo;
          end
        e_op_fmin, e_op_fmax:
          begin
            rec_result_lo = fminmax_lo;
            rec_eflags_lo = fminmax_eflags_lo;
          end
        e_op_fsgnj, e_op_fsgnjn, e_op_fsgnjx:
          begin
            direct_result_lo = (opr_i == e_pr_single)
                               ? {32'hffffffff, fsgn_lo[0+:word_width_gp]}
                               : fsgn_lo;
            direct_eflags_lo = fsgn_eflags_lo;
          end
        e_op_imvf:
          begin
            direct_result_lo = (opr_i == e_pr_single)
                               ? {32'hffffffff, a_sext_li[0+:word_width_gp]}
                               : a_sext_li;
            direct_eflags_lo = '0;
          end
        default: begin end
      endcase
    end

  wire is_direct_result = 
      (op_i inside {e_op_imvf, e_op_fsgnj, e_op_fsgnjn, e_op_fsgnjx});

  // Recoded result selection
  //
  logic [dp_float_width_gp-1:0] result_lo, fp_result_lo;
  logic [4:0] fp_eflags_lo, dir_eflags_lo, eflags_lo;
  bp_be_hardfloat_fpu_recode_out
   recode_out
    (.rec_i(rec_result_lo)
     ,.rec_eflags_i(rec_eflags_lo)
     ,.opr_i(opr_i)
     ,.rm_i(rm_i)

     ,.result_o(fp_result_lo)
     ,.result_eflags_o(fp_eflags_lo)
     );

  assign dir_eflags_lo = (opr_i == e_pr_double) ? direct_eflags_lo : direct_eflags_lo;

  assign result_lo = is_direct_result ? direct_result_lo : fp_result_lo;
  assign eflags_lo = is_direct_result ? dir_eflags_lo : fp_eflags_lo;
  bsg_dff_chain
   #(.width_p($bits(rv64_fflags_s)+long_width_gp)
     ,.num_stages_p(latency_p-1)
     )
   retimer_chain
    (.clk_i(clk_i)

     ,.data_i({eflags_lo, result_lo})
     ,.data_o({eflags_o, o})
     );

endmodule


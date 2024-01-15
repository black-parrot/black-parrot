/**
 *
 * Name:
 *   bp_be_pipe_aux.v
 *
 * Description:
 *   Pipeline for RISC-V floating point auxiliary instructions
 *
 * Notes:
 *
 */
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_aux
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam reservation_width_lp = `bp_be_reservation_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [reservation_width_lp-1:0]  reservation_i
   , input                             flush_i
   , input rv64_frm_e                  frm_dyn_i

   // Pipeline results
   , output logic [dpath_width_gp-1:0] data_o
   , output rv64_fflags_s              fflags_o
   , output logic                      v_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_reservation_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [dp_rec_width_gp-1:0] frs1 = reservation.fsrc1;
  wire [dp_rec_width_gp-1:0] frs2 = reservation.fsrc2;
  wire [dword_width_gp-1:0]  irs1 = reservation.isrc1;
  wire [dword_width_gp-1:0]  irs2 = reservation.isrc2;

  wire ops_v = decode.fp_tag == e_fp_sp;
  wire opw_v = decode.int_tag == e_int_word;

  //
  // Control bits for the FPU
  //   The control bits control tininess, which is fixed in RISC-V
  rv64_frm_e frm_li;
  // VCS / DVE 2016.1 has an issue with the 'assign' variant of the following code
  always_comb frm_li = rv64_frm_e'((instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : instr.t.fmatype.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  //
  // FCLASS
  //
  logic frs1_is_nan, frs1_is_inf, frs1_is_zero;
  logic frs1_sign;
  logic [dp_exp_width_gp+1:0] frs1_sexp;
  logic [dp_sig_width_gp:0] frs1_sig;
  recFNToRawFN
   #(.expWidth(dp_exp_width_gp) ,.sigWidth(dp_sig_width_gp))
   frs1_class
    (.in(frs1)
     ,.isNaN(frs1_is_nan)
     ,.isInf(frs1_is_inf)
     ,.isZero(frs1_is_zero)
     ,.sign(frs1_sign)
     ,.sExp(frs1_sexp)
     ,.sig(frs1_sig)
     );
  localparam [dp_exp_width_gp:0] minNormDpExp = (1<<(dp_exp_width_gp - 1)) + 2;
  localparam [sp_exp_width_gp:0] minNormSpExp = (1<<(sp_exp_width_gp - 1)) + 2;

  localparam bias_adj_lp = (1 << sp_exp_width_gp) - (1 << dp_exp_width_gp);
  wire [sp_exp_width_gp:0] frs1_sexp_sp = frs1_sexp + bias_adj_lp;
  wire [dp_exp_width_gp:0] frs1_sexp_dp = frs1_sexp + 0;

  wire frs1_is_sub = (decode.fp_tag == e_fp_sp)
    ? ~frs1_is_zero & ~frs1_is_inf & ~frs1_is_nan & (frs1_sexp_sp < minNormSpExp)
    : ~frs1_is_zero & ~frs1_is_inf & ~frs1_is_nan & (frs1_sexp_dp < minNormDpExp);

  logic frs1_is_snan;
  isSigNaNRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   frs1_sig_nan
    (.in(frs1)
     ,.isSigNaN(frs1_is_snan)
     );

  logic frs2_is_nan, frs2_is_inf, frs2_is_zero;
  logic frs2_sign;
  logic [dp_exp_width_gp+1:0] frs2_sexp;
  recFNToRawFN
   #(.expWidth(dp_exp_width_gp) ,.sigWidth(dp_sig_width_gp))
   rs2_class
    (.in(frs2)
     ,.isNaN(frs2_is_nan)
     ,.isInf(frs2_is_inf)
     ,.isZero(frs2_is_zero)
     ,.sign(frs2_sign)
     ,.sExp(frs2_sexp)
     ,.sig()
     );

  logic frs2_is_snan;
  isSigNaNRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   frs2_sig_nan
    (.in(frs2)
     ,.isSigNaN(frs2_is_snan)
     );

  rv64_fclass_s fclass_result;
  rv64_fflags_s fclass_fflags;
  assign fclass_result = '{q_nan  : frs1_is_nan & ~frs1_is_snan
                           ,s_nan : frs1_is_nan &  frs1_is_snan
                           ,p_inf : ~frs1_sign & frs1_is_inf
                           ,p_norm: ~frs1_sign & ~frs1_is_sub & ~frs1_is_zero & ~frs1_is_inf & ~frs1_is_nan
                           ,p_sub : ~frs1_sign & frs1_is_sub
                           ,p_zero: ~frs1_sign & frs1_is_zero
                           ,n_zero:  frs1_sign & frs1_is_zero
                           ,n_sub :  frs1_sign & frs1_is_sub
                           ,n_norm:  frs1_sign & ~frs1_is_sub & ~frs1_is_zero & ~frs1_is_inf & ~frs1_is_nan
                           ,n_inf :  frs1_sign & frs1_is_inf
                           ,default: '0
                           };
  assign fclass_fflags = '0;

  //
  // Move Float -> Int
  //
  bp_be_int_reg_s fmvi_result;
  rv64_fflags_s fmvi_fflags;

  assign fmvi_result = '{tag: decode.int_tag, val: frs1};
  assign fmvi_fflags = '0;

  //
  // FCVT Int -> Float
  //
  bp_be_fp_reg_s i2f_result;
  rv64_fflags_s i2f_fflags;

  wire rs1_unsigned = decode.fu_op inside {e_aux_op_iu2f};
  logic [dp_rec_width_gp-1:0] i2d_out;
  rv64_fflags_s i2d_fflags;
  iNToRecFN
   #(.intWidth(dword_width_gp)
     ,.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   i2d
    (.control(control_li)
     ,.signedIn(!rs1_unsigned)
     ,.in(irs1)
     ,.roundingMode(frm_li)
     ,.out(i2d_out)
     ,.exceptionFlags(i2d_fflags)
     );

  logic [sp_rec_width_gp-1:0] i2s_out;
  rv64_fflags_s i2s_fflags;
  iNToRecFN
   #(.intWidth(dword_width_gp)
     ,.expWidth(sp_exp_width_gp)
     ,.sigWidth(sp_sig_width_gp)
     )
   i2s
    (.control(control_li)
     ,.signedIn(!rs1_unsigned)
     ,.in(irs1)
     ,.roundingMode(frm_li)
     ,.out(i2s_out)
     ,.exceptionFlags(i2s_fflags)
     );

  logic [dp_rec_width_gp-1:0] i2s2d_out;
  recFNToRecFN_unsafe
   #(.inExpWidth(sp_exp_width_gp)
     ,.inSigWidth(sp_sig_width_gp)
     ,.outExpWidth(dp_exp_width_gp)
     ,.outSigWidth(dp_sig_width_gp)
     )
   i2s2d
    (.in(i2s_out)
     ,.out(i2s2d_out)
     );

  assign i2f_result = '{tag: decode.fp_tag, rec: ops_v ? i2s2d_out : i2d_out};
  assign i2f_fflags = ops_v ? i2s_fflags : i2d_fflags;

  //
  // FCVT Float -> Int
  //
  bp_be_int_reg_s f2i_result;
  rv64_fflags_s f2i_fflags;

  // Double -> dword conversion
  logic [dword_width_gp-1:0] f2dw_out;
  rv64_iflags_s f2dw_iflags;
  rv64_fflags_s dword_fflags;
  wire signed_f2i = (decode.fu_op inside {e_aux_op_f2i});
  recFNToIN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp), .intWidth(dword_width_gp))
   f2dw
    (.control(control_li)
     ,.in(frs1)
     ,.roundingMode(frm_li)
     ,.signedOut(signed_f2i)
     ,.out(f2dw_out)
     ,.intExceptionFlags(f2dw_iflags)
     );
  assign dword_fflags = '{nv: f2dw_iflags.nv | f2dw_iflags.of, nx: f2dw_iflags.nx, default: '0};

  logic [word_width_gp-1:0] f2w_out;
  rv64_iflags_s f2w_iflags;
  rv64_fflags_s word_fflags;
  recFNToIN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp), .intWidth(word_width_gp))
   f2w
    (.control(control_li)
     ,.in(frs1)
     ,.roundingMode(frm_li)
     ,.signedOut(signed_f2i)
     ,.out(f2w_out)
     ,.intExceptionFlags(f2w_iflags)
     );
  assign word_fflags = '{nv: f2w_iflags.nv | f2w_iflags.of, nx: f2w_iflags.nx, default: '0};

  assign f2i_result = '{tag: decode.int_tag, val: opw_v ? f2w_out : f2dw_out};
  assign f2i_fflags = opw_v ? word_fflags : dword_fflags;

  //
  // Float to Float
  //
  bp_be_fp_reg_s f2f_result;
  rv64_fflags_s f2f_fflags;

  // DP->SP conversion is a rounding operation
  logic [sp_rec_width_gp-1:0] dp2sp_round;
  rv64_fflags_s dp2sp_fflags;
  recFNToRecFN
   #(.inExpWidth(dp_exp_width_gp)
     ,.inSigWidth(dp_sig_width_gp)
     ,.outExpWidth(sp_exp_width_gp)
     ,.outSigWidth(sp_sig_width_gp)
     )
   f2f_round
    (.control(control_li)
     ,.in(frs1)
     ,.roundingMode(frm_li)
     ,.out(dp2sp_round)
     ,.exceptionFlags(dp2sp_fflags)
     );

  logic [dp_rec_width_gp-1:0] dp2sp_result;
  recFNToRecFN_unsafe
   #(.inExpWidth(sp_exp_width_gp)
     ,.inSigWidth(sp_sig_width_gp)
     ,.outExpWidth(dp_exp_width_gp)
     ,.outSigWidth(dp_sig_width_gp)
     )
   f2f_recover
    (.in(dp2sp_round)
     ,.out(dp2sp_result)
     );

  // SP->DP conversion is a NOP, except for canonicalizing NaNs
  logic [dp_rec_width_gp-1:0] sp2dp_result;
  rv64_fflags_s sp2dp_fflags;
  assign sp2dp_result = frs1_is_nan ? dp_canonical_rec : frs1;
  assign sp2dp_fflags = '0;

  assign f2f_result = '{tag: ops_v ? e_fp_dp : e_fp_sp, rec: ops_v ? sp2dp_result : dp2sp_result};
  assign f2f_fflags = ops_v ? sp2dp_fflags : dp2sp_fflags;

  //
  // FMV Int -> Float
  //
  wire [dword_width_gp-1:0] imvf_mask = {{word_width_gp{opw_v}}} << word_width_gp;
  wire [dword_width_gp-1:0] imvf_raw = irs1 | imvf_mask;

  //
  // FSGNJ
  //
  logic [dword_width_gp-1:0] fsgnj_raw;
  wire [`BSG_SAFE_CLOG2(dword_width_gp)-1:0] signbit =
    (decode.fp_tag == e_fp_dp) ? (dword_width_gp-1) : (word_width_gp-1);
  wire invbox_frs1 = ops_v & ~&frs1[word_width_gp+:word_width_gp];
  wire invbox_frs2 = ops_v & ~&frs2[word_width_gp+:word_width_gp];
  wire [dword_width_gp-1:0] fsgnj_a = invbox_frs1 ? sp_canonical_nan : frs1;
  wire [dword_width_gp-1:0] fsgnj_b = invbox_frs2 ? sp_canonical_nan : frs2;
  always_comb
    begin
      fsgnj_raw = fsgnj_a;
      unique case (decode.fu_op)
        e_aux_op_fsgnjn: fsgnj_raw[signbit] = ~fsgnj_b[signbit];
        e_aux_op_fsgnjx: fsgnj_raw[signbit] =  fsgnj_b[signbit] ^ fsgnj_a[signbit];
        e_aux_op_fsgnj : fsgnj_raw[signbit] =  fsgnj_b[signbit];
        default: begin end
      endcase
    end

  //
  // Box raw result
  //
  bp_be_fp_reg_s raw_result;
  rv64_fflags_s raw_fflags;
  wire [dword_width_gp-1:0] raw_src = (decode.fu_op == e_aux_op_imvf) ? imvf_raw : fsgnj_raw;
  bp_be_fp_box
   #(.bp_params_p(bp_params_p))
   fp_box
    (.raw_i(raw_src)
     ,.tag_i(decode.fp_tag)
     ,.reg_o(raw_result)
     );
  assign raw_fflags = '0;

  //
  // FEQ, FLT, FLE
  //
  bp_be_fp_reg_s fcmp_result;
  rv64_fflags_s fcmp_fflags;

  logic flt_lo, feq_lo, fgt_lo, unordered_lo;
  wire is_feq_li  = (decode.fu_op == e_aux_op_feq);
  wire is_flt_li  = (decode.fu_op == e_aux_op_flt);
  wire is_fle_li  = (decode.fu_op == e_aux_op_fle);
  wire is_fmax_li = (decode.fu_op == e_aux_op_fmax);
  wire is_fmin_li = (decode.fu_op == e_aux_op_fmin);
  wire signaling_li = is_flt_li | is_fle_li;
  compareRecFN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp))
   fcmp
    (.a(frs1)
     ,.b(frs2)
     ,.signaling(signaling_li)
     ,.lt(flt_lo)
     ,.eq(feq_lo)
     ,.gt(fgt_lo)
     ,.unordered(unordered_lo)
     ,.exceptionFlags(fcmp_fflags)
     );
  wire fle_lo = ~fgt_lo;
  wire fcmp_out = (is_feq_li & feq_lo) | (is_flt_li & flt_lo) | (is_fle_li & (flt_lo | feq_lo));
  assign fcmp_result = '{tag: decode.fp_tag, rec: fcmp_out};

  //
  // FMIN-MAX
  //
  bp_be_fp_reg_s fminmax_result;
  rv64_fflags_s  fminmax_fflags;

  logic [dp_rec_width_gp-1:0] fminmax_out;
  always_comb
    if (frs1_is_nan & frs2_is_nan)
      fminmax_out = dp_canonical_rec;
    else if (frs1_is_nan & ~frs2_is_nan)
      fminmax_out = frs2;
    else if (~frs1_is_nan & frs2_is_nan)
      fminmax_out = frs1;
    else if (feq_lo)
      fminmax_out = (is_fmin_li ^ frs1_sign) ? frs2 : frs1;
    else
      fminmax_out = (is_fmax_li ^ flt_lo) ? frs1 : frs2;

  assign fminmax_result = '{tag: decode.fp_tag, rec: fminmax_out};
  assign fminmax_fflags = '{nv: (frs1_is_snan | frs2_is_snan), default: '0};

  //
  // Get the final result
  //
  bp_be_fp_reg_s faux_result;
  rv64_fflags_s faux_fflags;
  always_comb
    case (decode.fu_op)
      e_aux_op_imvf, e_aux_op_fsgnj, e_aux_op_fsgnjn, e_aux_op_fsgnjx:
        begin
          faux_result = raw_result;
          faux_fflags = raw_fflags;
        end
      e_aux_op_i2f, e_aux_op_iu2f:
        begin
          faux_result = i2f_result;
          faux_fflags = i2f_fflags;
        end
      e_aux_op_f2f:
        begin
          faux_result = f2f_result;
          faux_fflags = f2f_fflags;
        end
      // e_aux_op_fmin, e_aux_op_fmax:
      default:
        begin
          faux_result = fminmax_result;
          faux_fflags = fminmax_fflags;
        end
    endcase

  logic [dword_width_gp-1:0] iaux_result;
  rv64_fflags_s iaux_fflags;
  always_comb
    case (decode.fu_op)
      e_aux_op_fmvi:
        begin
          iaux_result = fmvi_result;
          iaux_fflags = fmvi_fflags;
        end
      e_aux_op_f2i, e_aux_op_f2iu:
        begin
          iaux_result = f2i_result;
          iaux_fflags = f2i_fflags;
        end
      e_aux_op_feq, e_aux_op_flt, e_aux_op_fle:
        begin
          iaux_result = fcmp_result;
          iaux_fflags = fcmp_fflags;
        end
      // e_aux_op_fclass
      default:
        begin
          iaux_result = fclass_result;
          iaux_fflags = fclass_fflags;
        end
    endcase

  logic [dpath_width_gp-1:0] ird_data_lo;
  bp_be_int_box
   #(.bp_params_p(bp_params_p))
   int_box
    (.raw_i(iaux_result)
     ,.tag_i(decode.int_tag)
     ,.unsigned_i(1'b0)
     ,.reg_o(ird_data_lo)
     );

  wire [dpath_width_gp-1:0] frd_data_lo = faux_result;

  wire [dpath_width_gp-1:0] aux_result = decode.irf_w_v ? ird_data_lo : frd_data_lo;
  wire [$bits(rv64_fflags_s)-1:0] aux_fflags = decode.irf_w_v ? iaux_fflags : faux_fflags;

  wire aux_v_li = reservation.v & reservation.decode.pipe_aux_v;
  bsg_dff_chain
   #(.width_p($bits(bp_be_fp_reg_s)+$bits(rv64_fflags_s)+1), .num_stages_p(1))
   retiming_chain
    (.clk_i(clk_i)

     ,.data_i({aux_fflags, aux_result, aux_v_li})
     ,.data_o({fflags_o, data_o, v_o})
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_be_pipe_aux)


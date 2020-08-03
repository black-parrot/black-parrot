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
module bp_be_pipe_aux
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter latency_p = "inv"

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i
   , input rv64_frm_e                  frm_dyn_i

   // Pipeline results
   , output [dpath_width_p-1:0]        data_o
   , output rv64_fflags_s              fflags_o
   );

  // Suppress unused signal warning
  wire unused0 = clk_i;
  wire unused1 = reset_i;

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;
  bp_be_fp_reg_s frs1, frs2;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  assign frs1 = reservation.rs1;
  assign frs2 = reservation.rs2;

  //
  // Control bits for the FPU
  //   The control bits control tininess, which is fixed in RISC-V
  rv64_frm_e frm_li;
  assign frm_li = (instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : rv64_frm_e'(instr.t.fmatype.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  //
  // Convert recoded registers to raw
  //
  logic [dword_width_p-1:0] frs1_raw;
  bp_be_rec_to_fp
   #(.bp_params_p(bp_params_p))
   frs1_rec2raw
    (.rec_i(frs1.rec)

     ,.raw_sp_not_dp_i(frs1.sp_not_dp)
     ,.raw_o(frs1_raw)
     );

  logic [dword_width_p-1:0] frs2_raw;
  bp_be_rec_to_fp
   #(.bp_params_p(bp_params_p))
   frs2_rec2raw
    (.rec_i(frs2.rec)

     ,.raw_sp_not_dp_i(frs2.sp_not_dp)
     ,.raw_o(frs2_raw)
     );

  //
  // Move Float -> Int
  //
  logic [dword_width_p-1:0] fmvi_result;
  rv64_fflags_s fmvi_fflags;

  assign fmvi_result =
      decode.opw_v
      ? {{word_width_p{frs1_raw[word_width_p-1]}}, frs1_raw[0+:word_width_p]}
      : frs1_raw;
  assign fmvi_fflags = '0;

  //
  // FMV Int -> Float
  //
  wire signed_i2f = (decode.fu_op inside {e_aux_op_i2f, e_aux_op_imvf});
  wire i2f_sigext = signed_i2f & frs1[word_width_p-1];
  wire [dword_width_p-1:0] imvf_src = decode.opw_v ? ({{word_width_p{i2f_sigext}}, frs1[0+:word_width_p]}) : frs1;

  bp_be_fp_reg_s imvf_result;
  rv64_fflags_s imvf_fflags;
  bp_be_fp_to_rec
   #(.bp_params_p(bp_params_p))
   fp_to_rec
    (.raw_i(imvf_src)
     ,.raw_sp_not_dp_i(decode.ops_v)

     ,.rec_sp_not_dp_o(imvf_result.sp_not_dp)
     ,.rec_o(imvf_result.rec)
     );
  assign imvf_fflags = '0;

  //
  // FCVT Int -> Float
  //
  wire [dword_width_p-1:0] i2f_src = decode.opw_v ? ({{word_width_p{i2f_sigext}}, frs1[0+:word_width_p]}) : frs1;

  bp_be_fp_reg_s i2f_result;
  rv64_fflags_s i2f_fflags;

  logic [dp_rec_width_gp-1:0] i2d_out;
  rv64_fflags_s i2d_fflags;
  iNToRecFN
   #(.intWidth(dword_width_p)
     ,.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   i2d
    (.control(control_li)
     ,.signedIn(signed_i2f)
     ,.in(i2f_src)
     ,.roundingMode(frm_li)
     ,.out(i2d_out)
     ,.exceptionFlags(i2d_fflags)
     );

  // Some of the edge cases aren't handled well by i2d
  // There's a lot of redundant logic here, though
  logic [sp_rec_width_gp-1:0] i2s_out;
  rv64_fflags_s i2s_fflags;
  iNToRecFN
   #(.intWidth(dword_width_p)
     ,.expWidth(sp_exp_width_gp)
     ,.sigWidth(sp_sig_width_gp)
     )
    i2s
    (.control(control_li)
     ,.signedIn(signed_i2f)
     ,.in(i2f_src)
     ,.roundingMode(frm_li)
     ,.out(i2s_out)
     ,.exceptionFlags(i2s_fflags)
     );

  logic [dp_rec_width_gp-1:0] i2s2d_out;
  recFNToRecFN
   #(.inExpWidth(sp_exp_width_gp)
     ,.inSigWidth(sp_sig_width_gp)
     ,.outExpWidth(dp_exp_width_gp)
     ,.outSigWidth(dp_sig_width_gp)
     )
  i2s2d
   (.control(control_li)
    ,.in(i2s_out)
    ,.roundingMode(frm_li)
    ,.out(i2s2d_out)
    ,.exceptionFlags()
    );
  
  assign i2f_result = '{sp_not_dp: decode.ops_v, rec: decode.ops_v ? i2s2d_out : i2d_out};
  assign i2f_fflags = decode.ops_v ? i2s_fflags : i2d_fflags;

  //
  // FCVT Float -> Int
  //
  logic [dword_width_p-1:0] f2i_result;
  rv64_fflags_s f2i_fflags;

  // Double -> dword conversion
  logic [dword_width_p-1:0] f2dw_out;
  rv64_iflags_s f2dw_iflags;
  wire signed_f2i = (decode.fu_op inside {e_aux_op_f2i, e_aux_op_fmvi});
  recFNToIN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp), .intWidth(dword_width_p))
   f2dw
    (.control(control_li)
     ,.in(frs1.rec)
     ,.roundingMode(frm_li)
     ,.signedOut(signed_f2i)
     ,.out(f2dw_out)
     ,.intExceptionFlags(f2dw_iflags)
     );

  // It's possible we can do away with this int converter and manually
  //   check for inexact exceptions.
  logic [word_width_p-1:0] f2w_out;
  rv64_iflags_s f2w_iflags;
  recFNToIN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp), .intWidth(word_width_p))
   f2w
    (.control(control_li)
     ,.in(frs1.rec)
     ,.roundingMode(frm_li)
     ,.signedOut(signed_f2i)
     ,.out(f2w_out)
     ,.intExceptionFlags(f2w_iflags)
     );

  assign f2i_result = decode.opw_v
                      ? {{word_width_p{f2w_out[word_width_p-1]}}, f2w_out}
                      : f2dw_out;
  assign f2i_fflags = decode.opw_v
                      ? '{nv: f2w_iflags.nv | f2w_iflags.of, nx: f2w_iflags.nx, default: '0}
                      : '{nv: f2dw_iflags.nv | f2dw_iflags.of, nx: f2dw_iflags.nx, default: '0};

  //
  // FCLASS
  //

  //
  // NaN unboxing
  //
  wire frs1_raw_v_li = ~decode.ops_v | frs1.sp_not_dp;
  wire [dp_rec_width_gp-1:0] frs1_rec_li = frs1_raw_v_li ? frs1.rec : dp_canonical_rec;
  wire [dword_width_p-1:0] frs1_raw_li = frs1_raw_v_li ? frs1_raw : sp_canonical_nan;

  wire frs2_raw_v_li = ~decode.ops_v | frs2.sp_not_dp;
  wire [dp_rec_width_gp-1:0] frs2_rec_li = frs2_raw_v_li ? frs2.rec : dp_canonical_rec;
  wire [dword_width_p-1:0] frs2_raw_li = frs2_raw_v_li ? frs2_raw : sp_canonical_nan;

  logic frs1_is_nan, frs1_is_inf, frs1_is_zero;
  logic frs1_sign;
  logic [dp_exp_width_gp+1:0] frs1_sexp;
  logic [dp_sig_width_gp:0] frs1_sig;
  recFNToRawFN
   #(.expWidth(dp_exp_width_gp) ,.sigWidth(dp_sig_width_gp))
   frs1_class
    (.in(frs1.rec)
     ,.isNaN(frs1_is_nan)
     ,.isInf(frs1_is_inf)
     ,.isZero(frs1_is_zero)
     ,.sign(frs1_sign)
     ,.sExp(frs1_sexp)
     ,.sig(frs1_sig)
     );
  wire frs1_is_sub = decode.ops_v
                     ? ~|frs1_raw[sp_sig_width_gp-1+:sp_exp_width_gp] & |frs1_raw[0+:sp_sig_width_gp-1]
                     : ~|frs1_raw[dp_sig_width_gp-1+:dp_exp_width_gp] & |frs1_raw[0+:dp_sig_width_gp-1];

  logic frs1_is_snan;
  isSigNaNRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   frs1_sig_nan
    (.in(frs1_rec_li)
     ,.isSigNaN(frs1_is_snan)
     );

  logic frs2_is_nan, frs2_is_inf, frs2_is_zero;
  logic frs2_sign;
  logic [dp_exp_width_gp+1:0] frs2_sexp;
  recFNToRawFN
   #(.expWidth(dp_exp_width_gp) ,.sigWidth(dp_sig_width_gp))
   frs2_class
    (.in(frs2.rec)
     ,.isNaN(frs2_is_nan)
     ,.isInf(frs2_is_inf)
     ,.isZero(frs2_is_zero)
     ,.sign(frs2_sign)
     ,.sExp(frs2_sexp)
     ,.sig()
     );
  wire frs2_is_sub = decode.ops_v
                     ? ~|frs2_raw[sp_sig_width_gp-1+:sp_exp_width_gp] & |frs2_raw[0+:sp_sig_width_gp-1]
                     : ~|frs2_raw[dp_sig_width_gp-1+:dp_exp_width_gp] & |frs2_raw[0+:dp_sig_width_gp-1];

  logic frs2_is_snan;
  isSigNaNRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   frs2_sig_nan
    (.in(frs2_rec_li)
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
  // Float to Float
  //
  bp_be_fp_reg_s f2f_result;
  rv64_fflags_s f2f_fflags;

  bp_hardfloat_rec_sp_s d2s_round;
  rv64_fflags_s d2s_round_fflags;
  roundAnyRawFNToRecFN
   #(.inExpWidth(dp_exp_width_gp)
     ,.inSigWidth(dp_sig_width_gp)
     ,.outExpWidth(sp_exp_width_gp)
     ,.outSigWidth(sp_sig_width_gp)
     )
   round_sp
    (.control(control_li)
     ,.invalidExc('0)
     ,.infiniteExc('0)
     ,.in_isNaN(frs1_is_nan)
     ,.in_isInf(frs1_is_inf)
     ,.in_isZero(frs1_is_zero)
     ,.in_sign(frs1_sign)
     ,.in_sExp(frs1_sexp)
     ,.in_sig(frs1_sig)
     ,.roundingMode(frm_li)
     ,.out(d2s_round)
     ,.exceptionFlags(d2s_round_fflags)
     );

  localparam bias_adj_lp = (1 << dp_exp_width_gp) - (1 << sp_exp_width_gp);
  bp_hardfloat_rec_dp_s d2s2d_final;

  wire [dp_exp_width_gp:0] adjusted_exp = d2s_round.exp + bias_adj_lp;
  wire [2:0]                   exp_code = d2s_round.exp[sp_exp_width_gp-:3];
  wire                          special = (exp_code == '0) || (exp_code >= 3'd6);

  assign d2s2d_final = '{sign  : d2s_round.sign
                         ,exp  : special ? {exp_code, adjusted_exp[0+:dp_exp_width_gp-2]} : adjusted_exp
                         ,fract: d2s_round.fract << (dp_sig_width_gp-sp_sig_width_gp)
                         };

  // SP->DP conversion is a NOP, except for canonicalizing NaNs
  wire [dp_rec_width_gp-1:0] frs1_canon_dp = (&frs1.rec[dp_rec_width_gp-2-:3]) ? dp_canonical_rec : frs1.rec;

  assign f2f_result = '{sp_not_dp: decode.ops_v, rec: decode.ops_v ? d2s2d_final : frs1_canon_dp};
  assign f2f_fflags = d2s_round_fflags;

  //
  // FSGNJ
  //
  bp_be_fp_reg_s fsgnj_result;
  rv64_fflags_s fsgnj_fflags;

  logic [dword_width_p-1:0] fsgnj_raw;
  logic sgn_lo;
  wire [`BSG_SAFE_CLOG2(dword_width_p)-1:0] signbit = decode.ops_v ? (word_width_p-1) : (dword_width_p-1);
  always_comb
    begin
      unique case (decode.fu_op)
        e_aux_op_fsgnj : sgn_lo = frs2_raw_li[signbit];
        e_aux_op_fsgnjn: sgn_lo = ~frs2_raw_li[signbit];
        e_aux_op_fsgnjx: sgn_lo = frs2_raw_li[signbit] ^ frs1_raw_li[signbit];
        default: sgn_lo = '0;
      endcase

      fsgnj_raw = frs1_raw_li;
      fsgnj_raw[signbit] = sgn_lo;
    end

  bp_be_fp_to_rec
   #(.bp_params_p(bp_params_p))
   fsgnj_recode
    (.raw_i(fsgnj_raw)
     ,.raw_sp_not_dp_i(decode.ops_v)

     ,.rec_sp_not_dp_o(fsgnj_result.sp_not_dp)
     ,.rec_o(fsgnj_result.rec)
     );
  assign fsgnj_fflags = '0;

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
    (.a(frs1_rec_li)
     ,.b(frs2_rec_li)
     ,.signaling(signaling_li)
     ,.lt(flt_lo)
     ,.eq(feq_lo)
     ,.gt(fgt_lo)
     ,.unordered(unordered_lo)
     ,.exceptionFlags(fcmp_fflags)
     );
  wire fle_lo = ~fgt_lo;
  wire fcmp_out = (is_feq_li & feq_lo) | (is_flt_li & flt_lo) | (is_fle_li & (flt_lo | feq_lo));
  assign fcmp_result = '{sp_not_dp: decode.ops_v, rec: fcmp_out};

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
      fminmax_out = frs2_rec_li;
    else if (~frs1_is_nan & frs2_is_nan)
      fminmax_out = frs1_rec_li;
    else if (feq_lo)
      fminmax_out = (is_fmin_li ^ frs1_sign) ? frs2_rec_li : frs1_rec_li;
    else
      fminmax_out = (is_fmax_li ^ flt_lo) ? frs1_rec_li : frs2_rec_li;

  assign fminmax_result = '{sp_not_dp: decode.ops_v, rec: fminmax_out};
  assign fminmax_fflags = '{nv: (frs1_is_snan | frs2_is_snan), default: '0};

  //
  // Get the final result
  //
  bp_be_fp_reg_s faux_result;
  rv64_fflags_s faux_fflags;
  always_comb
    begin
      faux_result = '0;
      faux_fflags = '0;

      case (decode.fu_op)
        // Transfer instructions
        e_aux_op_imvf:
          begin
            faux_result = imvf_result;
            faux_fflags = imvf_fflags;
          end
        e_aux_op_fmvi:
          begin
            faux_result = fmvi_result;
            faux_fflags = fmvi_fflags;
          end
        e_aux_op_f2i, e_aux_op_f2iu:
          begin
            faux_result = f2i_result;
            faux_fflags = f2i_fflags;
          end
        e_aux_op_i2f, e_aux_op_iu2f:
          begin
            faux_result = i2f_result;
            faux_fflags = i2f_fflags;
          end
        e_aux_op_fsgnj, e_aux_op_fsgnjn, e_aux_op_fsgnjx:
          begin
            faux_result = fsgnj_result;
            faux_fflags = fsgnj_fflags;
          end
        e_aux_op_f2f:
          begin
            faux_result = f2f_result;
            faux_fflags = f2f_fflags;
          end

        // Comparison instructions
        e_aux_op_fmin, e_aux_op_fmax:
          begin
            faux_result = fminmax_result;
            faux_fflags = fminmax_fflags;
          end
        e_aux_op_feq, e_aux_op_flt, e_aux_op_fle:
          begin
            faux_result = fcmp_result;
            faux_fflags = fcmp_fflags;
          end
        e_aux_op_fclass:
          begin
            faux_result = fclass_result;
            faux_fflags = fclass_fflags;
          end
        default: begin end
      endcase
    end

  bsg_dff_chain
   #(.width_p($bits(bp_be_fp_reg_s)+$bits(rv64_fflags_s)), .num_stages_p(latency_p-1))
   retiming_chain
    (.clk_i(clk_i)

     ,.data_i({faux_fflags, faux_result})
     ,.data_o({fflags_o, data_o})
     );

endmodule


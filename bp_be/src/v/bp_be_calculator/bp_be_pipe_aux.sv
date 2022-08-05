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

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i
   , input                             flush_i
   , input rv64_frm_e                  frm_dyn_i

   // Pipeline results
   , output logic [dpath_width_gp-1:0] data_o
   , output rv64_fflags_s              fflags_o
   , output logic                      v_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;
  bp_be_fp_reg_s frs1, frs2;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [dword_width_gp-1:0] rs1 = reservation.rs1;
  wire [dword_width_gp-1:0] rs2 = reservation.rs2;

  bp_be_nan_unbox
    #(.bp_params_p(bp_params_p))
    frs1_unbox
     (.reg_i(reservation.rs1)
      ,.unbox_i(decode.ops_v & !(decode.fu_op inside {e_aux_op_fmvi}))
      ,.reg_o(frs1)
      );

  bp_be_nan_unbox
    #(.bp_params_p(bp_params_p))
    frs2_unbox
     (.reg_i(reservation.rs2)
      ,.unbox_i(decode.ops_v)
      ,.reg_o(frs2)
      );

  //
  // Control bits for the FPU
  //   The control bits control tininess, which is fixed in RISC-V
  rv64_frm_e frm_li;
  // VCS / DVE 2016.1 has an issue with the 'assign' variant of the following code
  always_comb frm_li = (instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : rv64_frm_e'(instr.t.fmatype.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  //
  // Convert recoded registers to raw
  //
  logic [dword_width_gp-1:0] frs1_raw;
  rv64_fflags_s frs1_raw_fflags;
  bp_be_reg_to_fp
   #(.bp_params_p(bp_params_p))
   frs1_rec2raw
    (.reg_i(frs1)
     ,.raw_o(frs1_raw)
     ,.fflags_o(frs1_raw_fflags)
     );

  logic [dword_width_gp-1:0] frs2_raw;
  rv64_fflags_s frs2_raw_fflags;
  bp_be_reg_to_fp
   #(.bp_params_p(bp_params_p))
   frs2_rec2raw
    (.reg_i(frs2)
     ,.raw_o(frs2_raw)
     ,.fflags_o(frs2_raw_fflags)
     );

  //
  // Move Float -> Int
  //
  logic [dword_width_gp-1:0] fmvi_result;
  rv64_fflags_s fmvi_fflags;

  assign fmvi_result =
      decode.opw_v
      ? {{word_width_gp{frs1_raw[word_width_gp-1]}}, frs1_raw[0+:word_width_gp]}
      : frs1_raw;
  assign fmvi_fflags = frs1_raw_fflags;

  //
  // FMV Int -> Float
  //
  wire [dword_width_gp-1:0] imvf_src = decode.opw_v ? ({{word_width_gp{1'b1}}, rs1[0+:word_width_gp]}) : rs1;

  bp_be_fp_reg_s imvf_result;
  rv64_fflags_s imvf_fflags;
  bp_be_fp_to_reg
   #(.bp_params_p(bp_params_p))
   fp_to_reg
    (.raw_i(imvf_src)
     ,.reg_o(imvf_result)
     );
  assign imvf_fflags = '0;

  //
  // FCVT Int -> Float
  //
  wire signed_i2f = (decode.fu_op inside {e_aux_op_i2f});
  wire i2f_sigext = signed_i2f & rs1[word_width_gp-1];
  wire [dword_width_gp-1:0] i2f_src = decode.opw_v ? ({{word_width_gp{i2f_sigext}}, rs1[0+:word_width_gp]}) : rs1;
  bp_be_fp_reg_s i2f_result;
  rv64_fflags_s i2f_fflags;

  logic [dp_rec_width_gp-1:0] i2d_out;
  rv64_fflags_s i2d_fflags;
  iNToRecFN
   #(.intWidth(dword_width_gp)
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

  assign i2f_result = '{tag: decode.ops_v ? frm_li : e_fp_full, rec: i2d_out};
  assign i2f_fflags = i2d_fflags;

  //
  // FCVT Float -> Int
  //
  logic [dword_width_gp-1:0] f2i_result;
  rv64_fflags_s f2i_fflags;

  // Double -> dword conversion
  logic [dword_width_gp-1:0] f2dw_out;
  rv64_iflags_s f2dw_iflags;
  wire signed_f2i = (decode.fu_op inside {e_aux_op_f2i, e_aux_op_fmvi});
  recFNToIN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp), .intWidth(dword_width_gp))
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
  logic [word_width_gp-1:0] f2w_out;
  rv64_iflags_s f2w_iflags;
  recFNToIN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp), .intWidth(word_width_gp))
   f2w
    (.control(control_li)
     ,.in(frs1.rec)
     ,.roundingMode(frm_li)
     ,.signedOut(signed_f2i)
     ,.out(f2w_out)
     ,.intExceptionFlags(f2w_iflags)
     );

  assign f2i_result = decode.opw_v
                      ? {{word_width_gp{f2w_out[word_width_gp-1]}}, f2w_out}
                      : f2dw_out;

  // Bug in XSIM 2019.2 causes SEGV when assigning to structs with a mux
  // assign f2i_fflags = decode.opw_v
  //                     ? '{nv: f2w_iflags.nv | f2w_iflags.of, nx: f2w_iflags.nx, default: '0}
  //                     : '{nv: f2dw_iflags.nv | f2dw_iflags.of, nx: f2dw_iflags.nx, default: '0};
  rv64_fflags_s word_fflags;
  rv64_fflags_s dword_fflags;
  assign word_fflags = '{nv: f2w_iflags.nv | f2w_iflags.of, nx: f2w_iflags.nx, default: '0};
  assign dword_fflags = '{nv: f2dw_iflags.nv | f2dw_iflags.of, nx: f2dw_iflags.nx, default: '0};
  assign f2i_fflags = decode.opw_v ? word_fflags : dword_fflags;

  //
  // FCLASS
  //

  //
  // NaN unboxing
  //
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
    (.in(frs1.rec)
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
    (.in(frs2.rec)
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
  assign fclass_fflags = frs1_raw_fflags;

  //
  // Float to Float
  //
  bp_be_fp_reg_s f2f_result;
  rv64_fflags_s f2f_fflags;

  // SP->DP conversion is a NOP, except for canonicalizing NaNs
  wire [dp_rec_width_gp-1:0] frs1_canon_dp = frs1_is_nan ? dp_canonical_rec : frs1.rec;

  assign f2f_result = '{tag: decode.ops_v ? e_fp_full : frm_li, rec: decode.ops_v ? frs1.rec : frs1_canon_dp};
  assign f2f_fflags = '0;

  //
  // FSGNJ
  //
  bp_be_fp_reg_s fsgnj_result;
  rv64_fflags_s fsgnj_fflags;

  logic [dword_width_gp-1:0] fsgnj_raw;
  logic sgn_lo;
  wire [`BSG_SAFE_CLOG2(dword_width_gp)-1:0] frs1_signbit =
    (~decode.ops_v | (frs1.tag == e_fp_full)) ? (dword_width_gp-1) : (word_width_gp-1);
  wire [`BSG_SAFE_CLOG2(dword_width_gp)-1:0] frs2_signbit =
    (~decode.ops_v | (frs2.tag == e_fp_full)) ? (dword_width_gp-1) : (word_width_gp-1);
  wire [`BSG_SAFE_CLOG2(dword_width_gp)-1:0] frd_signbit  =
    (~decode.ops_v) ? (dword_width_gp-1) : (word_width_gp-1);
  always_comb
    begin
      unique case (decode.fu_op)
        e_aux_op_fsgnj : sgn_lo = frs2_raw[frs2_signbit];
        e_aux_op_fsgnjn: sgn_lo = ~frs2_raw[frs2_signbit];
        e_aux_op_fsgnjx: sgn_lo = frs2_raw[frs2_signbit] ^ frs1_raw[frs1_signbit];
        default: sgn_lo = '0;
      endcase

      fsgnj_raw = frs1_raw;
      fsgnj_raw[frd_signbit] = sgn_lo;
    end

  bp_be_fp_to_reg
   #(.bp_params_p(bp_params_p))
   fsgnj_fp_to_reg
    (.raw_i(fsgnj_raw)
     ,.reg_o(fsgnj_result)
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
    (.a(frs1.rec)
     ,.b(frs2.rec)
     ,.signaling(signaling_li)
     ,.lt(flt_lo)
     ,.eq(feq_lo)
     ,.gt(fgt_lo)
     ,.unordered(unordered_lo)
     ,.exceptionFlags(fcmp_fflags)
     );
  wire fle_lo = ~fgt_lo;
  wire fcmp_out = (is_feq_li & feq_lo) | (is_flt_li & flt_lo) | (is_fle_li & (flt_lo | feq_lo));
  assign fcmp_result = '{tag: decode.ops_v ? frm_li : e_fp_full, rec: fcmp_out};

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
      fminmax_out = frs2.rec;
    else if (~frs1_is_nan & frs2_is_nan)
      fminmax_out = frs1.rec;
    else if (feq_lo)
      fminmax_out = (is_fmin_li ^ frs1_sign) ? frs2.rec : frs1.rec;
    else
      fminmax_out = (is_fmax_li ^ flt_lo) ? frs1.rec : frs2.rec;

  assign fminmax_result = '{tag: decode.ops_v ? frm_li : e_fp_full, rec: fminmax_out};
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

  wire faux_v_li = reservation.v & reservation.decode.pipe_aux_v;
  bsg_dff_chain
   #(.width_p($bits(bp_be_fp_reg_s)+$bits(rv64_fflags_s)+1), .num_stages_p(1))
   retiming_chain
    (.clk_i(clk_i)

     ,.data_i({faux_fflags, faux_result, faux_v_li})
     ,.data_o({fflags_o, data_o, v_o})
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_be_pipe_aux)


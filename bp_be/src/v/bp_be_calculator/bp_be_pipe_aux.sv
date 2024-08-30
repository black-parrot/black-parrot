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
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)
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

  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);
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

  wire ops_v = decode.frd_tag == e_fp_sp;
  wire opw_v = decode.ird_tag == e_int_word;

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
  bp_hardfloat_raw_dp_s frs1_raw;
  bp_be_rec_to_raw
   #(.bp_params_p(bp_params_p))
   frs1_to_raw
    (.rec_i(frs1)
     ,.tag_i(decode.frs1_tag)
     ,.raw_o(frs1_raw)
     );

  bp_hardfloat_raw_dp_s frs2_raw;
  bp_be_rec_to_raw
   #(.bp_params_p(bp_params_p))
   frs2_to_raw
    (.rec_i(frs2)
     ,.tag_i(decode.frs2_tag)
     ,.raw_o(frs2_raw)
     );

  rv64_fclass_s fclass_result;
  rv64_fflags_s fclass_fflags;
  assign fclass_result = '{q_nan  : frs1_raw.is_nan & ~frs1_raw.is_snan
                           ,s_nan : frs1_raw.is_nan &  frs1_raw.is_snan
                           ,p_inf : ~frs1_raw.sign & frs1_raw.is_inf
                           ,p_norm: ~frs1_raw.sign & ~frs1_raw.is_sub & ~frs1_raw.is_zero & ~frs1_raw.is_inf & ~frs1_raw.is_nan
                           ,p_sub : ~frs1_raw.sign & frs1_raw.is_sub
                           ,p_zero: ~frs1_raw.sign & frs1_raw.is_zero
                           ,n_zero:  frs1_raw.sign & frs1_raw.is_zero
                           ,n_sub :  frs1_raw.sign & frs1_raw.is_sub
                           ,n_norm:  frs1_raw.sign & ~frs1_raw.is_sub & ~frs1_raw.is_zero & ~frs1_raw.is_inf & ~frs1_raw.is_nan
                           ,n_inf :  frs1_raw.sign & frs1_raw.is_inf
                           ,default: '0
                           };
  assign fclass_fflags = '0;

  //
  // Move Float -> Int
  //
  logic [dword_width_gp-1:0] fmvi_result;
  rv64_fflags_s fmvi_fflags;

  assign fmvi_result = frs1;
  assign fmvi_fflags = '0;

  //
  // FCVT Int -> Float
  //
  bp_hardfloat_raw_dp_s i2f_result;
  rv64_fflags_s i2f_fflags;

  bp_hardfloat_rec_dp_s i2f_rec;
  wire irs1_unsigned = decode.fu_op inside {e_aux_op_iu2f};
  iNToRecFN
   #(.intWidth(dword_width_gp)
     ,.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   i2f
    (.control(control_li)
     ,.signedIn(!irs1_unsigned)
     ,.in(irs1)
     ,.roundingMode(frm_li)
     ,.out(i2f_rec)
     ,.exceptionFlags(i2f_fflags)
     );

  bp_hardfloat_raw_dp_s i2f_raw;
  logic [dp_sig_width_gp:0] i2f_sig;
  recFNToRawFN
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp))
   i2f_rec_to_raw
    (.in(i2f_rec)
     ,.isNaN(i2f_result.is_nan)
     ,.isInf(i2f_result.is_inf)
     ,.isZero(i2f_result.is_zero)
     ,.sign(i2f_result.sign)
     ,.sExp(i2f_result.sexp)
     ,.sig(i2f_sig)
     );
  assign i2f_result.sig = i2f_sig << 2'b10;

  //
  // FCVT Float -> Int
  //
  logic [dword_width_gp-1:0] f2i_result;
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

  assign f2i_result = opw_v ? f2w_out : f2dw_out;
  assign f2i_fflags = opw_v ? word_fflags : dword_fflags;

  //
  // Float to Float
  //
  bp_hardfloat_raw_dp_s f2f_result;
  rv64_fflags_s f2f_fflags;

  assign f2f_result = frs1_raw;
  assign f2f_fflags = '0;

  //
  // FMV Int -> Float
  //
  logic [dword_width_gp-1:0] imvf_result;
  wire [dword_width_gp-1:0] imvf_mask = {{word_width_gp{opw_v}}} << word_width_gp;

  assign imvf_result = irs1 | imvf_mask;

  //
  // FSGNJ
  //
  logic [dword_width_gp-1:0] fsgnj_result;
  wire [`BSG_SAFE_CLOG2(dword_width_gp)-1:0] signbit =
    (decode.frd_tag == e_fp_dp) ? (dword_width_gp-1) : (word_width_gp-1);
  wire invbox_frs1 = ops_v & ~&frs1[word_width_gp+:word_width_gp];
  wire invbox_frs2 = ops_v & ~&frs2[word_width_gp+:word_width_gp];
  wire [dword_width_gp-1:0] fsgnj_a = invbox_frs1 ? sp_canonical_nan : frs1;
  wire [dword_width_gp-1:0] fsgnj_b = invbox_frs2 ? sp_canonical_nan : frs2;
  always_comb
    begin
      fsgnj_result = fsgnj_a;
      unique case (decode.fu_op)
        e_aux_op_fsgnjn: fsgnj_result[signbit] = ~fsgnj_b[signbit];
        e_aux_op_fsgnjx: fsgnj_result[signbit] =  fsgnj_b[signbit] ^ fsgnj_a[signbit];
        e_aux_op_fsgnj : fsgnj_result[signbit] =  fsgnj_b[signbit];
        default: begin end
      endcase
    end

  //
  // FEQ, FLT, FLE
  //
  logic fcmp_result;
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
  assign fcmp_result = fcmp_out;

  //
  // FMIN-MAX
  //
  bp_hardfloat_raw_dp_s fminmax_result;
  rv64_fflags_s  fminmax_fflags;

  always_comb
    if (frs1_raw.is_nan & frs2_raw.is_nan)
      fminmax_result = '1;
    else if (frs1_raw.is_nan & ~frs2_raw.is_nan)
      fminmax_result = frs2_raw;
    else if (~frs1_raw.is_nan & frs2_raw.is_nan)
      fminmax_result = frs1_raw;
    else if (feq_lo)
      fminmax_result = (is_fmin_li ^ frs1_raw.sign) ? frs2_raw : frs1_raw;
    else
      fminmax_result = (is_fmax_li ^ flt_lo) ? frs1_raw : frs2_raw;

  assign fminmax_fflags = fcmp_fflags;

  //
  // Get the final result
  //
  bp_be_fp_reg_s frd_data_lo;
  rv64_fflags_s frd_fflags;

  logic [dword_width_gp-1:0] ieee_result;
  always_comb
    case (decode.fu_op)
      e_aux_op_imvf: ieee_result = imvf_result;
      // e_aux_op_fsgnj, e_aux_op_fsgnjx, e_aux_op_fsgnjn;
      default: ieee_result = fsgnj_result;
    endcase

  bp_be_fp_reg_s ieee_data_lo;
  rv64_fflags_s ieee_fflags;
  bp_be_fp_box
   #(.bp_params_p(bp_params_p))
   fp_box
    (.ieee_i(ieee_result)
     ,.tag_i(decode.frd_tag)
     ,.reg_o(ieee_data_lo)
     );
  assign ieee_fflags = '0;

  bp_hardfloat_raw_dp_s raw_result;
  rv64_fflags_s raw_fflags;
  always_comb
    case (decode.fu_op)
      e_aux_op_i2f, e_aux_op_iu2f:
        begin
          raw_result = i2f_result;
          raw_fflags = i2f_fflags;
        end
      e_aux_op_f2f:
        begin
          raw_result = f2f_result;
          raw_fflags = f2f_fflags;
        end
      // e_aux_op_fmin, e_aux_op_fmax:
      default:
        begin
          raw_result = fminmax_result;
          raw_fflags = fminmax_fflags;
        end
    endcase

  bp_be_fp_reg_s rebox_data_lo;
  rv64_fflags_s rebox_fflags;
  bp_be_fp_rebox
   #(.bp_params_p(bp_params_p))
   rebox
    (.raw_i(raw_result)
     ,.tag_i(decode.frd_tag)
     ,.frm_i(frm_li)
     ,.invalid_exc_i(1'b0)
     ,.infinite_exc_i(1'b0)

     ,.reg_o(rebox_data_lo)
     ,.fflags_o(rebox_fflags)
     );

  assign frd_data_lo = decode.fmove_v ? ieee_data_lo : rebox_data_lo;
  assign frd_fflags = decode.fmove_v ? ieee_fflags  : (raw_fflags | rebox_fflags);

  logic [dword_width_gp-1:0] iaux_result;
  rv64_fflags_s ird_fflags;
  always_comb
    case (decode.fu_op)
      e_aux_op_fmvi:
        begin
          iaux_result = fmvi_result;
          ird_fflags = fmvi_fflags;
        end
      e_aux_op_f2i, e_aux_op_f2iu:
        begin
          iaux_result = f2i_result;
          ird_fflags = f2i_fflags;
        end
      e_aux_op_feq, e_aux_op_flt, e_aux_op_fle:
        begin
          iaux_result = fcmp_result;
          ird_fflags = fcmp_fflags;
        end
      // e_aux_op_fclass
      default:
        begin
          iaux_result = fclass_result;
          ird_fflags = fclass_fflags;
        end
    endcase

  logic [dpath_width_gp-1:0] ird_data_lo;
  bp_be_int_box
   #(.bp_params_p(bp_params_p))
   int_box
    (.raw_i(iaux_result)
     ,.tag_i(decode.ird_tag)
     ,.unsigned_i(1'b0)
     ,.reg_o(ird_data_lo)
     );

  wire [dpath_width_gp-1:0] aux_result = decode.irf_w_v ? ird_data_lo : frd_data_lo;
  wire [$bits(rv64_fflags_s)-1:0] aux_fflags = decode.irf_w_v ? ird_fflags : frd_fflags;

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



`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_long
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam wb_pkt_width_lp = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [dispatch_pkt_width_lp-1:0]  reservation_i
   , output logic                       ibusy_o
   , output logic                       fbusy_o
   , input rv64_frm_e                   frm_dyn_i

   , input                              flush_i

   , output logic [wb_pkt_width_lp-1:0] iwb_pkt_o
   , output logic                       iwb_v_o
   , input                              iwb_yumi_i

   , output logic [wb_pkt_width_lp-1:0] fwb_pkt_o
   , output logic                       fwb_v_o
   , input                              fwb_yumi_i
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  rv64_instr_s instr;
  bp_be_decode_s decode;
  bp_be_wb_pkt_s iwb_pkt;
  bp_be_wb_pkt_s fwb_pkt;

  assign iwb_pkt_o = iwb_pkt;
  assign fwb_pkt_o = fwb_pkt;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr  = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_gp-1:0] rs1 = reservation.rs1[0+:dword_width_gp];
  wire [dword_width_gp-1:0] rs2 = reservation.rs2[0+:dword_width_gp];
  wire [dword_width_gp-1:0] imm = reservation.imm[0+:dword_width_gp];

  wire int_v_li = reservation.v & reservation.decode.pipe_long_v & reservation.decode.irf_w_v;
  wire fp_v_li = reservation.v & reservation.decode.pipe_long_v & reservation.decode.frf_w_v;

  logic fmask_r, imask_r;
  bsg_dff
   #(.width_p(2))
   mask_reg
    (.clk_i(clk_i)
     ,.data_i({fp_v_li, int_v_li})
     ,.data_o({fmask_r, imask_r})
     );
  wire flush_int_li = flush_i & (imask_r | int_v_li);
  wire flush_fp_li  = flush_i & (fmask_r | fp_v_li);

  wire signed_div_li = decode.fu_op inside {e_mul_op_div, e_mul_op_rem};
  wire rem_not_div_li = decode.fu_op inside {e_mul_op_rem, e_mul_op_remu};

  wire [dword_width_gp-1:0] op_a = decode.opw_v ? (rs1 << word_width_gp) : rs1;
  wire [dword_width_gp-1:0] op_b = decode.opw_v ? (rs2 << word_width_gp) : rs2;

  wire signed_opA_li = decode.fu_op inside {e_mul_op_mulh, e_mul_op_mulhsu};
  wire signed_opB_li = decode.fu_op inside {e_mul_op_mulh};

  logic [dword_width_gp-1:0] imulh_result_lo;
  logic imulh_ready_lo, imulh_v_lo;
  wire imulh_v_li = int_v_li & (decode.fu_op inside {e_mul_op_mulh, e_mul_op_mulhsu, e_mul_op_mulhu});
  bsg_imul_iterative
   #(.width_p(dword_width_gp))
   imulh
    (.clk_i(clk_i)
    ,.reset_i(reset_i | flush_int_li)
    ,.v_i(imulh_v_li)
    ,.ready_o(imulh_ready_lo)
    ,.opA_i(op_a)
    ,.signed_opA_i(signed_opA_li)
    ,.opB_i(op_b)
    ,.signed_opB_i(signed_opB_li)
    ,.gets_high_part_i(1'b1)
    ,.v_o(imulh_v_lo)
    ,.result_o(imulh_result_lo)
    ,.yumi_i(imulh_v_lo & iwb_yumi_i)
    );

  // We actual could exit early here
  logic [dword_width_gp-1:0] quotient_lo, remainder_lo;
  logic idiv_ready_and_lo;
  logic idiv_v_lo;
  wire idiv_v_li = int_v_li & (decode.fu_op inside {e_mul_op_div, e_mul_op_divu});
  wire irem_v_li = int_v_li & (decode.fu_op inside {e_mul_op_rem, e_mul_op_remu});
  localparam idiv_bits_per_iter_lp = muldiv_support_p[e_idiv2b] ? 2'b10 : 2'b01;
  bsg_idiv_iterative
   #(.width_p(dword_width_gp), .bits_per_iter_p(idiv_bits_per_iter_lp))
   idiv
    (.clk_i(clk_i)
     ,.reset_i(reset_i | flush_int_li)

     ,.dividend_i(op_a)
     ,.divisor_i(op_b)
     ,.signed_div_i(signed_div_li)
     ,.v_i(idiv_v_li | irem_v_li)
     ,.ready_and_o(idiv_ready_and_lo)

     ,.quotient_o(quotient_lo)
     ,.remainder_o(remainder_lo)
     ,.v_o(idiv_v_lo)
     ,.yumi_i(idiv_v_lo & iwb_yumi_i)
     );
  wire [word_width_gp-1:0] quotient_w_lo = quotient_lo[0+:word_width_gp];
  wire [word_width_gp-1:0] remainder_w_lo = remainder_lo[0+:word_width_gp];

  logic [reg_addr_width_gp-1:0] ird_addr_r;
  bp_be_fu_op_s fu_op_r;
  logic opw_v_r;
  bsg_dff_en
   #(.width_p(reg_addr_width_gp+$bits(bp_be_fu_op_s)+1))
   iwb_reg
    (.clk_i(clk_i)
     ,.en_i(imulh_v_li | idiv_v_li | irem_v_li)

     ,.data_i({instr.t.fmatype.rd_addr, decode.fu_op, decode.opw_v})
     ,.data_o({ird_addr_r, fu_op_r, opw_v_r})
     );

  bp_be_fp_reg_s frs1, frs2;
  bp_be_nan_unbox
   #(.bp_params_p(bp_params_p))
   frs1_unbox
    (.reg_i(reservation.rs1)
     ,.unbox_i(decode.ops_v)
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
  always_comb frm_li = rv64_frm_e'((instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : instr.t.fmatype.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  wire fdiv_v_li  = fp_v_li & (decode.fu_op inside {e_fma_op_fdiv});
  wire fsqrt_v_li = fp_v_li & (decode.fu_op inside {e_fma_op_fsqrt});
  wire fdivsqrt_v_li = fdiv_v_li | fsqrt_v_li;

  logic fdivsqrt_ready_and_lo, fdivsqrt_v_lo;
  logic sqrt_lo, invalid_exc, infinite_exc;
  logic [2:0] frm_lo;
  bp_hardfloat_raw_dp_s fdivsqrt_raw_lo;
  localparam fdivsqrt_bits_per_iter_lp = fpu_support_p[e_fdivsqrt2b] ? 2'b10 : 2'b01;
  divSqrtRecFNToRaw
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     ,.bits_per_iter_p(fdivsqrt_bits_per_iter_lp)
     )
   fdiv
    (.clock(clk_i)
     ,.nReset(~reset_i & ~flush_fp_li)
     ,.control(control_li)

     ,.inReady(fdivsqrt_ready_and_lo)
     ,.inValid(fdivsqrt_v_li)
     ,.sqrtOp(fsqrt_v_li)
     ,.a(frs1.rec)
     ,.b(frs2.rec)
     ,.roundingMode(frm_li)

     ,.outValid(fdivsqrt_v_lo)
     ,.sqrtOpOut(sqrt_lo)
     ,.roundingModeOut(frm_lo)
     ,.invalidExc(invalid_exc)
     ,.infiniteExc(infinite_exc)

     ,.out_isNaN(fdivsqrt_raw_lo.is_nan)
     ,.out_isInf(fdivsqrt_raw_lo.is_inf)
     ,.out_isZero(fdivsqrt_raw_lo.is_zero)
     ,.out_sign(fdivsqrt_raw_lo.sign)
     ,.out_sExp(fdivsqrt_raw_lo.sexp)
     ,.out_sig(fdivsqrt_raw_lo.sig)
     );

  // outValid of fdivsqrt only goes high one cycle
  logic fdivsqrt_pending_r;
  bsg_dff_reset_en
   #(.width_p(1))
   fdivsqrt_pending_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i | flush_fp_li)
     ,.en_i(fdivsqrt_v_lo | fwb_yumi_i)
     ,.data_i(fdivsqrt_v_lo & ~fwb_yumi_i)
     ,.data_o(fdivsqrt_pending_r)
     );

  logic ops_v_r;
  logic [reg_addr_width_gp-1:0] frd_addr_r;
  rv64_frm_e frm_r;
  bsg_dff_en
   #(.width_p($bits(rv64_frm_e)+reg_addr_width_gp+1))
   fwb_reg
    (.clk_i(clk_i)
     ,.en_i(fdivsqrt_v_li)

     ,.data_i({frm_li, instr.t.fmatype.rd_addr, decode.ops_v})
     ,.data_o({frm_r, frd_addr_r, ops_v_r})
     );

  logic [dp_rec_width_gp-1:0] fdivsqrt_result_dp, fdivsqrt_result_sp;
  rv64_fflags_s fdivsqrt_fflags_dp, fdivsqrt_fflags_sp;
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
     ,.invalidExc(invalid_exc)
     ,.infiniteExc(infinite_exc)
     ,.in_isNaN(fdivsqrt_raw_lo.is_nan)
     ,.in_isInf(fdivsqrt_raw_lo.is_inf)
     ,.in_isZero(fdivsqrt_raw_lo.is_zero)
     ,.in_sign(fdivsqrt_raw_lo.sign)
     ,.in_sExp(fdivsqrt_raw_lo.sexp)
     ,.in_sig(fdivsqrt_raw_lo.sig)
     ,.roundingMode(frm_r)
     ,.fullOut(fdivsqrt_result_dp)
     ,.fullExceptionFlags(fdivsqrt_fflags_dp)
     ,.midOut(fdivsqrt_result_sp)
     ,.midExceptionFlags(fdivsqrt_fflags_sp)
     );

  bp_be_fp_reg_s fdivsqrt_sp_reg_lo, fdivsqrt_dp_reg_lo, frd_data_lo;
  rv64_fflags_s fflags_lo;
  assign fdivsqrt_sp_reg_lo = '{tag: e_fp_sp, rec: fdivsqrt_result_sp};
  assign fdivsqrt_dp_reg_lo = '{tag: e_fp_full, rec: fdivsqrt_result_dp};
  always_comb
    if (ops_v_r)
      {fflags_lo, frd_data_lo} = {fdivsqrt_fflags_sp, fdivsqrt_sp_reg_lo};
    else
      {fflags_lo, frd_data_lo} = {fdivsqrt_fflags_dp, fdivsqrt_dp_reg_lo};

  logic [dword_width_gp-1:0] ird_data_lo;
  always_comb
    if (~opw_v_r && fu_op_r inside {e_mul_op_mulh, e_mul_op_mulhsu, e_mul_op_mulhu})
      ird_data_lo = imulh_result_lo;
    else if (opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      ird_data_lo = `BSG_SIGN_EXTEND(quotient_w_lo, dword_width_gp);
    else if (opw_v_r && fu_op_r inside {e_mul_op_rem, e_mul_op_remu})
      ird_data_lo = $signed(remainder_lo) >>> word_width_gp;
    else if (~opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      ird_data_lo = quotient_lo;
    else
      ird_data_lo = remainder_lo;

  assign ibusy_o = int_v_li | ~imulh_ready_lo | ~idiv_ready_and_lo;
  assign fbusy_o = fdivsqrt_v_li | ~fdivsqrt_ready_and_lo | fdivsqrt_pending_r;

  assign iwb_v_o = ~imask_r & (imulh_v_lo | idiv_v_lo);
  assign iwb_pkt.ird_w_v    = iwb_v_o;
  assign iwb_pkt.frd_w_v    = 1'b0;
  assign iwb_pkt.rd_addr    = ird_addr_r;
  assign iwb_pkt.rd_data    = ird_data_lo;
  assign iwb_pkt.fflags_w_v = 1'b0;
  assign iwb_pkt.fflags     = '0;

  assign fwb_v_o = ~fmask_r & (fdivsqrt_v_lo | fdivsqrt_pending_r);
  assign fwb_pkt.ird_w_v    = 1'b0;
  assign fwb_pkt.frd_w_v    = fwb_v_o;
  assign fwb_pkt.rd_addr    = frd_addr_r;
  assign fwb_pkt.rd_data    = frd_data_lo;
  assign fwb_pkt.fflags_w_v = 1'b1;
  assign fwb_pkt.fflags     = fflags_lo;

endmodule


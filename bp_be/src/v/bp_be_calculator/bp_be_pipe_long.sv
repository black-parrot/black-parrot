
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
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i
   , output                            ready_o
   , input rv64_frm_e                  frm_dyn_i

   , input                             flush_i

   , output [wb_pkt_width_lp-1:0]      iwb_pkt_o
   , output                            iwb_v_o
   , input                             iwb_yumi_i

   , output [wb_pkt_width_lp-1:0]      fwb_pkt_o
   , output                            fwb_v_o
   , input                             fwb_yumi_i
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  rv64_instr_fmatype_s instr;
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

  wire v_li = reservation.v & ~reservation.poison & reservation.decode.pipe_long_v;

  wire signed_div_li = decode.fu_op inside {e_mul_op_div, e_mul_op_rem};
  wire rem_not_div_li = decode.fu_op inside {e_mul_op_rem, e_mul_op_remu};

  wire [dword_width_gp-1:0] op_a = decode.opw_v ? (rs1 << word_width_gp) : rs1;
  wire [dword_width_gp-1:0] op_b = decode.opw_v ? (rs2 << word_width_gp) : rs2;

  // We actual could exit early here
  logic [dword_width_gp-1:0] quotient_lo, remainder_lo;
  logic idiv_ready_lo;
  logic idiv_v_lo;
  wire idiv_v_li = v_li & (decode.fu_op inside {e_mul_op_div, e_mul_op_divu});
  wire irem_v_li = v_li & (decode.fu_op inside {e_mul_op_rem, e_mul_op_remu});
  bsg_idiv_iterative
   #(.width_p(dword_width_gp))
   idiv
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dividend_i(op_a)
     ,.divisor_i(op_b)
     ,.signed_div_i(signed_div_li)
     ,.v_i(idiv_v_li | irem_v_li)
     ,.ready_o(idiv_ready_lo)

     ,.quotient_o(quotient_lo)
     ,.remainder_o(remainder_lo)
     ,.v_o(idiv_v_lo)
     ,.yumi_i(idiv_v_lo & iwb_yumi_i)
     );

  bp_be_fp_reg_s frs1, frs2;
  assign frs1 = reservation.rs1;
  assign frs2 = reservation.rs2;

  //
  // Control bits for the FPU
  //   The control bits control tininess, which is fixed in RISC-V
  rv64_frm_e frm_li;
  assign frm_li = (instr.rm == e_dyn) ? frm_dyn_i : rv64_frm_e'(instr.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  wire fdiv_v_li  = v_li & (decode.fu_op == e_fma_op_fdiv);
  wire fsqrt_v_li = v_li & (decode.fu_op == e_fma_op_fsqrt);

  logic fdiv_ready_lo, fdivsqrt_v_lo;
  logic sqrt_lo;
  logic [2:0] frm_lo;
  logic invalid_exc, infinite_exc;
  logic is_nan, is_inf, is_zero;
  logic fdivsqrt_out_sign;
  logic [dp_exp_width_gp+1:0] fdivsqrt_out_sexp;
  logic [dp_sig_width_gp+2:0] fdivsqrt_out_sig;
  divSqrtRecFNToRaw_small
   #(.expWidth(dp_exp_width_gp), .sigWidth(dp_sig_width_gp))
   fdiv
    (.clock(clk_i)
     ,.nReset(~reset_i)
     ,.control(control_li)

     ,.inReady(fdiv_ready_lo)
     ,.inValid(fdiv_v_li | fsqrt_v_li)
     ,.sqrtOp(fsqrt_v_li)
     ,.a(frs1.rec)
     ,.b(frs2.rec)
     ,.roundingMode(frm_li)

     ,.outValid(fdivsqrt_v_lo)
     ,.sqrtOpOut(sqrt_lo)
     ,.roundingModeOut(frm_lo)
     ,.invalidExc(invalid_exc)
     ,.infiniteExc(infinite_exc)
     ,.out_isNaN(is_nan)
     ,.out_isInf(is_inf)
     ,.out_isZero(is_zero)
     ,.out_sign(fdivsqrt_out_sign)
     ,.out_sExp(fdivsqrt_out_sexp)
     ,.out_sig(fdivsqrt_out_sig)
     );

  logic opw_v_r, ops_v_r;
  bp_be_fu_op_s fu_op_r;
  logic [reg_addr_width_gp-1:0] rd_addr_r;
  rv64_frm_e frm_r;
  bsg_dff_reset_en
   #(.width_p($bits(rv64_frm_e)+reg_addr_width_gp+$bits(bp_be_fu_op_s)+2))
   wb_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(v_li)

     ,.data_i({frm_li, instr.rd_addr, decode.fu_op, decode.opw_v, decode.ops_v})
     ,.data_o({frm_r, rd_addr_r, fu_op_r, opw_v_r, ops_v_r})
     );

  logic idiv_done_v_r, fdiv_done_v_r, rd_w_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(3))
   wb_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({idiv_v_lo, fdivsqrt_v_lo, v_li})
     ,.clear_i({v_li, v_li, (iwb_yumi_i | fwb_yumi_i)})
     ,.data_o({idiv_done_v_r, fdiv_done_v_r, rd_w_v_r})
     );

  logic [2:0] hazard_cnt;
  wire idiv_safe = (hazard_cnt > 2);
  wire fdiv_safe = (hazard_cnt > 3);
  bsg_counter_clear_up
   #(.max_val_p(4), .init_val_p(0))
   hazard_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(v_li)
     ,.up_i(rd_w_v_r & ~fdiv_safe)
     ,.count_o(hazard_cnt)
     );

  logic [dp_rec_width_gp-1:0] fdivsqrt_dp_final;
  rv64_fflags_s fdivsqrt_dp_fflags;
  roundAnyRawFNToRecFN
   #(.inExpWidth(dp_exp_width_gp)
     ,.inSigWidth(dp_sig_width_gp+2)
     ,.outExpWidth(dp_exp_width_gp)
     ,.outSigWidth(dp_sig_width_gp)
     )
   round_dp
    (.control(control_li)
     ,.invalidExc(invalid_exc)
     ,.infiniteExc('0)
     ,.in_isNaN(is_nan)
     ,.in_isInf(is_inf)
     ,.in_isZero(is_zero)
     ,.in_sign(fdivsqrt_out_sign)
     ,.in_sExp(fdivsqrt_out_sexp)
     ,.in_sig(fdivsqrt_out_sig)
     ,.roundingMode(frm_r)
     ,.out(fdivsqrt_dp_final)
     ,.exceptionFlags(fdivsqrt_dp_fflags)
     );

  bp_hardfloat_rec_sp_s fdivsqrt_sp_final;
  rv64_fflags_s fdivsqrt_sp_fflags;
  roundAnyRawFNToRecFN
   #(.inExpWidth(dp_exp_width_gp)
     ,.inSigWidth(dp_sig_width_gp+2)
     ,.outExpWidth(sp_exp_width_gp)
     ,.outSigWidth(sp_sig_width_gp)
     )
   round_sp
    (.control(control_li)
     ,.invalidExc(invalid_exc)
     ,.infiniteExc('0)
     ,.in_isNaN(is_nan)
     ,.in_isInf(is_inf)
     ,.in_isZero(is_zero)
     ,.in_sign(fdivsqrt_out_sign)
     ,.in_sExp(fdivsqrt_out_sexp)
     ,.in_sig(fdivsqrt_out_sig)
     ,.roundingMode(frm_r)
     ,.out(fdivsqrt_sp_final)
     ,.exceptionFlags(fdivsqrt_sp_fflags)
     );

  localparam bias_adj_lp = (1 << dp_exp_width_gp) - (1 << sp_exp_width_gp);
  bp_hardfloat_rec_dp_s fdivsqrt_sp2dp_final;

  bp_be_fp_reg_s fdivsqrt_result;
  rv64_fflags_s fdivsqrt_fflags;
  assign fdivsqrt_result = '{sp_not_dp: ops_v_r, rec: ops_v_r ? fdivsqrt_sp2dp_final : fdivsqrt_dp_final};
  assign fdivsqrt_fflags = ops_v_r ? fdivsqrt_sp_fflags : fdivsqrt_dp_fflags;

  wire [dp_exp_width_gp:0] adjusted_exp = fdivsqrt_sp_final.exp + bias_adj_lp;
  wire [2:0]                   exp_code = fdivsqrt_sp_final.exp[sp_exp_width_gp-:3];
  wire                          special = (exp_code == '0) || (exp_code >= 3'd6);

  assign fdivsqrt_sp2dp_final = '{sign  : fdivsqrt_sp_final.sign
                                  ,exp  : special ? {exp_code, adjusted_exp[0+:dp_exp_width_gp-2]} : adjusted_exp
                                  ,fract: {fdivsqrt_sp_final.fract, (dp_sig_width_gp-sp_sig_width_gp)'(0)}
                                  };

  logic [dword_width_gp-1:0] rd_data_lo;
  always_comb
    if (opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      rd_data_lo = $signed(quotient_lo[0+:word_width_gp]);
    else if (opw_v_r && fu_op_r inside {e_mul_op_rem, e_mul_op_remu})
      rd_data_lo = $signed(remainder_lo) >>> word_width_gp;
    else if (~opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      rd_data_lo = quotient_lo;
    else
      rd_data_lo = remainder_lo;

  // Actually a busy signal
  assign ready_o = ~rd_w_v_r & ~v_li;

  assign iwb_pkt.ird_w_v    = rd_w_v_r;
  assign iwb_pkt.frd_w_v    = 1'b0;
  assign iwb_pkt.late       = 1'b1;
  assign iwb_pkt.rd_addr    = rd_addr_r;
  assign iwb_pkt.rd_data    = rd_data_lo;
  assign iwb_pkt.fflags_w_v = 1'b0;
  assign iwb_pkt.fflags     = '0;
  assign iwb_v_o = idiv_safe & idiv_done_v_r & rd_w_v_r;

  assign fwb_pkt.ird_w_v    = 1'b0;
  assign fwb_pkt.frd_w_v    = rd_w_v_r;
  assign fwb_pkt.late       = 1'b1;
  assign fwb_pkt.rd_addr    = rd_addr_r;
  assign fwb_pkt.rd_data    = fdivsqrt_result;
  assign fwb_pkt.fflags_w_v = 1'b1;
  assign fwb_pkt.fflags     = fdivsqrt_fflags;
  assign fwb_v_o = fdiv_safe & fdiv_done_v_r & rd_w_v_r;

endmodule


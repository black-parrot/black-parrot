/**
 *
 * Name:
 *   bp_be_pipe_fma.v
 *
 * Description:
 *   Pipeline for RISC-V float instructions. Handles float and double computation.
 *
 * Notes:
 *   This module relies on cross-boundary flattening and retiming to achieve
 *     good QoR
 *   
 *   ASIC tools prefer to have retiming chains be pure register chains at the end of
 *   a combinational logic cloud, whereas FPGA tools prefer explicitly instantiated registers.
 *   With this FPGA optimization, we've achieved 50MHz on a Zynq 7020
 *
 *   This module:
 *            ...
 *            fma 4 cycles     reservation
 *           /   \                 |
 *        round  imul_out      meta_info
 *          |
 *       fma_out
 *
 */
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_fma
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
   , output logic [dpath_width_gp-1:0] imul_data_o
   , output logic                      imul_v_o
   , output logic [dpath_width_gp-1:0] fma_data_o
   , output rv64_fflags_s              fma_fflags_o
   , output logic                      fma_v_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;
  bp_be_fp_reg_s frs1, frs2, frs3;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  assign frs1 = reservation.rs1;
  assign frs2 = reservation.rs2;
  assign frs3 = reservation.imm;
  wire [dword_width_gp-1:0] rs1 = decode.opw_v ? (frs1 << word_width_gp) : frs1;
  wire [dword_width_gp-1:0] rs2 = frs2;

  //
  // Control bits for the FPU
  //   The control bits control tininess, which is fixed in RISC-V
  rv64_frm_e frm_li;
  assign frm_li = (instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : rv64_frm_e'(instr.t.fmatype.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  wire is_fadd_li    = (decode.fu_op == e_fma_op_fadd);
  wire is_fsub_li    = (decode.fu_op == e_fma_op_fsub);
  wire is_faddsub_li = is_fadd_li | is_fsub_li;
  wire is_fmul_li    = (decode.fu_op == e_fma_op_fmul);
  wire is_fmadd_li   = (decode.fu_op == e_fma_op_fmadd);
  wire is_fmsub_li   = (decode.fu_op == e_fma_op_fmsub);
  wire is_fnmsub_li  = (decode.fu_op == e_fma_op_fnmsub);
  wire is_fnmadd_li  = (decode.fu_op == e_fma_op_fnmadd);
  wire is_imul_li    = (decode.fu_op == e_fma_op_imul);
  // FMA op list
  //   enc |    semantics  | RISC-V equivalent
  // 0 0 0 :   (a x b) + c : fmadd
  // 0 0 1 :   (a x b) - c : fmsub
  // 0 1 0 : - (a x b) + c : fnmsub
  // 0 1 1 : - (a x b) - c : fnmadd
  // 1 x x :   (a x b)     : integer multiplication
  logic [2:0] fma_op_li;
  always_comb
    begin
      if (is_fmadd_li | is_fadd_li | is_fmul_li)
        fma_op_li = 3'b000;
      else if (is_fmsub_li | is_fsub_li)
        fma_op_li = 3'b001;
      else if (is_fnmsub_li)
        fma_op_li = 3'b010;
      else  if (is_fnmadd_li)
        fma_op_li = 3'b011;
      else // if is_imul
        fma_op_li = 3'b100;
    end

  wire [dp_rec_width_gp-1:0] fma_a_li = is_imul_li ? rs1 : frs1.rec;
  wire [dp_rec_width_gp-1:0] fma_b_li = is_imul_li ? rs2 : is_faddsub_li ? dp_rec_1_0 : frs2.rec;
  wire [dp_rec_width_gp-1:0] fma_c_li = is_faddsub_li ? frs2.rec : is_fmul_li ? dp_rec_0_0 : frs3.rec;

  // Here, we switch the implementation based on synthesizing for Vivado or not. If this is
  //   a knob you'd like to turn yourself, consider modifying the define yourself. With this
  localparam fma_latency_lp  = 5;
  localparam imul_latency_lp = 4;
  `ifdef SYNTHESIS
    `ifdef DC
      localparam muladd_latency_lp = 0;
    `elsif CDS_TOOL_DEFINE
      localparam muladd_latency_lp = 0;
    `else
      localparam muladd_latency_lp = 3;
    `endif
  `else
      localparam muladd_latency_lp = 0;
  `endif
  localparam imul_retime_latency_lp = imul_latency_lp - muladd_latency_lp;
  localparam fma_retime_latency_lp  = fma_latency_lp - muladd_latency_lp;

  rv64_frm_e frm_preround_r;
  logic opw_preround_r, ops_preround_r;
  bsg_dff_chain
   #(.width_p($bits(rv64_frm_e)+2), .num_stages_p(muladd_latency_lp))
   preround_chain
    (.clk_i(clk_i)
     ,.data_i({frm_li, decode.opw_v, decode.ops_v})
     ,.data_o({frm_preround_r, opw_preround_r, ops_preround_r})
     );

  logic invalid_exc, is_nan, is_inf, is_zero, fma_out_sign;
  logic [dp_exp_width_gp+1:0] fma_out_sexp;
  logic [dp_sig_width_gp+2:0] fma_out_sig;
  logic [dword_width_gp-1:0] imul_out;
  mulAddRecFNToRaw
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     ,.pipelineStages(muladd_latency_lp)
     ,.imulEn(1)
     )
   fma
    (.clock(clk_i),
     .control(control_li)
     ,.op(fma_op_li)
     ,.a(fma_a_li)
     ,.b(fma_b_li)
     ,.c(fma_c_li)
     ,.roundingMode(frm_li)

     ,.invalidExc(invalid_exc)
     ,.out_isNaN(is_nan)
     ,.out_isInf(is_inf)
     ,.out_isZero(is_zero)
     ,.out_sign(fma_out_sign)
     ,.out_sExp(fma_out_sexp)
     ,.out_sig(fma_out_sig)
     ,.out_imul(imul_out)
     );
  wire [dpath_width_gp-1:0] imulw_out    = $signed(imul_out) >>> word_width_gp;
  wire [dpath_width_gp-1:0] imul_result = opw_preround_r ? imulw_out : imul_out;

  logic [dp_rec_width_gp-1:0] fma_dp_final;
  rv64_fflags_s fma_dp_fflags;
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
     ,.in_sign(fma_out_sign)
     ,.in_sExp(fma_out_sexp)
     ,.in_sig(fma_out_sig)
     ,.roundingMode(frm_preround_r)
     ,.out(fma_dp_final)
     ,.exceptionFlags(fma_dp_fflags)
     );

  bp_hardfloat_rec_sp_s fma_sp_final;
  rv64_fflags_s fma_sp_fflags;
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
     ,.in_sign(fma_out_sign)
     ,.in_sExp(fma_out_sexp)
     ,.in_sig(fma_out_sig)
     ,.roundingMode(frm_preround_r)
     ,.out(fma_sp_final)
     ,.exceptionFlags(fma_sp_fflags)
     );

  // TODO: Is it cheaper to do a single round, then unsafe rec-to-rec conversion?
  localparam bias_adj_lp = (1 << dp_exp_width_gp) - (1 << sp_exp_width_gp);
  bp_hardfloat_rec_dp_s fma_sp2dp_final;

  wire [dp_exp_width_gp:0] adjusted_exp = fma_sp_final.exp + bias_adj_lp;
  wire [2:0]                   exp_code = fma_sp_final.exp[sp_exp_width_gp-:3];
  wire                          special = (exp_code == '0) || (exp_code >= 3'd6);

  assign fma_sp2dp_final = '{sign  : fma_sp_final.sign
                             ,exp  : special ? {exp_code, adjusted_exp[0+:dp_exp_width_gp-2]} : adjusted_exp
                             ,fract: {fma_sp_final.fract, (dp_sig_width_gp-sp_sig_width_gp)'(0)}
                             };

  bp_be_fp_reg_s fma_result;
  rv64_fflags_s fma_fflags;
  assign fma_result = '{sp_not_dp: ops_preround_r, rec: ops_preround_r ? fma_sp2dp_final : fma_dp_final};
  assign fma_fflags = ops_preround_r ? fma_sp_fflags : fma_dp_fflags;

  // TODO: Can combine the registers here if DC doesn't do it automatically
  bsg_dff_chain
   #(.width_p(dpath_width_gp), .num_stages_p(imul_retime_latency_lp-1))
   imul_retiming_chain
    (.clk_i(clk_i)

     ,.data_i({imul_result})
     ,.data_o({imul_data_o})
     );

  bsg_dff_chain
   #(.width_p($bits(bp_be_fp_reg_s)+$bits(rv64_fflags_s)), .num_stages_p(fma_retime_latency_lp-1))
   fma_retiming_chain
    (.clk_i(clk_i)

     ,.data_i({fma_fflags, fma_result})
     ,.data_o({fma_fflags_o, fma_data_o})
     );

  wire imul_v_li = reservation.v & reservation.decode.pipe_mul_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(imul_latency_lp-1))
   imul_v_chain
    (.clk_i(clk_i)

     ,.data_i(imul_v_li)
     ,.data_o(imul_v_o)
     );

  wire fma_v_li = reservation.v & reservation.decode.pipe_fma_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(fma_latency_lp-1))
   fma_v_chain
    (.clk_i(clk_i)

     ,.data_i(fma_v_li)
     ,.data_o(fma_v_o)
     );

endmodule


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
 *            fma 3 cycles     reservation
 *           /   \                 |
 *        round  imul_out      imul meta
 *          |                      |
 *       fma_out                fma meta
 *
 */
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_fma
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
   , output logic [dpath_width_gp-1:0] imul_data_o
   , output logic                      imul_v_o
   , output logic [dpath_width_gp-1:0] fma_data_o
   , output rv64_fflags_s              fma_fflags_o
   , output logic                      fma_v_o
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
  wire [dp_rec_width_gp-1:0] frs3 = reservation.fsrc3;
  wire [dword_width_gp-1:0]  irs1 = reservation.isrc1;
  wire [dword_width_gp-1:0]  irs2 = reservation.isrc2;

  //
  // Control bits for the FPU
  //   The control bits control tininess, which is fixed in RISC-V
  rv64_frm_e frm_li;
  // VCS / DVE 2016.1 has an issue with the 'assign' variant of the following code
  always_comb frm_li = rv64_frm_e'((instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : instr.t.fmatype.rm);
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

  // We emulate A*B with A*B+0 and A+B with A*1+B
  // According to IEEE special arithmetic rules for signed 0
  // (https://en.wikipedia.org/wiki/Signed_zero):
  // x + (+-0) = x for x different from zero
  // In order to correct for this we compute the sign of of A*B
  //   and match it to maintain the correct signedness of the result
  wire negate_sign = frs1[dp_rec_width_gp-1] ^ frs2[dp_rec_width_gp-1];
  wire [dp_rec_width_gp-1:0] fma_one = dp_rec_1_0;
  wire [dp_rec_width_gp-1:0] fma_zero = negate_sign ? dp_rec_m0_0 : dp_rec_0_0;

  wire [dp_rec_width_gp-1:0] fma_a_li = decode.irs1_r_v ? irs1 : frs1;
  wire [dp_rec_width_gp-1:0] fma_b_li = decode.irs2_r_v ? irs2 : is_faddsub_li ? fma_one : frs2;
  wire [dp_rec_width_gp-1:0] fma_c_li = is_faddsub_li ? frs2 : is_fmul_li ? fma_zero : frs3;

  // Here, we switch the implementation based on synthesizing for Vivado or not. If this is
  //   a knob you'd like to turn, consider modifying the define yourself.
  localparam fma_latency_lp  = 4;
  localparam imul_latency_lp = 3;
  `ifdef SYNTHESIS
    `ifdef DC
      localparam int fma_pipeline_stages_lp [1:0] = '{0,0};
    `elsif CDS_TOOL_DEFINE
      localparam int fma_pipeline_stages_lp [1:0] = '{0,0};
    `else
      localparam int fma_pipeline_stages_lp [1:0] = '{1,imul_latency_lp-1};
    `endif
  `else
      localparam int fma_pipeline_stages_lp [1:0] = '{0,0};
  `endif
  localparam imul_retime_latency_lp = imul_latency_lp - fma_pipeline_stages_lp[0];
  localparam fma_retime_latency_lp  = fma_latency_lp - fma_pipeline_stages_lp[1] - fma_pipeline_stages_lp[0];

  rv64_frm_e frm_r;
  bp_be_fp_tag_e fp_tag_r;
  bsg_dff_chain
   #(.width_p($bits(rv64_frm_e)+1)
     ,.num_stages_p(fma_pipeline_stages_lp[0]+fma_pipeline_stages_lp[1])
     )
   fma_info_chain
    (.clk_i(clk_i)
     ,.data_i({frm_li, decode.fp_tag})
     ,.data_o({frm_r, fp_tag_r})
     );

  logic [$bits(bp_be_int_tag_e)-1:0] int_tag_r;
  bsg_dff_chain
   #(.width_p($bits(bp_be_int_tag_e)), .num_stages_p(fma_pipeline_stages_lp[0]))
   mul_info_chain
    (.clk_i(clk_i)
     ,.data_i(decode.int_tag)
     ,.data_o(int_tag_r)
     );

  logic invalid_exc, is_nan, is_inf, is_zero, fma_out_sign;
  logic [dword_width_gp-1:0] imul_out;
  bp_hardfloat_raw_dp_s fma_raw_lo;
  mulAddRecFNToRaw
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     ,.pipelineStages(fma_pipeline_stages_lp[0])
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
     ,.out_isNaN(fma_raw_lo.is_nan)
     ,.out_isInf(fma_raw_lo.is_inf)
     ,.out_isZero(fma_raw_lo.is_zero)
     ,.out_sign(fma_raw_lo.sign)
     ,.out_sExp(fma_raw_lo.sexp)
     ,.out_sig(fma_raw_lo.sig)
     ,.out_imul(imul_out)
     );

  logic [dpath_width_gp-1:0] ird_data_lo;
  bp_be_int_box
   #(.bp_params_p(bp_params_p))
   imul_box
    (.raw_i(imul_out)
     ,.tag_i(int_tag_r)
     ,.unsigned_i(1'b0)
     ,.reg_o(ird_data_lo)
     );

  bp_hardfloat_raw_dp_s fma_raw_r;
  logic invalid_exc_r;
  bsg_dff_chain
   #(.width_p(1+$bits(bp_hardfloat_raw_dp_s)), .num_stages_p(fma_pipeline_stages_lp[1]))
   round_info_chain
    (.clk_i(clk_i)
     ,.data_i({invalid_exc, fma_raw_lo})
     ,.data_o({invalid_exc_r, fma_raw_r})
     );

  bp_be_fp_reg_s frd_data_lo;
  rv64_fflags_s fflags_lo;
  bp_be_fp_rebox
   #(.bp_params_p(bp_params_p))
   rebox
    (.raw_i(fma_raw_r)
     ,.tag_i(fp_tag_r)
     ,.frm_i(frm_r)
     ,.invalid_exc_i(invalid_exc_r)
     ,.infinite_exc_i(1'b0)

     ,.reg_o(frd_data_lo)
     ,.fflags_o(fflags_lo)
     );

  // TODO: Can combine the registers here if DC doesn't do it automatically
  bsg_dff_chain
   #(.width_p(dpath_width_gp), .num_stages_p(imul_retime_latency_lp-1))
   imul_retiming_chain
    (.clk_i(clk_i)

     ,.data_i(ird_data_lo)
     ,.data_o(imul_data_o)
     );

  bsg_dff_chain
   #(.width_p($bits(bp_be_fp_reg_s)+$bits(rv64_fflags_s)), .num_stages_p(fma_retime_latency_lp-1))
   fma_retiming_chain
    (.clk_i(clk_i)

     ,.data_i({fflags_lo, frd_data_lo})
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


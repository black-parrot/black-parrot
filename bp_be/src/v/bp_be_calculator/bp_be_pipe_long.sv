
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
   , output logic                       iready_o
   , output logic                       fready_o
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

  wire v_li = reservation.v & reservation.decode.pipe_long_v & (reservation.decode.late_iwb_v | reservation.decode.late_fwb_v);

  wire signed_div_li = decode.fu_op inside {e_mul_op_div, e_mul_op_rem};
  wire rem_not_div_li = decode.fu_op inside {e_mul_op_rem, e_mul_op_remu};

  wire [dword_width_gp-1:0] op_a = decode.opw_v ? (rs1 << word_width_gp) : rs1;
  wire [dword_width_gp-1:0] op_b = decode.opw_v ? (rs2 << word_width_gp) : rs2;

  wire signed_opA_li = decode.fu_op inside {e_mul_op_mulh, e_mul_op_mulhsu};
  wire signed_opB_li = decode.fu_op inside {e_mul_op_mulh};

  logic [dword_width_gp-1:0] imulh_result_lo;
  logic imulh_ready_lo, imulh_v_lo;
  wire imulh_v_li = v_li & (decode.fu_op inside {e_mul_op_mulh, e_mul_op_mulhsu, e_mul_op_mulhu});
  bsg_imul_iterative
   #(.width_p(dword_width_gp))
   imulh
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
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
     ,.ready_and_o(idiv_ready_and_lo)

     ,.quotient_o(quotient_lo)
     ,.remainder_o(remainder_lo)
     ,.v_o(idiv_v_lo)
     ,.yumi_i(idiv_v_lo & iwb_yumi_i)
     );
  wire [word_width_gp-1:0] quotient_w_lo = quotient_lo[0+:word_width_gp];
  wire [word_width_gp-1:0] remainder_w_lo = remainder_lo[0+:word_width_gp];

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
  always_comb frm_li = (instr.t.fmatype.rm == e_dyn) ? frm_dyn_i : rv64_frm_e'(instr.t.fmatype.rm);
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  wire fdiv_v_li  = v_li & (decode.fu_op == e_fma_op_fdiv);
  wire fsqrt_v_li = v_li & (decode.fu_op == e_fma_op_fsqrt);

  bp_be_fp_reg_s fdivsqrt_result;
  rv64_fflags_s fdivsqrt_fflags;
  logic fdiv_ready_lo, fdivsqrt_v_lo;
  logic sqrt_lo;
  divSqrtRecFN_small
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
     ,.out(fdivsqrt_result.rec)
     ,.exceptionFlags(fdivsqrt_fflags)
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

     ,.data_i({frm_li, instr.t.fmatype.rd_addr, decode.fu_op, decode.opw_v, decode.ops_v})
     ,.data_o({frm_r, rd_addr_r, fu_op_r, opw_v_r, ops_v_r})
     );
  assign fdivsqrt_result.tag = ops_v_r ? frm_r : e_fp_full;

  logic imulh_done_v_r, idiv_done_v_r, fdiv_done_v_r, rd_w_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(4))
   wb_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({imulh_v_lo, idiv_v_lo, fdivsqrt_v_lo, v_li})
     ,.clear_i({v_li, v_li, v_li, (iwb_yumi_i | fwb_yumi_i)})
     ,.data_o({imulh_done_v_r, idiv_done_v_r, fdiv_done_v_r, rd_w_v_r})
     );

  // Prevents out of order writebacks before commits
  // Possibly unnecessary
  logic [2:0] hazard_cnt;
  wire wb_safe = (hazard_cnt > 3);
  bsg_counter_clear_up
   #(.max_val_p(4), .init_val_p(0))
   hazard_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(v_li)
     ,.up_i(rd_w_v_r & ~wb_safe)
     ,.count_o(hazard_cnt)
     );

  logic [dword_width_gp-1:0] rd_data_lo;
  always_comb
    if (~opw_v_r && fu_op_r inside {e_mul_op_mulh, e_mul_op_mulhsu, e_mul_op_mulhu})
      rd_data_lo = imulh_result_lo;
    else if (opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      rd_data_lo = `BSG_SIGN_EXTEND(quotient_w_lo, dword_width_gp);
    else if (opw_v_r && fu_op_r inside {e_mul_op_rem, e_mul_op_remu})
      rd_data_lo = $signed(remainder_lo) >>> word_width_gp;
    else if (~opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      rd_data_lo = quotient_lo;
    else
      rd_data_lo = remainder_lo;

  // Actually a busy signal
  assign iready_o = imulh_ready_lo & idiv_ready_and_lo & ~rd_w_v_r & ~v_li;
  assign fready_o = fdiv_ready_lo & ~rd_w_v_r & ~v_li;

  assign iwb_pkt.ird_w_v    = rd_w_v_r;
  assign iwb_pkt.frd_w_v    = 1'b0;
  assign iwb_pkt.late       = 1'b1;
  assign iwb_pkt.rd_addr    = rd_addr_r;
  assign iwb_pkt.rd_data    = rd_data_lo;
  assign iwb_pkt.fflags_w_v = 1'b0;
  assign iwb_pkt.fflags     = '0;
  assign iwb_v_o = (imulh_done_v_r | idiv_done_v_r) & rd_w_v_r & wb_safe;

  assign fwb_pkt.ird_w_v    = 1'b0;
  assign fwb_pkt.frd_w_v    = rd_w_v_r;
  assign fwb_pkt.late       = 1'b1;
  assign fwb_pkt.rd_addr    = rd_addr_r;
  assign fwb_pkt.rd_data    = fdivsqrt_result;
  assign fwb_pkt.fflags_w_v = 1'b1;
  assign fwb_pkt.fflags     = fdivsqrt_fflags;
  assign fwb_v_o = fdiv_done_v_r & rd_w_v_r & wb_safe;

endmodule


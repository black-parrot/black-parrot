
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

module bp_be_hardfloat_fpu
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 #(parameter latency_p = 5) // Used for retiming
  (input                        clk_i
   , input                      reset_i

   // Operands
   //   Can be either integers, single precision or double precision
   , input [long_width_gp-1:0]  a_i
   , input [long_width_gp-1:0]  b_i
   , input [long_width_gp-1:0]  c_i

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
 
  // NaN boxing
  //
  logic [dp_rec_width_gp-1:0] a_rec_li, b_rec_li, c_rec_li;
  logic a_is_nan_li, b_is_nan_li, c_is_nan_li;
  logic a_is_snan_li, b_is_snan_li, c_is_snan_li;
  logic a_is_sub_li, b_is_sub_li, c_is_sub_li;
  bp_be_hardfloat_fpu_recode_in
   #(.els_p(3))
   recode_in
    (.fp_i({c_i, b_i, a_i})
  
     ,.ipr_i(ipr_i)
  
     ,.fp_o()
     ,.rec_o({c_rec_li, b_rec_li, a_rec_li})
     ,.nan_o({c_is_nan_li, b_is_nan_li, a_is_nan_li})
     ,.snan_o({c_is_snan_li, b_is_snan_li, a_is_snan_li})
     ,.sub_o({c_is_sub_li, b_is_sub_li, a_is_sub_li})
     );

  // Generate auxiliary information
  //
  // F[N]MADD/F[N]MSUB
  //
  logic [dp_rec_width_gp-1:0] fma_lo;
  rv64_fflags_s fma_eflags_lo;

  wire is_fadd_li    = (op_i == e_op_fadd);
  wire is_fsub_li    = (op_i == e_op_fsub);
  wire is_faddsub_li = is_fadd_li | is_fsub_li;
  wire is_fmul_li    = (op_i == e_op_fmul);
  wire is_fmadd_li   = (op_i == e_op_fmadd);
  wire is_fmsub_li   = (op_i == e_op_fmsub);
  wire is_fnmsub_li  = (op_i == e_op_fnmsub);
  wire is_fnmadd_li  = (op_i == e_op_fnmadd);
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
        fma_op_li = 3'b00;
      else if (is_fmsub_li | is_fsub_li)
        fma_op_li = 3'b01;
      else if (is_fnmsub_li)
        fma_op_li = 3'b10;
      else // if (is_fnmadd)
        fma_op_li = 3'b11;
    end

  wire [dp_rec_width_gp-1:0] fma_a_li = a_rec_li;
  wire [dp_rec_width_gp-1:0] fma_b_li = is_faddsub_li ? dp_rec_1_0 : b_rec_li;
  wire [dp_rec_width_gp-1:0] fma_c_li = is_faddsub_li
                                        ? b_rec_li
                                        : is_fmul_li
                                          ? dp_rec_0_0
                                          : c_rec_li;
  mulAddRecFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   fma
    (.control(control_li)
     ,.op(fma_op_li)
     ,.a(fma_a_li)
     ,.b(fma_b_li)
     ,.c(fma_c_li)
     ,.roundingMode(rm_i)
     ,.out(fma_lo)
     ,.out_imul()
     ,.exceptionFlags(fma_eflags_lo)
     );

  // Recoded result selection
  //
  logic [dp_float_width_gp-1:0] fp_result_lo;
  rv64_fflags_s fp_eflags_lo;
  bp_be_hardfloat_fpu_recode_out
   recode_out
    (.rec_i(fma_lo)
     ,.rec_eflags_i(fma_eflags_lo)
     ,.opr_i(opr_i)
     ,.rm_i(rm_i)

     ,.result_o(fp_result_lo)
     ,.result_eflags_o(fp_eflags_lo)
     );

  bsg_dff_chain
   #(.width_p($bits(rv64_fflags_s)+long_width_gp)
     ,.num_stages_p(latency_p-1)
     )
   retimer_chain
    (.clk_i(clk_i)

     ,.data_i({fp_eflags_lo, fp_result_lo})
     ,.data_o({eflags_o, o})
     );

endmodule


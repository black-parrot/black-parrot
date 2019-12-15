
module bp_be_hardfloat_fpu_recode_out
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 #(parameter latency_p          = 5 // Used for retiming
   , parameter dword_width_p    = 64
   , parameter word_width_p     = 32
   , parameter sp_exp_width_lp  = 8
   , parameter sp_sig_width_lp  = 24
   , parameter sp_width_lp      = sp_exp_width_lp+sp_sig_width_lp
   , parameter dp_exp_width_lp  = 11
   , parameter dp_sig_width_lp  = 53
   , parameter dp_width_lp      = dp_exp_width_lp+dp_sig_width_lp
   , parameter els_p            = 1

   , parameter sp_rec_width_lp = sp_exp_width_lp+sp_sig_width_lp+1
   , parameter dp_rec_width_lp = dp_exp_width_lp+dp_sig_width_lp+1
   )
  (input [dp_rec_width_lp-1:0]               rec_i
   , input [4:0]                             rec_eflags_i

   // Input/output precision of results. Applies to both integer and
   //   floating point operands and results
   , input bp_be_fp_pr_e                     opr_i
   , input rv64_frm_e                        rm_i

   , output [dword_width_p-1:0]              result_o
   , output [4:0]                            result_eflags_o
   );

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;
 
  // Classify the result
  //
  logic [sp_rec_width_lp-1:0] rec_result_dp2sp_lo;
  logic [4:0] dp2sp_eflags_lo;
  recFNToRecFN
   #(.inExpWidth(dp_exp_width_lp)
     ,.inSigWidth(dp_sig_width_lp)
     ,.outExpWidth(sp_exp_width_lp)
     ,.outSigWidth(sp_sig_width_lp)
     )
   rec_dp_to_sp
    (.control(control_li)
     ,.in(rec_i)
     ,.roundingMode(rm_i)
     ,.out(rec_result_dp2sp_lo)
     ,.exceptionFlags(dp2sp_eflags_lo)
     );

  // Un-recode the results
  //
  logic [dword_width_p-1:0] raw_dp_result_lo;
  recFNToFN
   #(.expWidth(dp_exp_width_lp)
     ,.sigWidth(dp_sig_width_lp)
     )
   out_dp_rec
    (.in(rec_i)
     ,.out(raw_dp_result_lo)
     );
  wire [dword_width_p-1:0] final_dp_result_lo = raw_dp_result_lo;

  logic [word_width_p-1:0] raw_sp_result_lo;
  recFNToFN
   #(.expWidth(sp_exp_width_lp)
     ,.sigWidth(sp_sig_width_lp)
     )
   out_sp_rec
    (.in(rec_result_dp2sp_lo)
     ,.out(raw_sp_result_lo)
     );
  // NaN-boxing
  wire [dword_width_p-1:0] final_sp_result_lo = {32'hffffffff, raw_sp_result_lo};

  assign result_o = (opr_i == e_pr_double) ? final_dp_result_lo : final_sp_result_lo;
  assign result_eflags_o = (opr_i == e_pr_double) ? rec_eflags_i : (rec_eflags_i | dp2sp_eflags_lo);

endmodule


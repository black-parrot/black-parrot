
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_reg_to_fp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dpath_width_gp-1:0]          reg_i
   , output logic [dword_width_gp-1:0] raw_o
   , output rv64_fflags_s              fflags_o
   );

 `bp_cast_i(bp_be_fp_reg_s, reg);

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  localparam bias_adj_lp = (1 << sp_exp_width_gp) - (1 << dp_exp_width_gp);
  bp_hardfloat_rec_dp_s dp_rec;
  bp_hardfloat_rec_sp_s dp2sp_rec_round, dp2sp_rec_unsafe, dp2sp_rec;
  assign dp_rec = reg_i;

  wire [sp_exp_width_gp:0] adjusted_exp = dp_rec.exp + bias_adj_lp;
  wire [2:0]                   exp_code = dp_rec.exp[dp_exp_width_gp-:3];
  wire                          special = (exp_code == '0) || (exp_code >= 3'd6);

  assign dp2sp_rec_unsafe = '{sign  : dp_rec.sign
                              ,exp  : special ? {exp_code, adjusted_exp[0+:sp_exp_width_gp-2]} : adjusted_exp
                              ,fract: dp_rec.fract[dp_sig_width_gp-2:dp_sig_width_gp-sp_sig_width_gp]
                              };

  rv64_fflags_s dp2sp_fflags;
  recFNToRecFN
   #(.inExpWidth(dp_exp_width_gp)
     ,.inSigWidth(dp_sig_width_gp)
     ,.outExpWidth(sp_exp_width_gp)
     ,.outSigWidth(sp_sig_width_gp)
     )
   round
    (.control(control_li)
     ,.in(reg_cast_i.rec)
     ,.roundingMode(reg_cast_i.tag)
     ,.out(dp2sp_rec_round)
     ,.exceptionFlags(dp2sp_fflags)
     );

  wire is_nan = &reg_cast_i.rec[dp_rec_width_gp-2-:3];

  assign dp2sp_rec = is_nan ? dp2sp_rec_unsafe : dp2sp_rec_round;
  assign fflags_o  = (reg_cast_i.tag == e_fp_full || is_nan) ? '0 : dp2sp_fflags;

  logic [word_width_gp-1:0] sp_raw_lo;
  recFNToFN
   #(.expWidth(sp_exp_width_gp)
     ,.sigWidth(sp_sig_width_gp)
     )
   out_sp_rec
    (.in(dp2sp_rec)
     ,.out(sp_raw_lo)
     );

  logic [dword_width_gp-1:0] dp_raw_lo;
  recFNToFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   out_dp_rec
    (.in(reg_cast_i.rec)
     ,.out(dp_raw_lo)
     );

  assign raw_o = (reg_cast_i.tag == e_fp_full) ? dp_raw_lo : {32'hffff_ffff, sp_raw_lo};

endmodule


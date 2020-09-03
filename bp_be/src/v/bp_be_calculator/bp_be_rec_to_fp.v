
module bp_be_rec_to_fp
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_hardfloat_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dp_rec_width_gp-1:0]    rec_i

   , input                        raw_sp_not_dp_i
   , output [dword_width_p-1:0]   raw_o
   );

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  localparam bias_adj_lp = (1 << sp_exp_width_gp) - (1 << dp_exp_width_gp);
  bp_hardfloat_rec_dp_s dp_rec;
  bp_hardfloat_rec_sp_s dp2sp_rec;
  assign dp_rec = rec_i;

  wire [sp_exp_width_gp:0] adjusted_exp = dp_rec.exp + bias_adj_lp;
  wire [2:0]                   exp_code = dp_rec.exp[dp_exp_width_gp-:3];
  wire                          special = (exp_code == '0) || (exp_code >= 3'd6);

  assign dp2sp_rec = '{sign  : dp_rec.sign
                       ,exp  : special ? {exp_code, adjusted_exp[0+:sp_exp_width_gp-2]} : adjusted_exp
                       ,fract: dp_rec.fract >> (dp_sig_width_gp-sp_sig_width_gp)
                       };

  logic [word_width_p-1:0] sp_raw_lo;
  recFNToFN
   #(.expWidth(sp_exp_width_gp)
     ,.sigWidth(sp_sig_width_gp)
     )
   out_sp_rec
    (.in(dp2sp_rec)
     ,.out(sp_raw_lo)
     );

  logic [dword_width_p-1:0] dp_raw_lo;
  recFNToFN
   #(.expWidth(dp_exp_width_gp)
     ,.sigWidth(dp_sig_width_gp)
     )
   out_dp_rec
    (.in(dp_rec)
     ,.out(dp_raw_lo)
     );

  assign raw_o = raw_sp_not_dp_i ? {32'hffff_ffff, sp_raw_lo} : dp_raw_lo;

endmodule


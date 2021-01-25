
package bp_be_pkg;

  import bp_common_pkg::*;

  localparam dpath_width_gp = 66;

  typedef struct packed
  {
    logic        sp_not_dp;
    logic [64:0] rec;
  } bp_be_fp_reg_s;

  localparam sp_float_width_gp = 32;
  localparam sp_rec_width_gp   = 33;
  localparam sp_exp_width_gp   = 8;
  localparam sp_sig_width_gp   = 24;

  localparam dp_float_width_gp = 64;
  localparam dp_rec_width_gp   = 65;
  localparam dp_exp_width_gp   = 11;
  localparam dp_sig_width_gp   = 53;

  localparam [dp_float_width_gp-1:0] dp_canonical_nan = 64'h7ff80000_00000000;
  localparam [dp_float_width_gp-1:0] sp_canonical_nan = 64'hffffffff_7fc00000;

  localparam [dp_rec_width_gp-1:0] dp_rec_1_0 = 65'h0_80000000_00000000;
  localparam [dp_rec_width_gp-1:0] dp_rec_0_0 = 65'h0_00000000_00000000;

  localparam [dp_rec_width_gp-1:0] dp_canonical_rec = 65'h0_e0080000_00000000;

  typedef struct packed
  {
    logic                       sign;
    logic [sp_exp_width_gp:0]   exp;
    logic [sp_sig_width_gp-2:0] fract;
  }  bp_hardfloat_rec_sp_s;

  typedef struct packed
  {
    logic                       sign;
    logic [dp_exp_width_gp:0]   exp;
    logic [dp_sig_width_gp-2:0] fract;
  }  bp_hardfloat_rec_dp_s;

  `include "bp_be_ctl_pkgdef.svh"
  `include "bp_be_dcache_pkgdef.svh"

endpackage


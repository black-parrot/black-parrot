
package bp_be_hardfloat_pkg;

  localparam long_width_gp     = 64;
  localparam word_width_gp     = 32;

  localparam sp_float_width_gp = 32;
  localparam sp_rec_width_gp   = 33;
  localparam sp_exp_width_gp   = 8;
  localparam sp_sig_width_gp   = 24;

  localparam dp_float_width_gp = 64;
  localparam dp_rec_width_gp   = 65;
  localparam dp_exp_width_gp   = 11;
  localparam dp_sig_width_gp   = 53;

  localparam [dp_float_width_gp-1:0] dp_canonical = 64'h7ff80000_00000000;
  localparam [dp_float_width_gp-1:0] sp_canonical = 64'hffffffff_7fc00000;

  localparam [dp_rec_width_gp-1:0] dp_rec_1_0 = 65'h0_80000000_00000000;
  localparam [dp_rec_width_gp-1:0] dp_rec_0_0 = 65'h0_00000000_00000000;

  localparam [dp_rec_width_gp-1:0] dp_canonical_rec = 65'h0_e0080000_00000000;

endpackage


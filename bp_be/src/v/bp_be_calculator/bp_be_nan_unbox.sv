
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_nan_unbox
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [dpath_width_gp-1:0]          reg_i
   , input                             unbox_i
   , output logic [dpath_width_gp-1:0] reg_o
   );

 `bp_cast_i(bp_be_fp_reg_s, reg);
 `bp_cast_o(bp_be_fp_reg_s, reg);

  wire invbox = unbox_i & (reg_cast_i.tag == e_fp_full);
  // Bug in XSIM 2019.2 causes SEGV when assigning to structs with a mux
  bp_be_fp_reg_s invbox_nan;
  assign invbox_nan = '{tag: unbox_i ? e_rne : e_fp_full, rec: dp_canonical_rec};
  assign reg_cast_o = invbox ? invbox_nan : reg_i;

endmodule


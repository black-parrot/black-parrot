
module bp_pma
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                      ptag_v_i
   , input [ptag_width_p-1:0] ptag_i

   , output                   uncached_o
   );

  // FIXME: OpenPiton integration
  assign uncached_o = ptag_v_i & (ptag_i < (dram_base_addr_gp >> page_offset_width_p)) || ptag_i[ptag_width_p-1];

endmodule


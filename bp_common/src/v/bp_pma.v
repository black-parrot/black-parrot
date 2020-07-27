
module bp_pma
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                          clk_i
   , input                        reset_i
  
   , input                        ptag_v_i
   , input [ptag_width_p-1:0]     ptag_i

   , output                       uncached_o
   );

  wire is_local_addr = (ptag_i < (dram_base_addr_gp >> page_offset_width_p));
  wire is_io_addr    = (ptag_i[ptag_width_p-1-:io_noc_did_width_p] != '0);

  assign uncached_o = ptag_v_i & (is_local_addr | is_io_addr);

endmodule


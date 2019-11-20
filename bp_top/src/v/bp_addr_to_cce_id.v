
module bp_addr_to_cce_id
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   //, localparam cce_id_width_lp     = `BSG_SAFE_CLOG2(num_cce_p)
   //, localparam coh_cce_id_width_lp = `BSG_SAFE_CLOG2(num_coh_cce_p)
   //, localparam acc_id_width_lp     = `BSG_SAFE_CLOG2(coh_noc_y_dim_p)
   )
  (input [paddr_width_p-1:0]     paddr_i

   , output logic [cce_id_width_p-1:0] cce_id_o
   );

/*
always_comb
  if (paddr_i < dram_base_addr_gp)
    begin
      // Split uncached I/O region by N CCE cores
      // TODO: hardcoded bit range, should be in defines file
      cce_id_o = paddr_i[37-:cce_id_width_lp];
    end
  else if (paddr_i < coproc_base_addr_gp)
    begin
      // Stripe by cache line
      cce_id_o = paddr_i[page_offset_width_p+:coh_cce_id_width_lp];
    end
  else if (paddr_i < global_base_addr_gp)
    begin
      // Stripe by 1MB pages
      cce_id_o = paddr_i[20+:acc_id_width_lp];
    end
  else
    begin
      // Split global address by N CCE cores
      cce_id_o = paddr_i[37-:cce_id_width_lp];
    end
*/

endmodule


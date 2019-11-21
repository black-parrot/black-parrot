
module bp_me_addr_to_cce_id
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [paddr_width_p-1:0]           paddr_i

   , output logic [cce_id_width_p-1:0] cce_id_o
   );

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
      cce_id_o = (num_cce_p > 0) ? paddr_i[page_offset_width_p+:`BSG_SAFE_CLOG2(num_cce_p)] : '0;
    end
  else if (paddr_i < global_base_addr_gp)
    begin
      // Stripe by 1MB pages
    end
  else
    begin
      // Split global address by N CCE cores
    end

endmodule


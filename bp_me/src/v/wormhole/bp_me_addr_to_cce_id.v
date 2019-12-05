
module bp_me_addr_to_cce_id
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [paddr_width_p-1:0]           paddr_i

   , output logic [cce_id_width_p-1:0] cce_id_o
   );

bp_local_addr_s local_addr_li;

assign local_addr_li = paddr_i;

localparam max_cc_cce_lp  = num_core_p;
localparam max_mc_cce_lp  = max_cc_cce_lp + num_l2e_p;
localparam max_cac_cce_lp = max_mc_cce_lp + num_cacc_p;
localparam max_sac_cce_lp = max_cac_cce_lp + num_sacc_p;
localparam max_ioc_cce_lp = max_sac_cce_lp + num_io_p;

localparam block_offset_lp = `BSG_SAFE_CLOG2(cce_block_width_p);
always_comb
  if ((paddr_i >= host_dev_base_addr_gp) && (paddr_i < cce_dev_base_addr_gp))
    begin
      // Stripe by 4kiB page, start at io CCE id
      cce_id_o = (num_io_p > 1) 
                 ? max_sac_cce_lp + paddr_i[page_offset_width_p+:`BSG_SAFE_CLOG2(num_io_p)] 
                 : max_sac_cce_lp;
    end
  else if (paddr_i < dram_base_addr_gp)
    begin
      // Split uncached I/O region by 128 cores
      cce_id_o = local_addr_li.cce;
    end
  else if (paddr_i < coproc_base_addr_gp)
    begin
      // Stripe by cache line
      cce_id_o = (num_cce_p > 1) ? paddr_i[block_offset_lp+:`BSG_SAFE_CLOG2(num_cce_p)] : '0;
    end
  else if (paddr_i < global_base_addr_gp)
    begin
      // Stripe by 4kiB page, start at sac CCE id
      cce_id_o = '0;
      //cce_id_o = max_cac_cce_lp 
      //           + (num_cacc_p > 1) ? paddr_i[page_offset_width_p+:`BSG_SAFE_CLOG2(num_cacc_p)] : '0;
    end
  else
    begin
      // Stripe by 4kiB page, start at io CCE id
      cce_id_o = (num_io_p > 1) 
                 ? max_sac_cce_lp + paddr_i[page_offset_width_p+:`BSG_SAFE_CLOG2(num_io_p)] 
                 : max_sac_cce_lp;
    end

endmodule


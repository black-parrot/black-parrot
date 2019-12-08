
module bp_me_addr_to_cce_id
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [paddr_width_p-1:0]           paddr_i

   , output logic [cce_id_width_p-1:0] cce_id_o
   );

bp_global_addr_s global_addr_li;
bp_local_addr_s  local_addr_li;

assign global_addr_li = paddr_i;
assign local_addr_li  = paddr_i;

localparam max_cc_cce_lp  = num_core_p;
localparam max_mc_cce_lp  = max_cc_cce_lp + num_l2e_p;
localparam max_cac_cce_lp = max_mc_cce_lp + num_cacc_p;
localparam max_sac_cce_lp = max_cac_cce_lp + num_sacc_p;
localparam max_ioc_cce_lp = max_sac_cce_lp + num_io_p;

wire external_io_li = (global_addr_li.did > '0);

localparam block_offset_lp = `BSG_SAFE_CLOG2(cce_block_width_p);
always_comb
  if (external_io_li || (local_addr_li.dev == host_dev_gp))
    // Stripe by 4kiB page, start at io CCE id
    cce_id_o = (num_io_p > 1)
               ? max_sac_cce_lp + paddr_i[page_offset_width_p+:`BSG_SAFE_CLOG2(num_io_p)]
               : max_sac_cce_lp;
  else if (paddr_i < dram_base_addr_gp)
    // Split uncached I/O region by max 128 cores
    cce_id_o = local_addr_li.cce;
  else if ((paddr_i >= dram_base_addr_gp) && (paddr_i < coproc_base_addr_gp))
    // Stripe by cache line
    cce_id_o = (num_cce_p > 1) ? paddr_i[block_offset_lp+:`BSG_SAFE_CLOG2(num_cce_p)] : '0;
  else
    // TODO: Coprocessor address space, figure out.  Probably striped by CCEs within the AC
    cce_id_o = '0;

endmodule




module bp_me_addr_to_cce_id
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [paddr_width_p-1:0]           paddr_i

   , output logic [cce_id_width_p-1:0] cce_id_o
   );

bp_global_addr_s global_addr_li;
bp_local_addr_s  local_addr_li;

assign global_addr_li = paddr_i;
assign local_addr_li  = paddr_i;

  // CCE: CC -> MC -> CAC -> SAC -> IOC
localparam max_cc_cce_lp  = num_core_p;
localparam max_mc_cce_lp  = max_cc_cce_lp + num_l2e_p;
localparam max_cac_cce_lp = max_mc_cce_lp + num_cacc_p;
localparam max_sac_cce_lp = max_cac_cce_lp + num_sacc_p;
localparam max_ioc_cce_lp = max_sac_cce_lp + num_io_p;

wire external_io_v_li = (global_addr_li.did > '1);
wire local_addr_v_li = (paddr_i < dram_base_addr_gp);
wire dram_addr_v_li = (paddr_i >= dram_base_addr_gp) && (paddr_i < coproc_base_addr_gp);
wire core_local_addr_v_li = local_addr_v_li && (local_addr_li.cce < num_core_p);   
     
localparam block_offset_lp = `BSG_SAFE_CLOG2(cce_block_width_p/8);
localparam lg_lce_sets_lp = `BSG_SAFE_CLOG2(lce_sets_p);
localparam lg_num_cce_lp = `BSG_SAFE_CLOG2(num_cce_p);

// convert miss address (excluding block offset bits) into CCE ID
// For now, assume all CCE's have ID [0,num_core_p-1] and addresses are striped
// at the cache block granularity
logic [lg_lce_sets_lp-1:0] hash_addr_li;
logic [lg_num_cce_lp-1:0] cce_dst_id_lo;
assign hash_addr_li = {<< {paddr_i[block_offset_lp+:lg_lce_sets_lp]}};
bsg_hash_bank
  #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
    ,.width_p(lg_lce_sets_lp) // width of address input
    )
  addr_to_cce_id
   (.i(hash_addr_li)
    ,.bank_o(cce_dst_id_lo)
    ,.index_o()
    );

always_comb begin
  cce_id_o = '0;
  if (external_io_v_li || (core_local_addr_v_li && (local_addr_li.dev inside {boot_dev_gp, host_dev_gp})))
    // Stripe by 4kiB page, start at io CCE id
    cce_id_o = (num_io_p > 1)
               ? max_sac_cce_lp + paddr_i[page_offset_width_p+:`BSG_SAFE_CLOG2(num_io_p)]
               : max_sac_cce_lp;
  else if (local_addr_v_li)
    // Split uncached I/O region by max 128 cores
    cce_id_o = local_addr_li.cce;
  else if (dram_addr_v_li)
    // Stripe by cache line
    cce_id_o[0+:lg_num_cce_lp] = cce_dst_id_lo;
  else
    cce_id_o = (num_sacc_p > 1)
               ? max_cac_cce_lp + paddr_i[paddr_width_p-io_noc_did_width_p-1-: (num_sacc_p > 1 ? `BSG_SAFE_CLOG2(num_sacc_p) : 1)]
               : max_cac_cce_lp;
     
   
end

endmodule



// TODO: Configure to handle network configurations more flexibly
module bp_me_cce_id_to_cord
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [cce_id_width_p-1:0]                cce_id_i
   , output logic [coh_noc_cord_width_p-1:0] cce_cord_o
   , output logic [coh_noc_cid_width_p-1:0]  cce_cid_o
   );


  // CCE: CC -> MC -> CAC -> SAC -> IOC
  localparam max_cc_cce_lp  = num_core_p;
  localparam max_mc_cce_lp  = max_cc_cce_lp + num_l2e_p;
  localparam max_cac_cce_lp = max_mc_cce_lp + num_cacc_p;
  localparam max_sac_cce_lp = max_cac_cce_lp + num_sacc_p;
  localparam max_ioc_cce_lp = max_sac_cce_lp + num_io_p;

  // TODO: We only support 1 additional column / row for non-core-complex accelerators
  always_comb
    // Core complex
    if (cce_id_i < max_cc_cce_lp)
      begin
        cce_cord_o[0+:coh_noc_x_cord_width_p]                      = sac_x_dim_p + (cce_id_i % cc_x_dim_p);
        cce_cord_o[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p] = ic_y_dim_p  + (cce_id_i / cc_x_dim_p);
        cce_cid_o = '0;
      end
    // Memory complex
    else if (cce_id_i < max_mc_cce_lp)
      begin
        cce_cord_o[0+:coh_noc_x_cord_width_p]                      = sac_x_dim_p + (cce_id_i % cc_x_dim_p);
        cce_cord_o[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p] = ic_y_dim_p + cc_y_dim_p;
        cce_cid_o = '0;
      end
    // Coherent accelerator complex
    else if (cce_id_i < max_cac_cce_lp)
      begin
        cce_cord_o[0+:coh_noc_x_cord_width_p]                      = sac_x_dim_p + cc_x_dim_p;
        cce_cord_o[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p] = ic_y_dim_p  + (cce_id_i % cc_y_dim_p);
        cce_cid_o = '0;
      end
    // Streaming accelerator complex
    else if (cce_id_i < max_sac_cce_lp)
      begin
        cce_cord_o[0+:coh_noc_x_cord_width_p]                      = '0;
        cce_cord_o[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p] = ic_y_dim_p + (cce_id_i % cc_y_dim_p);
        cce_cid_o = '0;
      end
    // IO complex
    else
      begin
        cce_cord_o[0+:coh_noc_x_cord_width_p]                      = sac_x_dim_p + (cce_id_i % cc_x_dim_p);
        cce_cord_o[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p] = '0;
        cce_cid_o = '0;
      end

endmodule


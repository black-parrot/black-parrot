
// TODO: Configure to handle network configurations more flexibly
module bp_me_lce_id_to_cord
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   , localparam lce_id_width_lp = `BSG_SAFE_CLOG2(num_lce_p)
   )
  (input [lce_id_width_lp-1:0]         lce_id_i
   , output [coh_noc_cord_width_p-1:0] lce_cord_o
   , output [coh_noc_cid_width_p-1:0]  lce_cid_o
   );

  if (coh_noc_dims_p > 0)
    begin : x_cord
      assign lce_cord_o[0+:coh_noc_x_cord_width_p] = 
        (lce_id_i >> 1'b1) % lce_id_width_lp'(coh_noc_x_dim_p);
    end
  if (coh_noc_dims_p > 1)
    begin : y_cord
      assign lce_cord_o[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p] = 
        (lce_id_i >> 1'b1) / lce_id_width_lp'(coh_noc_x_dim_p);
    end
      assign lce_cid_o = coh_noc_cid_width_p'(lce_id_i[0]);

endmodule


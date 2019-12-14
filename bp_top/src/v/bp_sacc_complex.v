
module bp_sacc_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   )
  (input                                                         core_clk_i
   , input                                                       core_reset_i

   , input                                                       coh_clk_i
   , input                                                       coh_reset_i

   , input [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]      coh_req_link_i
   , output [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]     coh_req_link_o

   , input [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]      coh_cmd_link_i
   , output [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]     coh_cmd_link_o

   , input [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]      coh_resp_link_i
   , output [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]     coh_resp_link_o
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);

  bp_coh_ready_and_link_s [sac_y_dim_p-1:0][S:W] lce_req_link_li, lce_req_link_lo;
  bp_coh_ready_and_link_s [E:W][sac_y_dim_p-1:0] lce_req_hor_link_li, lce_req_hor_link_lo;
  bp_coh_ready_and_link_s [S:N]                  lce_req_ver_link_li, lce_req_ver_link_lo;
  
  bp_coh_ready_and_link_s [sac_y_dim_p-1:0][S:W] lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [E:W][sac_y_dim_p-1:0] lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
  bp_coh_ready_and_link_s [S:N]                  lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
  
  bp_coh_ready_and_link_s [sac_y_dim_p-1:0][S:W] lce_resp_link_li, lce_resp_link_lo;
  bp_coh_ready_and_link_s [E:W][sac_y_dim_p-1:0] lce_resp_hor_link_li, lce_resp_hor_link_lo;
  bp_coh_ready_and_link_s [S:N]                  lce_resp_ver_link_li, lce_resp_ver_link_lo;
  
  // TODO: Insert tiles here
  //
  // Note: Probably what makes sense is a pseudo-hardware generator here.
  //   i.e. we leave `accelerator_type_1, `accelerator_type_2
  //   and then substitute based on a parameter pattern...
  //
  if (sac_x_dim_p > 0)
    begin : sacc_stitch
      assign lce_req_ver_link_li    = '0;
      assign lce_req_hor_link_li[E] = coh_req_link_i;
      assign lce_req_hor_link_li[W] = '0;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(sac_x_dim_p)
         ,.y_max_p(1)
         )
       coh_req_mesh
        (.outs_i(lce_req_link_lo)
         ,.ins_o(lce_req_link_li)

         ,.hor_i(lce_req_hor_link_li)
         ,.hor_o(lce_req_hor_link_lo)
         ,.ver_i(lce_req_ver_link_li)
         ,.ver_o(lce_req_ver_link_lo)
         );
      assign coh_req_link_o = lce_req_ver_link_lo[E];

      assign lce_cmd_ver_link_li    = '0;
      assign lce_cmd_hor_link_li[E] = coh_cmd_link_i;
      assign lce_cmd_hor_link_li[W] = '0;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(sac_x_dim_p)
         ,.y_max_p(1)
         )
       coh_cmd_mesh
        (.outs_i(lce_cmd_link_lo)
         ,.ins_o(lce_cmd_link_li)

         ,.hor_i(lce_cmd_hor_link_li)
         ,.hor_o(lce_cmd_hor_link_lo)
         ,.ver_i(lce_cmd_ver_link_li)
         ,.ver_o(lce_cmd_ver_link_lo)
         );
      assign coh_cmd_link_o = lce_cmd_ver_link_lo[E];

      assign lce_resp_ver_link_li    = '0;
      assign lce_resp_hor_link_li[E] = coh_resp_link_i;
      assign lce_resp_hor_link_li[W] = '0;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(sac_x_dim_p)
         ,.y_max_p(1)
         )
       coh_resp_mesh
        (.outs_i(lce_resp_link_lo)
         ,.ins_o(lce_resp_link_li)

         ,.hor_i(lce_resp_hor_link_li)
         ,.hor_o(lce_resp_hor_link_lo)
         ,.ver_i(lce_resp_ver_link_li)
         ,.ver_o(lce_resp_ver_link_lo)
         );
      assign coh_resp_link_o = lce_resp_ver_link_lo[E];
    end
  else
    begin : stub
      assign coh_req_link_o  = '0;
      assign coh_cmd_link_o  = '0;
      assign coh_resp_link_o = '0;
    end

endmodule


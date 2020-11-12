module bp_sacc_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   )
  (input                                                        core_clk_i
   , input                                                      core_reset_i

   , input                                                      coh_clk_i
   , input                                                      coh_reset_i

   , input [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]     coh_req_link_i
   , output [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]    coh_req_link_o

   , input [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]     coh_cmd_link_i
   , output [sac_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]    coh_cmd_link_o

   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);

  bp_coh_ready_and_link_s [sac_y_dim_p-1:0][S:W] lce_req_link_li, lce_req_link_lo;
  bp_coh_ready_and_link_s [E:W][sac_y_dim_p-1:0] lce_req_hor_link_li, lce_req_hor_link_lo;
  bp_coh_ready_and_link_s [S:N]                  lce_req_ver_link_li, lce_req_ver_link_lo;

  bp_coh_ready_and_link_s [sac_y_dim_p-1:0][S:W] lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [E:W][sac_y_dim_p-1:0] lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
  bp_coh_ready_and_link_s [S:N]                  lce_cmd_ver_link_li, lce_cmd_ver_link_lo;


  for (genvar j=0; j < sac_y_dim_p; j++)
    begin : y
       wire [coh_noc_cord_width_p-1:0] cord_li = {coh_noc_y_cord_width_p'(ic_y_dim_p+j),
                                                  coh_noc_x_cord_width_p'(sac_x_dim_p-1)};
       if (sac_x_dim_p>0)
         begin : node
           bp_sacc_tile_node
             #(.bp_params_p(bp_params_p))
             accel_tile_node
               (.core_clk_i(core_clk_i)
               ,.core_reset_i(core_reset_i)

               ,.coh_clk_i(coh_clk_i)
               ,.coh_reset_i(coh_reset_i)

               ,.my_cord_i(cord_li)

               ,.coh_lce_req_link_i(lce_req_link_li[j])
               ,.coh_lce_cmd_link_i(lce_cmd_link_li[j])

               ,.coh_lce_req_link_o(lce_req_link_lo[j])
               ,.coh_lce_cmd_link_o(lce_cmd_link_lo[j])
               );
        end
      else
        begin : stub
          assign lce_req_link_lo[j] = '0;
          assign lce_cmd_link_lo[j] = '0;
        end
  end



  if (sac_x_dim_p > 0)
    begin : sac_stitch
      assign lce_req_ver_link_li    = '0;
      assign lce_req_hor_link_li[W] = '0;
      assign lce_req_hor_link_li[E] = coh_req_link_i;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(sac_x_dim_p)
         ,.y_max_p(sac_y_dim_p)
         )
       coh_req_mesh
        (.outs_i(lce_req_link_lo)
         ,.ins_o(lce_req_link_li)

         ,.hor_i(lce_req_hor_link_li)
         ,.hor_o(lce_req_hor_link_lo)
         ,.ver_i(lce_req_ver_link_li)
         ,.ver_o(lce_req_ver_link_lo)
         );
      assign coh_req_link_o = lce_req_hor_link_lo[E];

      assign lce_cmd_ver_link_li    = '0;
      assign lce_cmd_hor_link_li[W] = '0;
      assign lce_cmd_hor_link_li[E] = coh_cmd_link_i;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(sac_x_dim_p)
         ,.y_max_p(sac_y_dim_p)
         )
       coh_cmd_mesh
        (.outs_i(lce_cmd_link_lo)
         ,.ins_o(lce_cmd_link_li)

         ,.hor_i(lce_cmd_hor_link_li)
         ,.hor_o(lce_cmd_hor_link_lo)
         ,.ver_i(lce_cmd_ver_link_li)
         ,.ver_o(lce_cmd_ver_link_lo)
         );
      assign coh_cmd_link_o = lce_cmd_hor_link_lo[E];
    end
  else
    begin : stub
      assign coh_req_link_o  = '0;
      assign coh_cmd_link_o  = '0;
    end

endmodule


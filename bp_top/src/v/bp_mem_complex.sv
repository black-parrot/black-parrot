
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_mem_complex
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                     core_clk_i
   , input                                                   core_reset_i

   , input                                                   coh_clk_i
   , input                                                   coh_reset_i

   , input                                                   mem_clk_i
   , input                                                   mem_reset_i

   , input [io_noc_did_width_p-1:0]                          my_did_i

   , input  [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_i
   , output [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_o

   , input  [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_i
   , output [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_o

   , input  [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_link_i
   , output [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_link_o

   , input  [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_o

   , output [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  dram_cmd_link_o
   , input [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]   dram_resp_link_i
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  bp_coh_ready_and_link_s [mc_x_dim_p-1:0][S:W] lce_req_link_li, lce_req_link_lo;
  bp_coh_ready_and_link_s [E:W]                 lce_req_hor_link_li, lce_req_hor_link_lo;
  bp_coh_ready_and_link_s [S:N][mc_x_dim_p-1:0] lce_req_ver_link_li, lce_req_ver_link_lo;
  bp_coh_ready_and_link_s [mc_x_dim_p-1:0][S:W] lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [E:W]                 lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
  bp_coh_ready_and_link_s [S:N][mc_x_dim_p-1:0] lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
  bp_coh_ready_and_link_s [mc_x_dim_p-1:0][S:W] lce_resp_link_li, lce_resp_link_lo;
  bp_coh_ready_and_link_s [E:W]                 lce_resp_hor_link_li, lce_resp_hor_link_lo;
  bp_coh_ready_and_link_s [S:N][mc_x_dim_p-1:0] lce_resp_ver_link_li, lce_resp_ver_link_lo;

  bp_mem_ready_and_link_s [mc_x_dim_p-1:0] mem_cmd_link_li, mem_cmd_link_lo;
  bp_mem_ready_and_link_s [mc_x_dim_p-1:0] mem_resp_link_li, mem_resp_link_lo;
  bp_mem_ready_and_link_s [S:N][mc_x_dim_p-1:0] mem_ver_link_li, mem_ver_link_lo;

  for (genvar i = 0; i < mc_x_dim_p; i++)
    begin : node
      wire [coh_noc_cord_width_p-1:0] cord_li = {coh_noc_y_cord_width_p'(1'b1+cc_y_dim_p), coh_noc_x_cord_width_p'(i+sac_x_dim_p)};

      if (mc_y_dim_p > 0)
        begin : node
          bp_l2e_tile_node
           #(.bp_params_p(bp_params_p))
           l2e
            (.core_clk_i(core_clk_i)
             ,.core_reset_i(core_reset_i)

             ,.coh_clk_i(coh_clk_i)
             ,.coh_reset_i(coh_reset_i)

             ,.mem_clk_i(mem_clk_i)
             ,.mem_reset_i(mem_reset_i)

             ,.my_did_i(my_did_i)
             ,.my_cord_i(cord_li)

             ,.coh_lce_req_link_i(lce_req_link_li[i])
             ,.coh_lce_req_link_o(lce_req_link_lo[i])

             ,.coh_lce_cmd_link_i(lce_cmd_link_li[i])
             ,.coh_lce_cmd_link_o(lce_cmd_link_lo[i])

             ,.coh_lce_resp_link_i(lce_resp_link_li[i])
             ,.coh_lce_resp_link_o(lce_resp_link_lo[i])

             ,.mem_cmd_link_i(mem_cmd_link_li[i])
             ,.mem_cmd_link_o(mem_cmd_link_lo[i])

             ,.mem_resp_link_i(mem_resp_link_li[i])
             ,.mem_resp_link_o(mem_resp_link_lo[i])
             );
        end
      else
        begin : stub
          assign lce_req_link_lo[i]  = '0;
          assign lce_cmd_link_lo[i]  = '0;
          assign lce_resp_link_lo[i] = '0;

          assign mem_cmd_link_lo[i]  = '0;
          assign mem_resp_link_lo[i] = '0;
        end
    end

  if (mc_y_dim_p > 0)
    begin : stitch
      assign lce_req_ver_link_li[N] = coh_req_link_i;
      assign lce_req_ver_link_li[S] = '0;
      assign lce_req_hor_link_li    = '0;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(mc_x_dim_p)
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
      assign coh_req_link_o = lce_req_ver_link_lo[N];

      assign lce_cmd_ver_link_li[N] = coh_cmd_link_i;
      assign lce_cmd_ver_link_li[S] = '0;
      assign lce_cmd_hor_link_li    = '0;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(mc_x_dim_p)
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
      assign coh_cmd_link_o = lce_cmd_ver_link_lo[N];

      assign lce_resp_ver_link_li[N] = coh_resp_link_i;
      assign lce_resp_ver_link_li[S] = '0;
      assign lce_resp_hor_link_li    = '0;
      bsg_mesh_stitch
       #(.width_p(coh_noc_ral_link_width_lp)
         ,.x_max_p(mc_x_dim_p)
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
      assign coh_resp_link_o = lce_resp_ver_link_lo[N];

      bp_mem_ready_and_link_s [mc_x_dim_p-1:0][S:W] mem_mesh_lo, mem_mesh_li;
      for (genvar j = 0; j < mc_x_dim_p; j++)
        begin : link
          assign mem_mesh_lo[j][S] = mem_cmd_link_lo[j];
          assign mem_mesh_lo[j][N] = mem_resp_link_lo[j];

          assign mem_cmd_link_li[j] = mem_mesh_li[j][N];
          assign mem_resp_link_li[j] = mem_mesh_li[j][S];
        end
      assign mem_ver_link_li[N] = mem_cmd_link_i;
      bsg_mesh_stitch
       #(.width_p($bits(bp_mem_ready_and_link_s))
         ,.x_max_p(mc_x_dim_p)
         ,.y_max_p(1)
         )
       mem_mesh
        (.outs_i(mem_mesh_lo)
         ,.ins_o(mem_mesh_li)

         ,.hor_i()
         ,.hor_o()
         ,.ver_i(mem_ver_link_li)
         ,.ver_o(mem_ver_link_lo)
         );
      assign mem_resp_link_o = mem_ver_link_lo[N];
    end
  else
    begin : stub
      assign coh_req_link_o = '0;
      assign coh_cmd_link_o = '0;
      assign coh_resp_link_o = '0;

      assign mem_ver_link_lo[S] = mem_cmd_link_i;
      assign mem_resp_link_o = mem_ver_link_li[S];
    end

  assign dram_cmd_link_o = mem_ver_link_lo[S];
  assign mem_ver_link_li[S] = dram_resp_link_i;

endmodule


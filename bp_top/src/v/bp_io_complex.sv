
module bp_io_complex
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
   , localparam io_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   )
  (input                                                         core_clk_i
   , input                                                       core_reset_i

   , input                                                       coh_clk_i
   , input                                                       coh_reset_i

   , input                                                       io_clk_i
   , input                                                       io_reset_i

   , input [io_noc_did_width_p-1:0]                              my_did_i
   , input [io_noc_did_width_p-1:0]                              host_did_i

   , input [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]       coh_req_link_i
   , output [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]      coh_req_link_o

   , input [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]       coh_cmd_link_i
   , output [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]      coh_cmd_link_o

   , input [E:W][io_noc_ral_link_width_lp-1:0]                   io_cmd_link_i
   , output [E:W][io_noc_ral_link_width_lp-1:0]                  io_cmd_link_o

   , input [E:W][io_noc_ral_link_width_lp-1:0]                   io_resp_link_i
   , output [E:W][io_noc_ral_link_width_lp-1:0]                  io_resp_link_o
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_ready_and_link_s);

  bp_io_ready_and_link_s [ic_x_dim_p-1:0][E:W]  io_cmd_link_li, io_cmd_link_lo, io_resp_link_li, io_resp_link_lo;
  bp_io_ready_and_link_s [E:W]                   io_cmd_hor_link_li, io_cmd_hor_link_lo, io_resp_hor_link_li, io_resp_hor_link_lo;
  bp_coh_ready_and_link_s [ic_x_dim_p-1:0][S:W] lce_req_link_li, lce_req_link_lo, lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [S:N][ic_x_dim_p-1:0] lce_req_ver_link_li, lce_req_ver_link_lo, lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
  bp_coh_ready_and_link_s [E:W]                  lce_req_hor_link_li, lce_req_hor_link_lo, lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
  
  for (genvar i = 0; i < ic_x_dim_p; i++)
    begin : node
      wire [coh_noc_cord_width_p-1:0] cord_li = {'0, coh_noc_x_cord_width_p'(i+sac_x_dim_p)};
      bp_io_tile_node
       #(.bp_params_p(bp_params_p))
       io
        (.core_clk_i(core_clk_i)
         ,.core_reset_i(core_reset_i)
  
         ,.coh_clk_i(coh_clk_i)
         ,.coh_reset_i(coh_reset_i)
  
         ,.io_clk_i(io_clk_i)
         ,.io_reset_i(io_reset_i)
  
         ,.host_did_i(host_did_i)
         ,.my_did_i(my_did_i)
         ,.my_cord_i(cord_li)
  
         ,.coh_lce_req_link_i(lce_req_link_li[i])
         ,.coh_lce_req_link_o(lce_req_link_lo[i])
  
         ,.coh_lce_cmd_link_i(lce_cmd_link_li[i])
         ,.coh_lce_cmd_link_o(lce_cmd_link_lo[i])
  
         ,.io_cmd_link_i(io_cmd_link_li[i])
         ,.io_cmd_link_o(io_cmd_link_lo[i])
  
         ,.io_resp_link_i(io_resp_link_li[i])
         ,.io_resp_link_o(io_resp_link_lo[i])
         );
    end
  
  assign lce_req_ver_link_li[N] = '0;
  assign lce_req_ver_link_li[S] = coh_req_link_i;
  assign lce_req_hor_link_li    = '0;
  bsg_mesh_stitch
   #(.width_p(coh_noc_ral_link_width_lp)
     ,.x_max_p(ic_x_dim_p)
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
  assign coh_req_link_o = lce_req_ver_link_lo[S];

  assign lce_cmd_ver_link_li[N] = '0;
  assign lce_cmd_ver_link_li[S] = coh_cmd_link_i;
  assign lce_cmd_hor_link_li    = '0;
  bsg_mesh_stitch
   #(.width_p(coh_noc_ral_link_width_lp)
     ,.x_max_p(ic_x_dim_p)
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
  assign coh_cmd_link_o = lce_cmd_ver_link_lo[S];

  bp_io_ready_and_link_s [ic_x_dim_p-1:0][S:W] io_cmd_mesh_lo, io_cmd_mesh_li;
  for (genvar i = 0; i < ic_x_dim_p; i++)
    begin : cmd_link
      assign io_cmd_mesh_lo[i][E:W] = io_cmd_link_lo[i][E:W];
      assign io_cmd_link_li[i][E:W] = io_cmd_mesh_li[i][E:W];
    end
  assign io_cmd_hor_link_li = io_cmd_link_i;
  bsg_mesh_stitch
   #(.width_p(io_noc_ral_link_width_lp)
     ,.x_max_p(ic_x_dim_p)
     ,.y_max_p(1)
     )
   cmd_mesh
    (.outs_i(io_cmd_mesh_lo)
     ,.ins_o(io_cmd_mesh_li)

     ,.hor_i(io_cmd_hor_link_li)
     ,.hor_o(io_cmd_hor_link_lo)
     ,.ver_i()
     ,.ver_o()
     );
  assign io_cmd_link_o  = io_cmd_hor_link_lo;

  bp_io_ready_and_link_s [ic_x_dim_p-1:0][S:W] io_resp_mesh_lo, io_resp_mesh_li;
  for (genvar i = 0; i < ic_x_dim_p; i++)
    begin : resp_link
      assign io_resp_mesh_lo[i][E:W] = io_resp_link_lo[i][E:W];
      assign io_resp_link_li[i][E:W] = io_resp_mesh_li[i][E:W];
    end
  assign io_resp_hor_link_li = io_resp_link_i;
  bsg_mesh_stitch
   #(.width_p(io_noc_ral_link_width_lp)
     ,.x_max_p(ic_x_dim_p)
     ,.y_max_p(ic_y_dim_p)
     )
   resp_mesh
    (.outs_i(io_resp_mesh_lo)
     ,.ins_o(io_resp_mesh_li)

     ,.hor_i(io_resp_hor_link_li)
     ,.hor_o(io_resp_hor_link_lo)
     ,.ver_i()
     ,.ver_o()
     );
  assign io_resp_link_o = io_resp_hor_link_lo;

endmodule


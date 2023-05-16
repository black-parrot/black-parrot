
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_io_complex
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                          core_clk_i
   , input                                                        core_reset_i

   , input                                                        coh_clk_i
   , input                                                        coh_reset_i

   , input                                                        mem_clk_i
   , input                                                        mem_reset_i

   , input [mem_noc_did_width_p-1:0]                               my_did_i
   , input [mem_noc_did_width_p-1:0]                               host_did_i

   , input [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]        coh_req_link_i
   , output logic [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_req_link_o

   , input [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]        coh_cmd_link_i
   , output logic [ic_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_cmd_link_o

   , input [E:W][mem_noc_ral_link_width_lp-1:0]                    mem_fwd_link_i
   , output logic [E:W][mem_noc_ral_link_width_lp-1:0]             mem_fwd_link_o

   , input [E:W][mem_noc_ral_link_width_lp-1:0]                    mem_rev_link_i
   , output logic [E:W][mem_noc_ral_link_width_lp-1:0]             mem_rev_link_o
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  bp_mem_ready_and_link_s [ic_x_dim_p-1:0][E:W]  mem_fwd_link_li, mem_fwd_link_lo, mem_rev_link_li, mem_rev_link_lo;
  bp_mem_ready_and_link_s [E:W] mem_fwd_hor_link_li, mem_fwd_hor_link_lo, mem_rev_hor_link_li, mem_rev_hor_link_lo;
  bp_coh_ready_and_link_s [ic_x_dim_p-1:0][S:W] lce_req_link_li, lce_req_link_lo, lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [S:N][ic_x_dim_p-1:0] lce_req_ver_link_li, lce_req_ver_link_lo, lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
  bp_coh_ready_and_link_s [E:W] lce_req_hor_link_li, lce_req_hor_link_lo, lce_cmd_hor_link_li, lce_cmd_hor_link_lo;

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

         ,.mem_clk_i(mem_clk_i)
         ,.mem_reset_i(mem_reset_i)

         ,.host_did_i(host_did_i)
         ,.my_did_i(my_did_i)
         ,.my_cord_i(cord_li)

         ,.coh_lce_req_link_i(lce_req_link_li[i])
         ,.coh_lce_req_link_o(lce_req_link_lo[i])

         ,.coh_lce_cmd_link_i(lce_cmd_link_li[i])
         ,.coh_lce_cmd_link_o(lce_cmd_link_lo[i])

         ,.mem_fwd_link_i(mem_fwd_link_li[i])
         ,.mem_fwd_link_o(mem_fwd_link_lo[i])

         ,.mem_rev_link_i(mem_rev_link_li[i])
         ,.mem_rev_link_o(mem_rev_link_lo[i])
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

  bp_mem_ready_and_link_s [ic_x_dim_p-1:0][S:W] mem_fwd_mesh_lo, mem_fwd_mesh_li;
  for (genvar i = 0; i < ic_x_dim_p; i++)
    begin : cmd_link
      assign mem_fwd_mesh_lo[i][E:W] = mem_fwd_link_lo[i][E:W];
      assign mem_fwd_link_li[i][E:W] = mem_fwd_mesh_li[i][E:W];
    end
  assign mem_fwd_hor_link_li = mem_fwd_link_i;
  bsg_mesh_stitch
   #(.width_p(mem_noc_ral_link_width_lp)
     ,.x_max_p(ic_x_dim_p)
     ,.y_max_p(1)
     )
   fwd_mesh
    (.outs_i(mem_fwd_mesh_lo)
     ,.ins_o(mem_fwd_mesh_li)

     ,.hor_i(mem_fwd_hor_link_li)
     ,.hor_o(mem_fwd_hor_link_lo)
     ,.ver_i()
     ,.ver_o()
     );
  assign mem_fwd_link_o  = mem_fwd_hor_link_lo;

  bp_mem_ready_and_link_s [ic_x_dim_p-1:0][S:W] mem_rev_mesh_lo, mem_rev_mesh_li;
  for (genvar i = 0; i < ic_x_dim_p; i++)
    begin : resp_link
      assign mem_rev_mesh_lo[i][E:W] = mem_rev_link_lo[i][E:W];
      assign mem_rev_link_li[i][E:W] = mem_rev_mesh_li[i][E:W];
    end
  assign mem_rev_hor_link_li = mem_rev_link_i;
  bsg_mesh_stitch
   #(.width_p(mem_noc_ral_link_width_lp)
     ,.x_max_p(ic_x_dim_p)
     ,.y_max_p(ic_y_dim_p)
     )
   rev_mesh
    (.outs_i(mem_rev_mesh_lo)
     ,.ins_o(mem_rev_mesh_li)

     ,.hor_i(mem_rev_hor_link_li)
     ,.hor_o(mem_rev_hor_link_lo)
     ,.ver_i()
     ,.ver_o()
     );
  assign mem_rev_link_o = mem_rev_hor_link_lo;

endmodule


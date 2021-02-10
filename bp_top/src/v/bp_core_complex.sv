/**
 *
 * bp_core_complex.v
 *
 */

`include "bsg_noc_links.vh"

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_core_complex
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   )
  (input                                                         core_clk_i
   , input                                                       core_reset_i

   , input                                                       coh_clk_i
   , input                                                       coh_reset_i

   , input                                                       mem_clk_i
   , input                                                       mem_reset_i

   , input [io_noc_did_width_p-1:0]                              my_did_i
   , input [io_noc_did_width_p-1:0]                              host_did_i

   , input [E:W][cc_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_hor_link_i
   , output [E:W][cc_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_req_hor_link_o

   , input [E:W][cc_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_hor_link_i
   , output [E:W][cc_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_cmd_hor_link_o

   , input [E:W][cc_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_hor_link_i
   , output [E:W][cc_y_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_resp_hor_link_o

   , input [S:N][cc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_ver_link_i
   , output [S:N][cc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_req_ver_link_o

   , input [S:N][cc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_ver_link_i
   , output [S:N][cc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_cmd_ver_link_o

   , input [S:N][cc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_ver_link_i
   , output [S:N][cc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_resp_ver_link_o

   , input [N:N][cc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_ver_link_i
   , output [S:S][cc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0] mem_cmd_ver_link_o

   , input [S:S][cc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_ver_link_i
   , output [N:N][cc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0] mem_resp_ver_link_o
   );

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, coh_noc_ral_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

  coh_noc_ral_link_s [cc_y_dim_p-1:0][cc_x_dim_p-1:0][S:W] lce_req_link_lo, lce_req_link_li;
  coh_noc_ral_link_s [cc_y_dim_p-1:0][cc_x_dim_p-1:0][S:W] lce_cmd_link_lo, lce_cmd_link_li;
  coh_noc_ral_link_s [cc_y_dim_p-1:0][cc_x_dim_p-1:0][S:W] lce_resp_link_lo, lce_resp_link_li;

  mem_noc_ral_link_s [cc_y_dim_p-1:0][cc_x_dim_p-1:0][S:S] mem_cmd_link_lo, mem_resp_link_li;
  mem_noc_ral_link_s [cc_y_dim_p-1:0][cc_x_dim_p-1:0][N:N] mem_resp_link_lo, mem_cmd_link_li;

  coh_noc_ral_link_s [E:W][cc_y_dim_p-1:0] lce_req_hor_link_li, lce_req_hor_link_lo;
  coh_noc_ral_link_s [S:N][cc_x_dim_p-1:0] lce_req_ver_link_li, lce_req_ver_link_lo;
  coh_noc_ral_link_s [E:W][cc_y_dim_p-1:0] lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
  coh_noc_ral_link_s [S:N][cc_x_dim_p-1:0] lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
  coh_noc_ral_link_s [E:W][cc_y_dim_p-1:0] lce_resp_hor_link_li, lce_resp_hor_link_lo;
  coh_noc_ral_link_s [S:N][cc_x_dim_p-1:0] lce_resp_ver_link_li, lce_resp_ver_link_lo;

  mem_noc_ral_link_s [S:N][cc_x_dim_p-1:0] mem_ver_link_lo, mem_ver_link_li;

  for (genvar j = 0; j < cc_y_dim_p; j++)
    begin : y
      for (genvar i = 0; i < cc_x_dim_p; i++)
        begin : x
          wire [coh_noc_cord_width_p-1:0] cord_li = {coh_noc_y_cord_width_p'(ic_y_dim_p+j)
                                                     ,coh_noc_x_cord_width_p'(sac_x_dim_p+i)
                                                     };
          bp_tile_node
           #(.bp_params_p(bp_params_p))
           tile_node
            (.core_clk_i(core_clk_i)
             ,.core_reset_i(core_reset_i)

             ,.coh_clk_i(coh_clk_i)
             ,.coh_reset_i(coh_reset_i)

             ,.mem_clk_i(mem_clk_i)
             ,.mem_reset_i(mem_reset_i)

             ,.my_did_i(my_did_i)
             ,.host_did_i(host_did_i)
             ,.my_cord_i(cord_li)

             ,.coh_lce_req_link_i(lce_req_link_li[j][i])
             ,.coh_lce_resp_link_i(lce_resp_link_li[j][i])
             ,.coh_lce_cmd_link_i(lce_cmd_link_li[j][i])

             ,.coh_lce_req_link_o(lce_req_link_lo[j][i])
             ,.coh_lce_resp_link_o(lce_resp_link_lo[j][i])
             ,.coh_lce_cmd_link_o(lce_cmd_link_lo[j][i])

             ,.mem_cmd_link_i(mem_cmd_link_li[j][i])
             ,.mem_cmd_link_o(mem_cmd_link_lo[j][i])

             ,.mem_resp_link_i(mem_resp_link_li[j][i])
             ,.mem_resp_link_o(mem_resp_link_lo[j][i])
             );
        end
    end

    assign lce_req_hor_link_li = coh_req_hor_link_i;
    assign lce_req_ver_link_li = coh_req_ver_link_i;
    bsg_mesh_stitch
     #(.width_p($bits(coh_noc_ral_link_s))
       ,.x_max_p(cc_x_dim_p)
       ,.y_max_p(cc_y_dim_p)
       )
     coh_req_mesh
      (.outs_i(lce_req_link_lo)
       ,.ins_o(lce_req_link_li)

       ,.hor_i(lce_req_hor_link_li)
       ,.hor_o(lce_req_hor_link_lo)
       ,.ver_i(lce_req_ver_link_li)
       ,.ver_o(lce_req_ver_link_lo)
       );
    assign coh_req_hor_link_o = lce_req_hor_link_lo;
    assign coh_req_ver_link_o = lce_req_ver_link_lo;

    assign lce_cmd_hor_link_li = coh_cmd_hor_link_i;
    assign lce_cmd_ver_link_li = coh_cmd_ver_link_i;
    bsg_mesh_stitch
     #(.width_p($bits(coh_noc_ral_link_s))
       ,.x_max_p(cc_x_dim_p)
       ,.y_max_p(cc_y_dim_p)
       )
     coh_cmd_mesh
      (.outs_i(lce_cmd_link_lo)
       ,.ins_o(lce_cmd_link_li)

       ,.hor_i(lce_cmd_hor_link_li)
       ,.hor_o(lce_cmd_hor_link_lo)
       ,.ver_i(lce_cmd_ver_link_li)
       ,.ver_o(lce_cmd_ver_link_lo)
       );
    assign coh_cmd_hor_link_o = lce_cmd_hor_link_lo;
    assign coh_cmd_ver_link_o = lce_cmd_ver_link_lo;

    assign lce_resp_hor_link_li = coh_resp_hor_link_i;
    assign lce_resp_ver_link_li = coh_resp_ver_link_i;
    bsg_mesh_stitch
     #(.width_p($bits(coh_noc_ral_link_s))
       ,.x_max_p(cc_x_dim_p)
       ,.y_max_p(cc_y_dim_p)
       )
     coh_resp_mesh
      (.outs_i(lce_resp_link_lo)
       ,.ins_o(lce_resp_link_li)

       ,.hor_i(lce_resp_hor_link_li)
       ,.hor_o(lce_resp_hor_link_lo)
       ,.ver_i(lce_resp_ver_link_li)
       ,.ver_o(lce_resp_ver_link_lo)
       );
    assign coh_resp_hor_link_o = lce_resp_hor_link_lo;
    assign coh_resp_ver_link_o = lce_resp_ver_link_lo;

    mem_noc_ral_link_s [cc_y_dim_p-1:0][cc_x_dim_p-1:0][S:W] mem_mesh_lo, mem_mesh_li;
    for (genvar i = 0; i < cc_y_dim_p; i++)
      for (genvar j = 0; j < cc_x_dim_p; j++)
        begin : link
          assign mem_mesh_lo[i][j][S] = mem_cmd_link_lo[i][j];
          assign mem_mesh_lo[i][j][N] = mem_resp_link_lo[i][j];

          assign mem_cmd_link_li[i][j] = mem_mesh_li[i][j][N];
          assign mem_resp_link_li[i][j] = mem_mesh_li[i][j][S];
        end
    assign mem_ver_link_li = {mem_resp_ver_link_i, mem_cmd_ver_link_i};
    bsg_mesh_stitch
     #(.width_p($bits(mem_noc_ral_link_s))
       ,.x_max_p(cc_x_dim_p)
       ,.y_max_p(cc_y_dim_p)
       )
     mem_mesh
      (.outs_i(mem_mesh_lo)
       ,.ins_o(mem_mesh_li)

       ,.hor_i()
       ,.hor_o()
       ,.ver_i(mem_ver_link_li)
       ,.ver_o(mem_ver_link_lo)
       );
    assign {mem_cmd_ver_link_o, mem_resp_ver_link_o} = mem_ver_link_lo;

endmodule


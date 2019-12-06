
module bp_io_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                         core_clk_i
   , input                                                       core_reset_i

   , input                                                       coh_clk_i
   , input                                                       coh_reset_i

   , input                                                       mem_clk_i
   , input                                                       mem_reset_i

   , input [mem_noc_did_width_p-1:0]                             my_did_i

   , input [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_i
   , output [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_req_link_o

   , input [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_i
   , output [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0] coh_cmd_link_o

   , input [E:W][mem_noc_ral_link_width_lp-1:0]                  io_cmd_link_i
   , output [E:W][mem_noc_ral_link_width_lp-1:0]                 io_cmd_link_o

   , input [E:W][mem_noc_ral_link_width_lp-1:0]                  io_resp_link_i
   , output [E:W][mem_noc_ral_link_width_lp-1:0]                 io_resp_link_o
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  bp_mem_ready_and_link_s [mem_noc_x_dim_p-1:0][S:W] mem_cmd_link_li, mem_cmd_link_lo, mem_resp_link_li, mem_resp_link_lo;
  bp_mem_ready_and_link_s [S:N][mem_noc_x_dim_p-1:0] mem_cmd_ver_link_li, mem_cmd_ver_link_lo, mem_resp_ver_link_li, mem_resp_ver_link_lo;
  bp_mem_ready_and_link_s [E:W]                      mem_cmd_hor_link_li, mem_cmd_hor_link_lo, mem_resp_hor_link_li, mem_resp_hor_link_lo;
  bp_coh_ready_and_link_s [coh_noc_x_dim_p-1:0][S:W] lce_req_link_li, lce_req_link_lo, lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [S:N][coh_noc_x_dim_p-1:0] lce_req_ver_link_li, lce_req_ver_link_lo, lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
  bp_coh_ready_and_link_s [E:W]                      lce_req_hor_link_li, lce_req_hor_link_lo, lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
  
  for (genvar i = 0; i < mem_noc_x_dim_p; i++)
    begin : node
      wire [mem_noc_cord_width_p-1:0] cord_li = {'0, mem_noc_x_cord_width_p'(i)};
      bp_io_tile_node
       #(.bp_params_p(bp_params_p))
       io
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
  
         ,.io_cmd_link_i(mem_cmd_link_li[i])
         ,.io_cmd_link_o(mem_cmd_link_lo[i])
  
         ,.io_resp_link_i(mem_resp_link_li[i])
         ,.io_resp_link_o(mem_resp_link_lo[i])
         );
    end
  
  assign lce_req_ver_link_li[N] = '0;
  assign lce_req_ver_link_li[S] = coh_req_link_i;
  assign lce_req_hor_link_li    = '0;
  bsg_mesh_stitch
   #(.width_p(coh_noc_ral_link_width_lp)
     ,.x_max_p(coh_noc_x_dim_p)
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
     ,.x_max_p(coh_noc_x_dim_p)
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

  assign mem_cmd_ver_link_li = '0;
  assign mem_cmd_hor_link_li = io_cmd_link_i;
  bsg_mesh_stitch
   #(.width_p(mem_noc_ral_link_width_lp)
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(1)
     )
   cmd_mesh
    (.outs_i(mem_cmd_link_lo)
     ,.ins_o(mem_cmd_link_li)

     ,.hor_i(mem_cmd_hor_link_li)
     ,.hor_o(mem_cmd_hor_link_lo)
     ,.ver_i(mem_cmd_ver_link_li)
     ,.ver_o(mem_cmd_ver_link_lo)
     );
  assign io_cmd_link_o  = mem_cmd_hor_link_lo;

  assign mem_resp_ver_link_li = '0;
  assign mem_resp_hor_link_li = io_resp_link_i;
  bsg_mesh_stitch
   #(.width_p(mem_noc_ral_link_width_lp)
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(1)
     )
   resp_mesh
    (.outs_i(mem_resp_link_lo)
     ,.ins_o(mem_resp_link_li)

     ,.hor_i(mem_resp_hor_link_li)
     ,.hor_o(mem_resp_hor_link_lo)
     ,.ver_i(mem_resp_ver_link_li)
     ,.ver_o(mem_resp_ver_link_lo)
     );
  assign io_resp_link_o = mem_resp_hor_link_lo;

endmodule


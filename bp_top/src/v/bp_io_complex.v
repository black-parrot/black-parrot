
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

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                               core_clk_i
   , input                                                             core_reset_i

   , input                                                             mem_clk_i
   , input                                                             mem_reset_i

   , input [mem_noc_did_width_p-1:0]                                   my_did_i

   , input [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  mem_cmd_link_i
   , output [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] mem_cmd_link_o

   , input [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  mem_resp_link_i
   , output [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] mem_resp_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]                       prev_cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]                      prev_cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]                       prev_resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]                      prev_resp_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]                       next_cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]                      next_cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]                       next_resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]                      next_resp_link_o
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s [mem_noc_x_dim_p-1:0][S:W] cmd_link_li, cmd_link_lo, resp_link_li, resp_link_lo;
bsg_ready_and_link_sif_s [S:N][mem_noc_x_dim_p-1:0] cmd_ver_link_li, cmd_ver_link_lo, resp_ver_link_li, resp_ver_link_lo;
bsg_ready_and_link_sif_s [E:W]                      cmd_hor_link_li, cmd_hor_link_lo, resp_hor_link_li, resp_hor_link_lo;

for (genvar i = 0; i < mem_noc_x_dim_p; i++)
  begin : node
    wire [mem_noc_cord_width_p-1:0] cord_li = {'0, mem_noc_x_cord_width_p'(i)};
    wire [E:W][bsg_ready_and_link_sif_width_lp-1:0] off_cmd_link_li = {next_cmd_link_i, prev_cmd_link_i};
    wire [E:W][bsg_ready_and_link_sif_width_lp-1:0] off_resp_link_li = {next_resp_link_i, prev_resp_link_i};
    bp_remote_domain_proxy_node
     #(.bp_params_p(bp_params_p))
     rdp
      (.clk_i(mem_clk_i)
       ,.reset_i(mem_reset_i)

       ,.my_did_i(my_did_i)
       ,.my_cord_i(cord_li)

       ,.on_cmd_link_i(cmd_link_li[i][S])
       ,.on_cmd_link_o(cmd_link_lo[i][S])

       ,.on_resp_link_i(resp_link_li[i][S])
       ,.on_resp_link_o(resp_link_lo[i][S])

       ,.off_cmd_link_i(cmd_link_li[i][E:W])
       ,.off_cmd_link_o(cmd_link_lo[i][E:W])

       ,.off_resp_link_i(resp_link_li[i][E:W])
       ,.off_resp_link_o(resp_link_lo[i][E:W])
       );
  end

  assign cmd_ver_link_li[N] = '0;
  assign cmd_ver_link_li[S] = mem_cmd_link_i;
  assign cmd_hor_link_li[E] = next_cmd_link_i;
  assign cmd_hor_link_li[W] = prev_cmd_link_i;
  bsg_mesh_stitch
   #(.width_p(bsg_ready_and_link_sif_width_lp)
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(1)
     )
   cmd_mesh
    (.outs_i(cmd_link_lo)
     ,.ins_o(cmd_link_li)

     ,.hor_i(cmd_hor_link_li)
     ,.hor_o(cmd_hor_link_lo)
     ,.ver_i(cmd_ver_link_li)
     ,.ver_o(cmd_ver_link_lo)
     );
  assign mem_cmd_link_o  = cmd_ver_link_lo[S];
  assign prev_cmd_link_o = cmd_hor_link_lo[W];
  assign next_cmd_link_o = cmd_hor_link_lo[E];

  assign resp_ver_link_li[N] = '0;
  assign resp_ver_link_li[S] = mem_resp_link_i;
  assign resp_hor_link_li[E] = next_resp_link_i;
  assign resp_hor_link_li[W] = prev_resp_link_i;
  bsg_mesh_stitch
   #(.width_p(bsg_ready_and_link_sif_width_lp)
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(1)
     )
   resp_mesh
    (.outs_i(resp_link_lo)
     ,.ins_o(resp_link_li)

     ,.hor_i(resp_hor_link_li)
     ,.hor_o(resp_hor_link_lo)
     ,.ver_i(resp_ver_link_li)
     ,.ver_o(resp_ver_link_lo)
     );
  assign mem_resp_link_o  = resp_ver_link_lo[S];
  assign prev_resp_link_o = resp_hor_link_lo[W];
  assign next_resp_link_o = resp_hor_link_lo[E];

endmodule


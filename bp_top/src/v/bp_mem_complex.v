
module bp_mem_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                               core_clk_i
   , input                                                             core_reset_i

   , input                                                             mem_clk_i
   , input                                                             mem_reset_i

   , input [num_mem_p-1:0][mem_noc_cord_width_p-1:0]                   mem_cord_i

   , input [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  mem_cmd_link_i
   , output [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] mem_cmd_link_o

   , input [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  mem_resp_link_i
   , output [mem_noc_x_dim_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] mem_resp_link_o

   // TODO DMC channels
   //, input [num_mem_p-1:0]   ....
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s [num_mem_p-1:0][S:W] cmd_link_li, cmd_link_lo, resp_link_li, resp_link_lo;
bsg_ready_and_link_sif_s [S:N][num_mem_p-1:0] cmd_ver_link_li, cmd_ver_link_lo, resp_ver_link_li, resp_ver_link_lo;
bsg_ready_and_link_sif_s [E:W]                cmd_hor_link_li, cmd_hor_link_lo, resp_hor_link_li, resp_hor_link_lo;

// bp_io_complex is laid out like this:
//   [io] [0:cores/2-1] [mmio_node] [cores/2:cores-1] [io]
// Note: for single core, there is no router on between mmio_node[E] and io[W]

for (genvar i = 0; i < num_mem_p; i++)
  begin : vcache
    bp_vcache_node
     #(.bp_params_p(bp_params_p))
     vcache
      (.core_clk_i(core_clk_i)
       ,.core_reset_i(core_reset_i)

       ,.mem_clk_i(mem_clk_i)
       ,.mem_reset_i(mem_reset_i)

       ,.my_cord_i(mem_cord_i[i])

       ,.mem_cmd_link_i(cmd_link_li[i])
       ,.mem_cmd_link_o(cmd_link_lo[i])

       ,.mem_resp_link_i(resp_link_li[i])
       ,.mem_resp_link_o(resp_link_lo[i])

       // TOOD: Add DMC link[i]
       );
  end

  assign cmd_ver_link_li[N] = mem_cmd_link_i;
  assign cmd_ver_link_li[S] = '0;
  assign cmd_hor_link_li    = '0;
  bsg_mesh_stitch
   #(.width_p(bsg_ready_and_link_sif_width_lp)
     ,.x_max_p(num_mem_p)
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
  assign mem_cmd_link_o  = cmd_ver_link_lo[N];

  assign resp_ver_link_li[N] = mem_resp_link_i;
  assign resp_ver_link_li[S] = '0;
  assign resp_hor_link_li    = '0;
  bsg_mesh_stitch
   #(.width_p(bsg_ready_and_link_sif_width_lp)
     ,.x_max_p(num_mem_p)
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
  assign mem_resp_link_o  = resp_ver_link_lo[N];

endmodule


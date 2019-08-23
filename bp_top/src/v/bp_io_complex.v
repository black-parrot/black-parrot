
module bp_io_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                          clk_i
   , input                                                        reset_i

   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0]             tile_cord_i

   , input [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] resp_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]                  io_cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]                 io_cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]                  io_resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]                 io_resp_link_o
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s [mem_noc_y_dim_p-1:0][mem_noc_x_dim_p-1:0][S:W] 
  cmd_link_li, cmd_link_lo, resp_link_li, resp_link_lo;
bsg_ready_and_link_sif_s [S:N][mem_noc_x_dim_p-1:0]
  cmd_ver_link_li, cmd_ver_link_lo, resp_ver_link_li, resp_ver_link_lo;
bsg_ready_and_link_sif_s [E:W][mem_noc_y_dim_p-1:0]
  cmd_hor_link_li, cmd_hor_link_lo, resp_hor_link_li, resp_hor_link_lo;

for (genvar j = 0; j < mem_noc_y_dim_p; j++)
  begin : y
    for (genvar i = 0; i < mem_noc_x_dim_p; i++)
      begin : x
         if (i == 0)
           begin : hor_links
             assign cmd_hor_link_li[W][j]  = '0;
             assign cmd_hor_link_li[E][j]  = (j == 0) ? io_cmd_link_i  : '0;

             assign resp_hor_link_li[W][j] = '0;
             assign resp_hor_link_li[E][j] = (j == 0) ? io_resp_link_i : '0;
           end
        
        bsg_wormhole_router
         #(.flit_width_p(mem_noc_flit_width_p)
           ,.dims_p(mem_noc_dims_p)
           ,.cord_dims_p(mem_noc_max_dims_p)
           ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
           ,.len_width_p(mem_noc_len_width_p)
           ,.reverse_order_p((j > 0))
           ,.routing_matrix_p((mem_noc_dims_p == 1) 
                              ? StrictX 
                              : (j == 0) 
                                ? StrictXY | XY_Allow_S
                                : StrictYX
                              )
           )
         cmd_router 
         (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.my_cord_i(tile_cord_i[j*mem_noc_x_dim_p+i])
          ,.link_i({cmd_link_li[j][i][mem_noc_dirs_p-1:W], cmd_link_i[j*mem_noc_x_dim_p+i]})
          ,.link_o({cmd_link_lo[j][i][mem_noc_dirs_p-1:W], cmd_link_o[j*mem_noc_x_dim_p+i]})
          );
        
        bsg_wormhole_router
         #(.flit_width_p(mem_noc_flit_width_p)
           ,.dims_p(mem_noc_dims_p)
           ,.cord_dims_p(mem_noc_max_dims_p)
           ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
           ,.len_width_p(mem_noc_len_width_p)
           ,.reverse_order_p((j > 0))
           ,.routing_matrix_p((mem_noc_dims_p == 1) 
                              ? StrictX 
                              : (j == 0) 
                                ? StrictXY | XY_Allow_S
                                : StrictYX
                              )
           )
         resp_router 
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.my_cord_i(tile_cord_i[j*mem_noc_x_dim_p+i])
           ,.link_i({resp_link_li[j][i][mem_noc_dirs_p-1:W], resp_link_i[j*mem_noc_x_dim_p+i]})
           ,.link_o({resp_link_lo[j][i][mem_noc_dirs_p-1:W], resp_link_o[j*mem_noc_x_dim_p+i]})
           );
      end
  end

  assign cmd_ver_link_li  = '0;
  bsg_mesh_stitch
   #(.width_p(bsg_ready_and_link_sif_width_lp)
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(mem_noc_y_dim_p)
     )
   cmd_mesh
    (.outs_i(cmd_link_lo)
     ,.ins_o(cmd_link_li)

     ,.hor_i(cmd_hor_link_li)
     ,.hor_o(cmd_hor_link_lo)
     ,.ver_i(cmd_ver_link_li)
     ,.ver_o(cmd_ver_link_lo)
     );
  assign io_cmd_link_o = cmd_hor_link_lo[E][0];

  assign resp_ver_link_li = '0;
  bsg_mesh_stitch
   #(.width_p(bsg_ready_and_link_sif_width_lp)
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(mem_noc_y_dim_p)
     )
   resp_mesh
    (.outs_i(resp_link_lo)
     ,.ins_o(resp_link_li)

     ,.hor_i(resp_hor_link_li)
     ,.hor_o(resp_hor_link_lo)
     ,.ver_i(resp_ver_link_li)
     ,.ver_o(resp_ver_link_lo)
     );
  assign io_resp_link_o = resp_hor_link_lo[E][0];

endmodule


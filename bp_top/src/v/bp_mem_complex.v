
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

   , output [num_core_p-1:0]                                           soft_irq_o
   , output [num_core_p-1:0]                                           timer_irq_o
   , output [num_core_p-1:0]                                           external_irq_o

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
bsg_ready_and_link_sif_s [num_mem_p-1:0][S:W] cmd_link_li, cmd_link_lo, resp_link_li, resp_link_lo;
bsg_ready_and_link_sif_s [S:N][num_mem_p-1:0] cmd_ver_link_li, cmd_ver_link_lo, resp_ver_link_li, resp_ver_link_lo;
bsg_ready_and_link_sif_s [E:W]                cmd_hor_link_li, cmd_hor_link_lo, resp_hor_link_li, resp_hor_link_lo;

// bp_mem_complex is laid out like this:
//   [io] [0:cores/2-1] [mmio_node] [cores/2:cores-1] [io]
// Note: for single core, there is no router on between mmio_node[E] and io[W]

for (genvar i = 0; i < num_mem_p; i++)
  begin : node
    if (i == clint_x_pos_p)
      begin : clint
        bp_clint_node
         #(.bp_params_p(bp_params_p))
         clint
          (.core_clk_i(core_clk_i)
           ,.core_reset_i(core_reset_i)

           ,.mem_clk_i(mem_clk_i)
           ,.mem_reset_i(mem_reset_i)

           ,.my_cord_i(mem_cord_i[i])
           ,.my_cid_i('0)

           ,.soft_irq_o(soft_irq_o)
           ,.timer_irq_o(timer_irq_o)
           ,.external_irq_o(external_irq_o)

           ,.mem_cmd_link_i(cmd_link_li[i])
           ,.mem_cmd_link_o(cmd_link_lo[i])

           ,.mem_resp_link_i(resp_link_li[i])
           ,.mem_resp_link_o(resp_link_lo[i])
           );
      end
    else
      begin : mem
        bsg_ready_and_link_sif_s rtr_cmd_link_li, rtr_cmd_link_lo;
        bsg_ready_and_link_sif_s rtr_resp_link_li, rtr_resp_link_lo;

        assign rtr_cmd_link_li = '0;
        bsg_wormhole_router
         #(.flit_width_p(mem_noc_flit_width_p)
           ,.dims_p(mem_noc_dims_p)
           ,.cord_dims_p(mem_noc_dims_p)
           ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
           ,.len_width_p(mem_noc_len_width_p)
           ,.reverse_order_p(0)
           ,.routing_matrix_p(StrictXY | XY_Allow_S)
           )
         cmd_router 
         (.clk_i(mem_clk_i)
          ,.reset_i(mem_reset_i)
          ,.my_cord_i(mem_cord_i[i])
          ,.link_i({cmd_link_li[i], rtr_cmd_link_li})
          ,.link_o({cmd_link_lo[i], rtr_cmd_link_lo})
          );
        
        assign rtr_resp_link_li = '0;
        bsg_wormhole_router
         #(.flit_width_p(mem_noc_flit_width_p)
           ,.dims_p(mem_noc_dims_p)
           ,.cord_dims_p(mem_noc_dims_p)
           ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
           ,.len_width_p(mem_noc_len_width_p)
           ,.reverse_order_p(0)
           ,.routing_matrix_p(StrictXY | XY_Allow_S)
           )
         resp_router 
          (.clk_i(mem_clk_i)
           ,.reset_i(mem_reset_i)
           ,.my_cord_i(mem_cord_i[i])
           ,.link_i({resp_link_li[i], rtr_resp_link_li})
           ,.link_o({resp_link_lo[i], rtr_resp_link_lo})
           );
      end
  end

  assign cmd_ver_link_li[N] = '0;
  assign cmd_ver_link_li[S] = {bsg_ready_and_link_sif_width_lp'('0), mem_cmd_link_i, bsg_ready_and_link_sif_width_lp'('0)};
  assign cmd_hor_link_li[W] = prev_cmd_link_i;
  assign cmd_hor_link_li[E] = next_cmd_link_i;
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
  assign mem_cmd_link_o  = cmd_ver_link_lo[S][num_mem_p-1:1];
  assign prev_cmd_link_o = cmd_hor_link_lo[W];
  assign next_cmd_link_o = cmd_hor_link_lo[E];

  assign resp_ver_link_li[N] = '0;
  assign resp_ver_link_li[S] = {bsg_ready_and_link_sif_width_lp'('0), mem_resp_link_i, bsg_ready_and_link_sif_width_lp'('0)};
  assign resp_hor_link_li[W] = prev_resp_link_i;
  assign resp_hor_link_li[E] = next_resp_link_i;
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
  assign mem_resp_link_o  = resp_ver_link_lo[S][num_mem_p-1:1];
  assign prev_resp_link_o = resp_hor_link_lo[W];
  assign next_resp_link_o = resp_hor_link_lo[E];

endmodule



`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_l2e_tile_node
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam dma_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(dma_noc_flit_width_p)
   )
  (input                                               core_clk_i
   , input                                             core_reset_i

   , input                                             coh_clk_i
   , input                                             coh_reset_i

   , input                                             dma_clk_i
   , input                                             dma_reset_i

   , input [mem_noc_did_width_p-1:0]                   my_did_i
   , input [coh_noc_cord_width_p-1:0]                  my_cord_i

   , input [S:W][coh_noc_ral_link_width_lp-1:0]        coh_lce_req_link_i
   , output logic [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_req_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]        coh_lce_cmd_link_i
   , output logic [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_cmd_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]        coh_lce_resp_link_i
   , output logic [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_resp_link_o

   , input [S:N][dma_noc_ral_link_width_lp-1:0]        dma_link_i
   , output logic [S:N][dma_noc_ral_link_width_lp-1:0] dma_link_o
   );

  // Declare the routing links
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(dma_noc_flit_width_p, bp_dma_ready_and_link_s);

  // Tile-side coherence connections
  bp_coh_ready_and_link_s l2e_lce_req_link_li, l2e_lce_req_link_lo;
  bp_coh_ready_and_link_s l2e_lce_cmd_link_li, l2e_lce_cmd_link_lo;
  bp_coh_ready_and_link_s l2e_lce_resp_link_li, l2e_lce_resp_link_lo;

  // Tile side membus connections
  bp_dma_ready_and_link_s l2e_dma_link_lo, l2e_dma_link_li;

  bp_l2e_tile
   #(.bp_params_p(bp_params_p))
   l2e_tile
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)

     ,.my_did_i(my_did_i)
     ,.my_cord_i(my_cord_i)

     ,.lce_req_link_i(l2e_lce_req_link_li)
     ,.lce_req_link_o(l2e_lce_req_link_lo)

     ,.lce_cmd_link_i(l2e_lce_cmd_link_li)
     ,.lce_cmd_link_o(l2e_lce_cmd_link_lo)

     ,.lce_resp_link_i(l2e_lce_resp_link_li)
     ,.lce_resp_link_o(l2e_lce_resp_link_lo)

     ,.dma_link_o(l2e_dma_link_lo)
     ,.dma_link_i(l2e_dma_link_li)
     );

  bp_nd_socket
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.routing_matrix_p(StrictYX)
     ,.async_clk_p(async_coh_clk_p)
     ,.els_p(3)
     )
   l2e_coh_socket
    (.tile_clk_i(core_clk_i)
     ,.tile_reset_i(core_reset_i)
     ,.network_clk_i(coh_clk_i)
     ,.network_reset_i(coh_reset_i)
     ,.my_cord_i(my_cord_i)
     ,.network_link_i({coh_lce_req_link_i, coh_lce_cmd_link_i, coh_lce_resp_link_i})
     ,.network_link_o({coh_lce_req_link_o, coh_lce_cmd_link_o, coh_lce_resp_link_o})
     ,.tile_link_i({l2e_lce_req_link_lo, l2e_lce_cmd_link_lo, l2e_lce_resp_link_lo})
     ,.tile_link_o({l2e_lce_req_link_li, l2e_lce_cmd_link_li, l2e_lce_resp_link_li})
     );

 bp_nd_socket
   #(.flit_width_p(dma_noc_flit_width_p)
     ,.dims_p(dma_noc_dims_p)
     ,.cord_dims_p(dma_noc_cord_dims_p)
     ,.cord_markers_pos_p(dma_noc_cord_markers_pos_p)
     ,.len_width_p(dma_noc_len_width_p)
     ,.routing_matrix_p(StrictX)
     ,.async_clk_p(async_dma_clk_p)
     ,.els_p(1)
     )
   l2e_mem_socket
    (.tile_clk_i(core_clk_i)
     ,.tile_reset_i(core_reset_i)
     ,.network_clk_i(dma_clk_i)
     ,.network_reset_i(dma_reset_i)
     ,.my_cord_i(my_cord_i[coh_noc_x_cord_width_p+:dma_noc_y_cord_width_p])
     ,.network_link_i(dma_link_i)
     ,.network_link_o(dma_link_o)
     ,.tile_link_i(l2e_dma_link_lo)
     ,.tile_link_o(l2e_dma_link_li)
     );

endmodule


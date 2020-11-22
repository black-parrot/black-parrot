module bp_io_tile_node
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam io_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   )
  (input                                         core_clk_i
   , input                                       core_reset_i

   , input                                       coh_clk_i
   , input                                       coh_reset_i

   , input                                       io_clk_i
   , input                                       io_reset_i

   , input [io_noc_did_width_p-1:0]              my_did_i
   , input [io_noc_did_width_p-1:0]              host_did_i
   , input [coh_noc_cord_width_p-1:0]            my_cord_i

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_req_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_req_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_cmd_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_cmd_link_o

   , input [E:W][io_noc_ral_link_width_lp-1:0]   io_cmd_link_i
   , output [E:W][io_noc_ral_link_width_lp-1:0]  io_cmd_link_o

   , input [E:W][io_noc_ral_link_width_lp-1:0]   io_resp_link_i
   , output [E:W][io_noc_ral_link_width_lp-1:0]  io_resp_link_o
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_ready_and_link_s);
  
  // Tile-side coherence connections
  bp_coh_ready_and_link_s core_lce_req_link_li, core_lce_req_link_lo;
  bp_coh_ready_and_link_s core_lce_cmd_link_li, core_lce_cmd_link_lo;
  
  // Tile side IO connections
  bp_io_ready_and_link_s core_io_cmd_link_li, core_io_cmd_link_lo;
  bp_io_ready_and_link_s core_io_resp_link_li, core_io_resp_link_lo;
  
  bp_io_tile
   #(.bp_params_p(bp_params_p))
   io_tile
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)

     ,.host_did_i(host_did_i)
     ,.my_did_i(my_did_i)
     ,.my_cord_i(my_cord_i)

     ,.lce_req_link_i(core_lce_req_link_li)
     ,.lce_req_link_o(core_lce_req_link_lo)

     ,.lce_cmd_link_i(core_lce_cmd_link_li)
     ,.lce_cmd_link_o(core_lce_cmd_link_lo)

     ,.io_cmd_link_i(core_io_cmd_link_li)
     ,.io_cmd_link_o(core_io_cmd_link_lo)

     ,.io_resp_link_i(core_io_resp_link_li)
     ,.io_resp_link_o(core_io_resp_link_lo)
     );

   
  // Network-side coherence connections
//  bp_coh_ready_and_link_s coh_lce_req_link_li, coh_lce_req_link_lo;
 // bp_coh_ready_and_link_s coh_lce_cmd_link_li, coh_lce_cmd_link_lo;

  bp_nd_socket
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.routing_matrix_p(StrictYX)
     ,.async_clk_p(async_coh_clk_p)
     ,.els_p(2)
     )
   io_coh_socket
    (.tile_clk_i(core_clk_i)
     ,.tile_reset_i(core_reset_i)
     ,.network_clk_i(coh_clk_i)
     ,.network_reset_i(coh_reset_i)
     ,.my_cord_i(my_cord_i)
     ,.network_link_i({coh_lce_req_link_i, coh_lce_cmd_link_i})
     ,.network_link_o({coh_lce_req_link_o, coh_lce_cmd_link_o})
     ,.tile_link_i({core_lce_req_link_lo, core_lce_cmd_link_lo})
     ,.tile_link_o({core_lce_req_link_li, core_lce_cmd_link_li})
     );

 bp_nd_socket
   #(.flit_width_p(io_noc_flit_width_p)
     ,.dims_p(io_noc_dims_p)
     ,.cord_dims_p(io_noc_cord_dims_p)
     ,.cord_markers_pos_p(io_noc_cord_markers_pos_p)
     ,.len_width_p(io_noc_len_width_p)
     ,.routing_matrix_p(StrictX)
     ,.async_clk_p(async_io_clk_p)
     ,.els_p(2)
     )
   io_socket
    (.tile_clk_i(core_clk_i)
     ,.tile_reset_i(core_reset_i)
     ,.network_clk_i(io_clk_i)
     ,.network_reset_i(io_reset_i)
     ,.my_cord_i(io_noc_cord_width_p'(my_did_i))
     ,.network_link_i({io_cmd_link_i, io_resp_link_i})
     ,.network_link_o({io_cmd_link_o, io_resp_link_o})
     ,.tile_link_i({core_io_cmd_link_lo, core_io_resp_link_lo})
     ,.tile_link_o({core_io_cmd_link_li, core_io_resp_link_li})
     );
   
endmodule


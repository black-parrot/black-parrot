
module bp_l2e_tile_node
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                         l2e_clk_i
   , input                                       l2e_reset_i

   , input                                       coh_clk_i
   , input                                       coh_reset_i

   , input                                       mem_clk_i
   , input                                       mem_reset_i

   , input [io_noc_did_width_p-1:0]              my_did_i
   , input [mem_noc_cord_width_p-1:0]            my_cord_i

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_req_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_req_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_cmd_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_cmd_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_resp_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_resp_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0] mem_cmd_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0] mem_resp_link_o
   );

  // Declare the routing links
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  // Tile-side coherence connections
  bp_coh_ready_and_link_s l2e_lce_req_link_li, l2e_lce_req_link_lo;
  bp_coh_ready_and_link_s l2e_lce_cmd_link_li, l2e_lce_cmd_link_lo;
  bp_coh_ready_and_link_s l2e_lce_resp_link_li, l2e_lce_resp_link_lo;

  // Tile side membus connections
  bp_mem_ready_and_link_s l2e_mem_cmd_link_li, l2e_mem_cmd_link_lo;
  bp_mem_ready_and_link_s l2e_mem_resp_link_li, l2e_mem_resp_link_lo;

  bp_l2e_tile
   #(.bp_params_p(bp_params_p))
   l2e_tile
    (.clk_i(l2e_clk_i)
     ,.reset_i(l2e_reset_i)

     ,.my_did_i(my_did_i)
     ,.my_cord_i(my_cord_i)

     ,.lce_req_link_i(l2e_lce_req_link_li)
     ,.lce_req_link_o(l2e_lce_req_link_lo)

     ,.lce_cmd_link_i(l2e_lce_cmd_link_li)
     ,.lce_cmd_link_o(l2e_lce_cmd_link_lo)

     ,.lce_resp_link_i(l2e_lce_resp_link_li)
     ,.lce_resp_link_o(l2e_lce_resp_link_lo)

     ,.mem_cmd_link_i(l2e_mem_cmd_link_li)
     ,.mem_cmd_link_o(l2e_mem_cmd_link_lo)

     ,.mem_resp_link_i(l2e_mem_resp_link_li)
     ,.mem_resp_link_o(l2e_mem_resp_link_lo)
     );

  bp_coh_ready_and_link_s coh_lce_req_link_li, coh_lce_req_link_lo;
  bp_coh_ready_and_link_s coh_lce_cmd_link_li, coh_lce_cmd_link_lo;
  bp_coh_ready_and_link_s coh_lce_resp_link_li, coh_lce_resp_link_lo;

  if (async_coh_clk_p == 1)
    begin : coh_async
      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       lce_req_link
        (.aclk_i(l2e_clk_i)
         ,.areset_i(l2e_reset_i)

         ,.bclk_i(coh_clk_i)
         ,.breset_i(coh_reset_i)

         ,.alink_i(l2e_lce_req_link_lo)
         ,.alink_o(l2e_lce_req_link_li)

         ,.blink_i(coh_lce_req_link_li)
         ,.blink_o(coh_lce_req_link_lo)
         );

      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       lce_cmd_link
        (.aclk_i(l2e_clk_i)
         ,.areset_i(l2e_reset_i)

         ,.bclk_i(coh_clk_i)
         ,.breset_i(coh_reset_i)

         ,.alink_i(l2e_lce_cmd_link_lo)
         ,.alink_o(l2e_lce_cmd_link_li)

         ,.blink_i(coh_lce_cmd_link_li)
         ,.blink_o(coh_lce_cmd_link_lo)
         );

      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       lce_resp_link
        (.aclk_i(l2e_clk_i)
         ,.areset_i(l2e_reset_i)

         ,.bclk_i(coh_clk_i)
         ,.breset_i(coh_reset_i)

         ,.alink_i(l2e_lce_resp_link_lo)
         ,.alink_o(l2e_lce_resp_link_li)

         ,.blink_i(coh_lce_resp_link_li)
         ,.blink_o(coh_lce_resp_link_lo)
         );
    end
  else
    begin : coh_sync
      assign coh_lce_req_link_li  = l2e_lce_req_link_lo;
      assign coh_lce_cmd_link_li  = l2e_lce_cmd_link_lo;
      assign coh_lce_resp_link_li = l2e_lce_resp_link_lo;

      assign l2e_lce_req_link_li  = coh_lce_req_link_lo;
      assign l2e_lce_cmd_link_li  = coh_lce_cmd_link_lo;
      assign l2e_lce_resp_link_li = coh_lce_resp_link_lo;
    end

  bp_mem_ready_and_link_s mem_cmd_link_li, mem_cmd_link_lo;
  bp_mem_ready_and_link_s mem_resp_link_li, mem_resp_link_lo;

  if (async_mem_clk_p == 1)
    begin : mem_async
      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       mem_cmd_link
        (.aclk_i(l2e_clk_i)
         ,.areset_i(l2e_reset_i)

         ,.bclk_i(mem_clk_i)
         ,.breset_i(mem_reset_i)

         ,.alink_i(l2e_mem_cmd_link_lo)
         ,.alink_o(l2e_mem_cmd_link_li)

         ,.blink_i(mem_cmd_link_li)
         ,.blink_o(mem_cmd_link_lo)
         );

      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       mem_resp_link
        (.aclk_i(l2e_clk_i)
         ,.areset_i(l2e_reset_i)

         ,.bclk_i(mem_clk_i)
         ,.breset_i(mem_reset_i)

         ,.alink_i(l2e_mem_resp_link_lo)
         ,.alink_o(l2e_mem_resp_link_li)

         ,.blink_i(mem_resp_link_li)
         ,.blink_o(mem_resp_link_lo)
         );
    end
  else
    begin : mem_sync
      assign mem_cmd_link_li  = l2e_mem_cmd_link_lo;
      assign mem_resp_link_li = l2e_mem_resp_link_lo;

      assign l2e_mem_cmd_link_li  = mem_cmd_link_lo;
      assign l2e_mem_resp_link_li = mem_resp_link_lo;
    end

  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   lce_req_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.link_i({coh_lce_req_link_i, coh_lce_req_link_li})
     ,.link_o({coh_lce_req_link_o, coh_lce_req_link_lo})

     ,.my_cord_i(my_cord_i)
     );

  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   lce_cmd_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.link_i({coh_lce_cmd_link_i, coh_lce_cmd_link_li})
     ,.link_o({coh_lce_cmd_link_o, coh_lce_cmd_link_lo})

     ,.my_cord_i(my_cord_i)
     );

  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   lce_resp_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.link_i({coh_lce_resp_link_i, coh_lce_resp_link_li})
     ,.link_o({coh_lce_resp_link_o, coh_lce_resp_link_lo})

     ,.my_cord_i(my_cord_i)
     );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   mem_cmd_router
   (.clk_i(mem_clk_i)
    ,.reset_i(mem_reset_i)
    ,.my_cord_i(my_cord_i)
    ,.link_i({mem_cmd_link_i, mem_cmd_link_li})
    ,.link_o({mem_cmd_link_o, mem_cmd_link_lo})
    );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   mem_resp_router
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)
     ,.my_cord_i(my_cord_i)
     ,.link_i({mem_resp_link_i, mem_resp_link_li})
     ,.link_o({mem_resp_link_o, mem_resp_link_lo})
     );

endmodule


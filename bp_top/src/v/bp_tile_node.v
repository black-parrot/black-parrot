/**
 *
 * bp_tile_node.v
 *
 */

module bp_tile_node
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                         core_clk_i
   , input                                       core_reset_i

   , input                                       coh_clk_i
   , input                                       coh_reset_i

   , input                                       mem_clk_i
   , input                                       mem_reset_i

   // Memory side connection
   , input [io_noc_did_width_p-1:0]              my_did_i
   , input [coh_noc_cord_width_p-1:0]            my_cord_i

   // Connected to other tiles on east and west
   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_req_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_req_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_cmd_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_cmd_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_resp_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_resp_link_o

   , output [S:N][mem_noc_ral_link_width_lp-1:0] mem_cmd_link_o
   , input [S:N][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_i
   );

`declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

// Declare the routing links
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

// Tile-side coherence connections
bp_coh_ready_and_link_s core_lce_req_link_li, core_lce_req_link_lo;
bp_coh_ready_and_link_s core_lce_cmd_link_li, core_lce_cmd_link_lo;
bp_coh_ready_and_link_s core_lce_resp_link_li, core_lce_resp_link_lo;

// Tile side membus connections
bp_mem_ready_and_link_s core_mem_cmd_link_lo, core_mem_resp_link_li;

  bp_tile
   #(.bp_params_p(bp_params_p))
   tile
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)

     // Memory side connection
     ,.my_did_i(my_did_i)
     ,.my_cord_i(my_cord_i)

     ,.lce_req_link_i(core_lce_req_link_li)
     ,.lce_req_link_o(core_lce_req_link_lo)

     ,.lce_cmd_link_i(core_lce_cmd_link_li)
     ,.lce_cmd_link_o(core_lce_cmd_link_lo)

     ,.lce_resp_link_i(core_lce_resp_link_li)
     ,.lce_resp_link_o(core_lce_resp_link_lo)

     ,.mem_cmd_link_o(core_mem_cmd_link_lo)
     ,.mem_resp_link_i(core_mem_resp_link_li)
     );

// Network-side coherence connections
bp_coh_ready_and_link_s coh_lce_req_link_li, coh_lce_req_link_lo;
bp_coh_ready_and_link_s coh_lce_cmd_link_li, coh_lce_cmd_link_lo;
bp_coh_ready_and_link_s coh_lce_resp_link_li, coh_lce_resp_link_lo;

// Network side membus connections
bp_mem_ready_and_link_s mem_cmd_link_lo, mem_resp_link_li;

  if (async_coh_clk_p == 1)
    begin : coh_async
      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       lce_req_cdc
        (.aclk_i(core_clk_i)
         ,.areset_i(core_reset_i)

         ,.bclk_i(coh_clk_i)
         ,.breset_i(coh_reset_i)

         ,.alink_i(core_lce_req_link_lo)
         ,.alink_o(core_lce_req_link_li)

         ,.blink_i(coh_lce_req_link_lo)
         ,.blink_o(coh_lce_req_link_li)
         );

      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       lce_cmd_cdc
        (.aclk_i(core_clk_i)
         ,.areset_i(core_reset_i)

         ,.bclk_i(coh_clk_i)
         ,.breset_i(coh_reset_i)

         ,.alink_i(core_lce_cmd_link_lo)
         ,.alink_o(core_lce_cmd_link_li)

         ,.blink_i(coh_lce_cmd_link_lo)
         ,.blink_o(coh_lce_cmd_link_li)
         );

      bsg_async_noc_link
       #(.width_p(coh_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       lce_resp_cdc
        (.aclk_i(core_clk_i)
         ,.areset_i(core_reset_i)

         ,.bclk_i(coh_clk_i)
         ,.breset_i(coh_reset_i)

         ,.alink_i(core_lce_resp_link_lo)
         ,.alink_o(core_lce_resp_link_li)

         ,.blink_i(coh_lce_resp_link_lo)
         ,.blink_o(coh_lce_resp_link_li)
         );
    end
  else
    begin : coh_sync
      assign coh_lce_req_link_li  = core_lce_req_link_lo;
      assign coh_lce_cmd_link_li  = core_lce_cmd_link_lo;
      assign coh_lce_resp_link_li = core_lce_resp_link_lo;

      assign core_lce_req_link_li  = coh_lce_req_link_lo;
      assign core_lce_cmd_link_li  = coh_lce_cmd_link_lo;
      assign core_lce_resp_link_li = coh_lce_resp_link_lo;
    end

  if (async_mem_clk_p == 1)
    begin : mem_async
      bsg_async_noc_link
       #(.width_p(mem_noc_flit_width_p)
         ,.lg_size_p(3)
         )
       mem_cdc
        (.aclk_i(core_clk_i)
         ,.areset_i(core_reset_i)

         ,.bclk_i(mem_clk_i)
         ,.breset_i(mem_reset_i)

         ,.alink_i(core_mem_cmd_link_lo)
         ,.alink_o(core_mem_resp_link_li)

         ,.blink_o(mem_cmd_link_lo)
         ,.blink_i(mem_resp_link_li)
         );
    end
  else
    begin : mem_sync
      assign core_mem_resp_link_li = mem_resp_link_li;
      assign mem_cmd_link_lo       = core_mem_cmd_link_lo;
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

     ,.my_cord_i(my_cord_i)

     ,.link_i({coh_lce_req_link_i, coh_lce_req_link_li})
     ,.link_o({coh_lce_req_link_o, coh_lce_req_link_lo})
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

     ,.my_cord_i(my_cord_i)

     ,.link_i({coh_lce_cmd_link_i, coh_lce_cmd_link_li})
     ,.link_o({coh_lce_cmd_link_o, coh_lce_cmd_link_lo})
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

     ,.my_cord_i(my_cord_i)

     ,.link_i({coh_lce_resp_link_i, coh_lce_resp_link_li})
     ,.link_o({coh_lce_resp_link_o, coh_lce_resp_link_lo})
     );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_dims_p(mem_noc_cord_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictX)
     )
   mem_cmd_router 
   (.clk_i(mem_clk_i)
    ,.reset_i(mem_reset_i)

    ,.my_cord_i(my_cord_i[coh_noc_x_cord_width_p+:mem_noc_y_cord_width_p])

    ,.link_i({mem_resp_link_i, mem_cmd_link_lo})
    ,.link_o({mem_cmd_link_o, mem_resp_link_li})
    );

endmodule


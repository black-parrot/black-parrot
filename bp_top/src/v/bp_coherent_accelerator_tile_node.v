/**
 *
 * bp_accelerator_tile_node.v
 *
 */

module bp_coherent_accelerator_tile_node
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
   , parameter bp_enable_accelerator_p = 0
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   , parameter accelerator_type_p = 1
   )
  (input                                         core_clk_i
   , input                                       core_reset_i

   , input                                       coh_clk_i
   , input                                       coh_reset_i

   , input [coh_noc_cord_width_p-1:0]            my_cord_i
   // Connected to other tiles on east and west
   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_req_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_req_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_cmd_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_cmd_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_resp_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_resp_link_o
   );

  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  
  // Declare the routing links
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  
  // Tile-side coherence connections
  bp_coh_ready_and_link_s accel_lce_req_link_li, accel_lce_req_link_lo;
  bp_coh_ready_and_link_s accel_lce_cmd_link_li, accel_lce_cmd_link_lo;
  bp_coh_ready_and_link_s accel_lce_resp_link_li, accel_lce_resp_link_lo;
  

  bp_coherent_accelerator_tile
   #(.bp_params_p(bp_params_p)
     ,.bp_enable_accelerator_p(bp_enable_accelerator_p)
     )
   accel_tile
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)

     ,.my_cord_i(my_cord_i)
     
     ,.lce_req_link_i(accel_lce_req_link_li)
     ,.lce_req_link_o(accel_lce_req_link_lo)

     ,.lce_cmd_link_i(accel_lce_cmd_link_li)
     ,.lce_cmd_link_o(accel_lce_cmd_link_lo)

     ,.lce_resp_link_i(accel_lce_resp_link_li)
     ,.lce_resp_link_o(accel_lce_resp_link_lo)

     );

  // Network-side coherence connections
  bp_coh_ready_and_link_s coh_lce_req_link_li, coh_lce_req_link_lo;
  bp_coh_ready_and_link_s coh_lce_cmd_link_li, coh_lce_cmd_link_lo;
  bp_coh_ready_and_link_s coh_lce_resp_link_li, coh_lce_resp_link_lo;
  
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

         ,.alink_i(accel_lce_req_link_lo)
         ,.alink_o(accel_lce_req_link_li)

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

         ,.alink_i(accel_lce_cmd_link_lo)
         ,.alink_o(accel_lce_cmd_link_li)

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

         ,.alink_i(accel_lce_resp_link_lo)
         ,.alink_o(accel_lce_resp_link_li)

         ,.blink_i(coh_lce_resp_link_lo)
         ,.blink_o(coh_lce_resp_link_li)
         );
    end
  else
    begin : coh_sync
      assign coh_lce_req_link_li  = accel_lce_req_link_lo;
      assign coh_lce_cmd_link_li  = accel_lce_cmd_link_lo;
      assign coh_lce_resp_link_li = accel_lce_resp_link_lo;

      assign accel_lce_req_link_li  = coh_lce_req_link_lo;
      assign accel_lce_cmd_link_li  = coh_lce_cmd_link_lo;
      assign accel_lce_resp_link_li = coh_lce_resp_link_lo;
    end


  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictYX | YX_Allow_W)
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
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictYX | YX_Allow_W)
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
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictYX | YX_Allow_W)
     )
   lce_resp_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.my_cord_i(my_cord_i)

     ,.link_i({coh_lce_resp_link_i, coh_lce_resp_link_li})
     ,.link_o({coh_lce_resp_link_o, coh_lce_resp_link_lo})
     );

endmodule


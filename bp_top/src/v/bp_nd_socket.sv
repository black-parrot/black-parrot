/**
 *
 * bp_nd_socket.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

module bp_nd_socket
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter `BSG_INV_PARAM(flit_width_p)
   , parameter len_width_p = 1
   , parameter dims_p = 2
   , parameter cord_dims_p = dims_p
   , parameter int cord_markers_pos_p[cord_dims_p:0] = '{ 5, 4, 0 }
   , localparam dirs_lp = dims_p*2+1
   , parameter bit [1:0][dirs_lp-1:0][dirs_lp-1:0] routing_matrix_p =  (dims_p == 2) ? StrictXY : StrictX
   , parameter async_clk_p = 0
   , parameter els_p = 0

   , localparam ral_link_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
   )
  (input                                                     tile_clk_i
   , input                                                   tile_reset_i

   , input                                                   network_clk_i
   , input                                                   network_reset_i

   , input  [cord_markers_pos_p[dims_p]-1:0]                 my_cord_i

   , input  [els_p-1:0][dirs_lp-2:0][ral_link_width_lp-1:0]  network_link_i
   , output [els_p-1:0][dirs_lp-2:0][ral_link_width_lp-1:0]  network_link_o

   , input  [els_p-1:0][ral_link_width_lp-1:0]               tile_link_i
   , output [els_p-1:0][ral_link_width_lp-1:0]               tile_link_o

   );


  `declare_bsg_ready_and_link_sif_s(flit_width_p, bsg_ready_and_link_s);
  bsg_ready_and_link_s [els_p-1:0] network_link_li, network_link_lo;

for (genvar i=0; i < els_p; i++)
  begin: routers
  if (async_clk_p == 1)
    begin : async
      bsg_async_noc_link
       #(.width_p(flit_width_p)
         ,.lg_size_p(3)
         )
       cdc
        (.aclk_i(tile_clk_i)
         ,.areset_i(tile_reset_i)

         ,.bclk_i(network_clk_i)
         ,.breset_i(network_reset_i)

         ,.alink_i(tile_link_i[i])
         ,.alink_o(tile_link_o[i])

         ,.blink_i(network_link_lo[i])
         ,.blink_o(network_link_li[i])
         );
    end
  else
    begin : sync
      assign network_link_li[i]  = tile_link_i[i];
      assign tile_link_o[i]      = network_link_lo[i];
    end

  bsg_wormhole_router
   #(.flit_width_p(flit_width_p)
     ,.dims_p(dims_p)
     ,.cord_dims_p(cord_dims_p)
     ,.cord_markers_pos_p(cord_markers_pos_p)
     ,.len_width_p(len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(routing_matrix_p)
     ,.hold_on_valid_p(1)
     )
   router
    (.clk_i(network_clk_i)
     ,.reset_i(network_reset_i)

     ,.my_cord_i(my_cord_i)

     ,.link_i({network_link_i[i], network_link_li[i]})
     ,.link_o({network_link_o[i], network_link_lo[i]})
     );
  end


endmodule

`BSG_ABSTRACT_MODULE(bp_nd_socket)


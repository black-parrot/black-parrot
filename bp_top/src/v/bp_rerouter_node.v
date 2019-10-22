
module bp_rerouter_node
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                clk_i
   , input                                              reset_i

   , input [mem_noc_chid_width_p-1:0]                   my_chid_i
   , input [mem_noc_cord_width_p-1:0]                   my_cord_i

   , input [S:W][mem_noc_ral_link_width_lp-1:0]         mem_cmd_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]        mem_cmd_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]         mem_resp_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]        mem_resp_link_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

  mem_noc_ral_link_s reroute_cmd_link_li, reroute_cmd_link_lo;
  mem_noc_ral_link_s reroute_resp_link_li, reroute_resp_link_lo;

  logic [mem_noc_cord_width_p-1:0] dst_cord_lo;
  logic [mem_noc_cid_width_p-1:0] dst_cid_lo;
  bp_rerouter
   #(.bp_params_p(bp_params_p))
   rerouter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.my_chid_i(my_chid_i)
     ,.my_cord_i(my_cord_i)

     ,.mem_cmd_link_i(reroute_cmd_link_li)
     ,.mem_cmd_link_o(reroute_cmd_link_lo)

     ,.mem_resp_link_i(reroute_resp_link_li)
     ,.mem_resp_link_o(reroute_resp_link_lo)
     );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictXY | XY_Allow_S)
     )
   mem_cmd_router
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.my_cord_i(my_cord_i)
    ,.link_i({mem_cmd_link_i, reroute_cmd_link_lo})
    ,.link_o({mem_cmd_link_o, reroute_cmd_link_li})
    );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictXY | XY_Allow_S)
     )
   mem_resp_router
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.my_cord_i(my_cord_i)
     ,.link_i({mem_resp_link_i, reroute_resp_link_lo})
     ,.link_o({mem_resp_link_o, reroute_resp_link_li})
     );

endmodule


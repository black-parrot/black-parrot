
/* TODO: Inline this module into BP Tile */
module bp_me_tile_router
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   , localparam dirs_lp = 5 // NSEW, P
   , parameter x_cord_width_p = "inv"
   , parameter y_cord_width_p = "inv"
   , parameter debug_p = 0
   )
  (input clk_i
   , input reset_i

   , input [x_cord_width_p-1:0] my_x_i
   , input [y_cord_width_p-1:0] my_y_i

   // inputs
   , input  [dirs_lp-1:0][lce_cce_req_width_lp-1:0] lce_req_i
   , input  [dirs_lp-1:0]                           lce_req_v_i
   , output [dirs_lp-1:0]                           lce_req_ready_o

   , input  [dirs_lp-1:0][lce_cce_resp_width_lp-1:0] lce_resp_i
   , input  [dirs_lp-1:0]                            lce_resp_v_i
   , output [dirs_lp-1:0]                            lce_resp_ready_o

   , input [dirs_lp-1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_i
   , input [dirs_lp-1:0]                                 lce_data_resp_v_i
   , output [dirs_lp-1:0]                                lce_data_resp_ready_o

   , input [dirs_lp-1:0][lce_data_cmd_width_lp-1:0] lce_data_cmd_i
   , input [dirs_lp-1:0]                            lce_data_cmd_v_i
   , output [dirs_lp-1:0]                           lce_data_cmd_ready_o

   , input [dirs_lp-1:0][cce_lce_cmd_width_lp-1:0] lce_cmd_i
   , input [dirs_lp-1:0]                           lce_cmd_v_i
   , output                                        lce_cmd_ready_o

   // outputs
   , output  [dirs_lp-1:0][lce_cce_req_width_lp-1:0] lce_req_o
   , output  [dirs_lp-1:0]                           lce_req_v_o
   , input [dirs_lp-1:0]                             lce_req_ready_i

   , output [dirs_lp-1:0][lce_cce_resp_width_lp-1:0] lce_resp_o
   , output [dirs_lp-1:0]                            lce_resp_v_o
   , input  [dirs_lp-1:0]                            lce_resp_ready_i

   , output [dirs_lp-1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output [dirs_lp-1:0]                                 lce_data_resp_v_o
   , input [dirs_lp-1:0]                                  lce_data_resp_ready_i

   , output [dirs_lp-1:0][lce_data_cmd_width_lp-1:0] lce_data_cmd_o
   , output [dirs_lp-1:0]                            lce_data_cmd_v_o
   , input [dirs_lp-1:0]                             lce_data_cmd_ready_i

   , output [dirs_lp-1:0][cce_lce_cmd_width_lp-1:0] lce_cmd_o
   , output [dirs_lp-1:0]                           lce_cmd_v_o
   , input                                          lce_cmd_ready_i
   );
   

localparam lce_cce_req_network_width_lp = lce_cce_req_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1;
localparam lce_cce_resp_network_width_lp = lce_cce_resp_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1;
localparam lce_cce_data_resp_network_width_lp = lce_cce_data_resp_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1;
localparam lce_data_cmd_network_width_lp = lce_data_cmd_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1;
localparam cce_lce_cmd_network_width_lp = cce_lce_cmd_width_lp+`BSG_SAFE_CLOG2(x_cord_width_p)+1;

`declare_bsg_ready_and_link_sif_s(lce_cce_req_network_width_lp, bp_lce_req_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_resp_network_width_lp, bp_lce_resp_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_data_resp_network_width_lp, bp_lce_data_resp_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_data_cmd_network_width_lp, bp_lce_data_cmd_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(cce_lce_cmd_network_width_lp, bp_lce_cmd_ready_and_link_sif_s);

bp_lce_req_ready_and_link_sif_s [dirs_lp-1:0] lce_req_link_i_stitch;
bp_lce_req_ready_and_link_sif_s [dirs_lp-1:0] lce_req_link_o_stitch;

bp_lce_resp_ready_and_link_sif_s [dirs_lp-1:0] lce_resp_link_i_stitch;
bp_lce_resp_ready_and_link_sif_s [dirs_lp-1:0] lce_resp_link_o_stitch;

bp_lce_cmd_ready_and_link_sif_s [dirs_lp-1:0] lce_cmd_link_i_stitch;
bp_lce_cmd_ready_and_link_sif_s [dirs_lp-1:0] lce_cmd_link_o_stitch;

for (genvar i = 0; i < dirs_lp; i++) 
  begin : rof1
    assign lce_req_link_i_stitch[i].data          = lce_req_i;
    assign lce_req_link_i_stitch[i].v             = lce_req_v_i;
    assign lce_req_link_i_stitch[i].ready_and_rev = lce_req_ready_i;

    assign lce_resp_link_i_stitch[i].data          = lce_resp_i;
    assign lce_resp_link_i_stitch[i].v             = lce_resp_v_i;
    assign lce_resp_link_i_stitch[i].ready_and_rev = lce_resp_ready_i;

    assign lce_cmd_link_i_stitch[i].data          = lce_cmd_i;
    assign lce_cmd_link_i_stitch[i].v             = lce_cmd_v_i;
    assign lce_cmd_link_i_stitch[i].ready_and_rev = lce_cmd_ready_i;

    assign lce_req_ready_o   = lce_req_link_o_stitch[i].ready_and_rev;
    assign lce_resp_ready_o  = lce_resp_link_o_stitch[i].ready_and_rev;
    assign lce_cmd_ready_o   = lce_cmd_link_o_stitch[i].ready_and_rev;
  end // rof1

bsg_mesh_router_buffered
 #(.width_p(lce_cce_req_network_width_lp)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   ,.debug_p(debug_p)
   ,.XY_order_p(0)
   )
 req_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.link_i(lce_req_link_i_stitch)
   ,.link_o(lce_req_link_o_stitch)
   ,.my_x_i(my_x_i)
   ,.my_y_i(my_y_i)
   );

bsg_mesh_router_buffered
 #(.width_p(lce_cce_resp_network_width_lp)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   ,.debug_p(debug_p)
   ,.XY_order_p(0)
   )
 resp_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.link_i(lce_resp_link_i_stitch)
   ,.link_o(lce_resp_link_o_stitch)
   ,.my_x_i(my_x_i)
   ,.my_y_i(my_y_i)
   );

bsg_mesh_router_buffered
 #(.width_p(cce_lce_cmd_network_width_lp)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   ,.debug_p(debug_p)
   ,.XY_order_p(0)
   )
 cmd_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.link_i(lce_cmd_link_i_stitch)
   ,.link_o(lce_cmd_link_o_stitch)
   ,.my_x_i(my_x_i)
   ,.my_y_i(my_y_i)
   );

bp_me_lce_data_cmd_router
 #(.cfg_p(cfg_p)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   )
 data_cmd_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.my_x_i(my_x_i)
   ,.my_y_i(my_y_i)

   ,.lce_data_cmd_i(lce_data_cmd_i)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

   ,.lce_data_cmd_o(lce_data_cmd_o)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)
   );

bp_me_lce_data_resp_router
 #(.cfg_p(cfg_p)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   )
 data_resp_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.my_x_i(my_x_i)
   ,.my_y_i(my_y_i)

   ,.lce_data_resp_i(lce_data_resp_i)
   ,.lce_data_resp_v_i(lce_data_resp_v_i)
   ,.lce_data_resp_ready_o(lce_data_resp_ready_o)

   ,.lce_data_resp_o(lce_data_resp_o)
   ,.lce_data_resp_v_o(lce_data_resp_v_o)
   ,.lce_data_resp_ready_i(lce_data_resp_ready_i)
   );

endmodule : bp_me_tile_router


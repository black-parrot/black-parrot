/**
 *
 * bp_multi_top.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_chip
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   // Used to enable trace replay outputs for testbench
   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1
   
   // Wormhole parameters
   , localparam dims_lp = 1
   , localparam int cord_markers_pos_lp[dims_lp:0] = '{noc_cord_width_p, 0}
   , localparam cord_width_lp = cord_markers_pos_lp[dims_lp]
   , localparam dirs_lp = dims_lp*2+1
   , localparam bit [1:0][dirs_lp-1:0][dirs_lp-1:0] routing_matrix_lp = StrictX
   
   // Tile parameters
   , localparam num_tiles_lp = num_core_p
   , localparam num_routers_lp = num_tiles_lp+1
   
   // Other parameters
   , localparam lce_cce_req_network_width_lp = lce_cce_req_width_lp+x_cord_width_p+1
   , localparam lce_cce_resp_network_width_lp = lce_cce_resp_width_lp+x_cord_width_p+1
   , localparam cce_lce_cmd_network_width_lp = cce_lce_cmd_width_lp+x_cord_width_p+1

   , localparam lce_cce_data_resp_num_flits_lp = bp_data_resp_num_flit_gp
   , localparam lce_cce_data_resp_len_width_lp = `BSG_SAFE_CLOG2(lce_cce_data_resp_num_flits_lp)
   , localparam lce_cce_data_resp_packet_width_lp = 
       lce_cce_data_resp_width_lp+x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp
   , localparam lce_cce_data_resp_router_width_lp = 
       (lce_cce_data_resp_packet_width_lp/lce_cce_data_resp_num_flits_lp) 
       + ((lce_cce_data_resp_packet_width_lp%lce_cce_data_resp_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_cce_data_resp_payload_offset_lp = 
       (x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp)

   , localparam lce_data_cmd_num_flits_lp = bp_data_cmd_num_flit_gp
   , localparam lce_data_cmd_len_width_lp = `BSG_SAFE_CLOG2(lce_data_cmd_num_flits_lp)
   , localparam lce_data_cmd_packet_width_lp = 
       lce_data_cmd_width_lp+x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp
   , localparam lce_data_cmd_router_width_lp = 
       (lce_data_cmd_packet_width_lp/lce_data_cmd_num_flits_lp) 
       + ((lce_data_cmd_packet_width_lp%lce_data_cmd_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_data_cmd_payload_offset_lp = (x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp)
   
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)

   // Arbitrarily set, should be set based on PD constraints
   , localparam reset_pipe_depth_lp = 10
   )
  (input                                          clk_i
   , input                                        reset_i

   , input [num_core_p-1:0][cord_width_lp-1:0]    tile_cord_i
   , input [cord_width_lp-1:0]                    dram_cord_i
   , input [cord_width_lp-1:0]                    clint_cord_i

   , input  [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);

bsg_ready_and_link_sif_s [num_routers_lp-1:0][E:P] cmd_link_li,  cmd_link_lo;
bsg_ready_and_link_sif_s [num_routers_lp-1:0][E:P] resp_link_li, resp_link_lo;

bsg_ready_and_link_sif_s [num_routers_lp-1:0] cc_cmd_link_li, cc_cmd_link_lo;
bsg_ready_and_link_sif_s [num_routers_lp-1:0] cc_resp_link_li, cc_resp_link_lo;

bp_core_complex
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   ,.cce_trace_p(cce_trace_p)
   )
  cc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.tile_cord_i(tile_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.clint_cord_i(clint_cord_i)

   ,.cmd_link_i(cc_cmd_link_li)
   ,.cmd_link_o(cc_cmd_link_lo)

   ,.resp_link_i(cc_resp_link_li)
   ,.resp_link_o(cc_resp_link_lo)
   );

for (genvar i = 0; i < num_routers_lp; i++)
  begin: wh_router
    logic [noc_cord_width_p-1:0] router_cord_li;
    if (i == clint_pos_p)
      begin : fi1
        assign router_cord_li = clint_cord_i;
      end 
    else 
      begin : fi1
        localparam tile_id_lp = (i < clint_pos_p) ? i : i-1;

        assign router_cord_li = tile_cord_i[tile_id_lp];
      end

    bsg_wormhole_router_generalized
     #(.flit_width_p(noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(routing_matrix_lp)
       ,.len_width_p(noc_len_width_p)
       )
     cmd_router
     (.clk_i(clk_i)
	    ,.reset_i(reset_i)
 	    ,.my_cord_i(router_cord_li)
      ,.link_i(cmd_link_li[i])
      ,.link_o(cmd_link_lo[i])
	    );
  
    bsg_wormhole_router_generalized
     #(.flit_width_p(noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(routing_matrix_lp)
       ,.len_width_p(noc_len_width_p)
       )
     resp_router
      (.clk_i(clk_i)
	     ,.reset_i(reset_i)
	     ,.my_cord_i(router_cord_li)
       ,.link_i(resp_link_li[i])
       ,.link_o(resp_link_lo[i])
	     );
    
    // Link to next router
    if (i != num_routers_lp-1)
    begin : fi2
      assign cmd_link_li[i][E]   = cmd_link_lo[i+1][W];
      assign cmd_link_li[i+1][W] = cmd_link_lo[i][E];

      assign resp_link_li[i][E]   = resp_link_lo[i+1][W];
      assign resp_link_li[i+1][W] = resp_link_lo[i][E];
    end
  end

// Connect end of chain to off-chip
assign cmd_link_li[0][W]                 = '0;
assign cmd_link_li[num_routers_lp-1][E]  = cmd_link_i;
assign cmd_link_o                        = cmd_link_lo[num_routers_lp-1][E];

assign resp_link_li[0][W]                = '0;
assign resp_link_li[num_routers_lp-1][E] = resp_link_i;
assign resp_link_o                       = resp_link_lo[num_routers_lp-1][E];

// Connect endpoints in core_complex
for (genvar i = 0; i < num_routers_lp; i++)
  begin : rof1
    assign cc_cmd_link_li[i]  = cmd_link_lo[i][P];
    assign cmd_link_li[i][P]  = cc_cmd_link_lo[i];
    assign cc_resp_link_li[i] = resp_link_lo[i][P];
    assign resp_link_li[i][P] = cc_resp_link_lo[i];
  end

endmodule


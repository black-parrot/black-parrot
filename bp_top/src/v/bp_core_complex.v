/**
 *
 * bp_core_complex.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_core_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Used to enable trace replay outputs for testbench
   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   , localparam x_cord_width_lp = `BSG_SAFE_CLOG2(num_lce_p)
   , localparam y_cord_width_lp = 1
   
   // FIXME: hardcoded
   , localparam noc_x_cord_width_lp = 7
   , localparam noc_y_cord_width_lp = 1

   // Wormhole parameters
   , localparam dims_lp = 1
   , localparam int cord_markers_pos_lp[dims_lp:0] = '{noc_x_cord_width_lp+noc_y_cord_width_lp, 0}
   , localparam cord_width_lp = cord_markers_pos_lp[dims_lp]
   , localparam dirs_lp = dims_lp*2+1
   , localparam bit [1:0][dirs_lp-1:0][dirs_lp-1:0] routing_matrix_lp = StrictX
   
   // Tile parameters
   , localparam num_tiles_lp = num_core_p
   , localparam num_routers_lp = num_tiles_lp+1
   
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)

   // Arbitrarily set, should be set based on PD constraints
   , localparam reset_pipe_depth_lp = 10
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_routers_lp-1:0][cord_width_lp-1:0]                    my_cord_i
   , input [num_routers_lp-1:0][cord_width_lp-1:0]                    dest_cord_i

   , input [num_routers_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [num_routers_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [num_routers_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [num_routers_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

logic [num_core_p-1:0] timer_irq_lo, soft_irq_lo, external_irq_lo;

logic [num_core_p-1:0]                       cfg_w_v_lo;
logic [num_core_p-1:0][cfg_addr_width_p-1:0] cfg_addr_lo;
logic [num_core_p-1:0][cfg_data_width_p-1:0] cfg_data_lo;

`declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s [num_routers_lp-1:0] cmd_link_cast_i, cmd_link_cast_o;
bsg_ready_and_link_sif_s [num_routers_lp-1:0] resp_link_cast_i, resp_link_cast_o;

assign cmd_link_cast_i  = cmd_link_i;
assign cmd_link_o       = cmd_link_cast_o;

assign resp_link_cast_i = resp_link_i;
assign resp_link_o      = resp_link_cast_o;

/************************* RESET *************************/
logic reset_r;
bsg_dff_chain
 #(.width_p(1)
   ,.num_stages_p(reset_pipe_depth_lp)
   )
 reset_pipe
  (.clk_i(clk_i)
   ,.data_i(reset_i)
   ,.data_o(reset_r)
   );

/************************* Router nodes *************************/
// Mapping clint to router-pos
// Clint is in the middle of chain, for single core it is at position 1
// `BSG_CDIV(num_core_p, 2);
localparam clint_pos_lp = ((cfg_p == e_bp_oct_core_cfg) || (cfg_p == e_bp_sexta_core_cfg))
                          ? 6
                          : `BSG_CDIV(num_core_p, 2);


logic [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  tile_cmd_link_i;
logic  [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] tile_cmd_link_o;
logic [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  tile_resp_link_i;
logic  [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] tile_resp_link_o;
logic [num_core_p-1:0][cord_width_lp-1:0]                    top_my_cord_li;
logic [num_core_p-1:0][cord_width_lp-1:0]                    top_dest_cord_li;

logic [bsg_ready_and_link_sif_width_lp-1:0]                  clint_cmd_link_i;
logic [bsg_ready_and_link_sif_width_lp-1:0]                  clint_cmd_link_o;
logic [bsg_ready_and_link_sif_width_lp-1:0]                  clint_resp_link_i;
logic [bsg_ready_and_link_sif_width_lp-1:0]                  clint_resp_link_o;

bp_top
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   ,.cce_trace_p(cce_trace_p)
   )
 bp_top
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_w_v_i(cfg_w_v_lo)
   ,.cfg_addr_i(cfg_addr_lo)
   ,.cfg_data_i(cfg_data_lo)

   ,.timer_irq_i(timer_irq_lo)
   ,.soft_irq_i(soft_irq_lo)
   ,.external_irq_i(external_irq_lo)

   ,.my_cord_i(top_my_cord_li)
   ,.dest_cord_i(top_dest_cord_li)
   ,.clint_cord_i(my_cord_i[clint_pos_lp])

   ,.cmd_link_i(tile_cmd_link_i)
   ,.cmd_link_o(tile_cmd_link_o)
   ,.resp_link_i(tile_resp_link_i)
   ,.resp_link_o(tile_resp_link_o)
   );

bp_clint
 #(.cfg_p(cfg_p)
   ,.noc_x_cord_width_p(noc_x_cord_width_lp)
   ,.noc_y_cord_width_p(noc_y_cord_width_lp)
   )
 clint
  (.clk_i(clk_i)
   ,.reset_i(reset_r)
   
   ,.cfg_w_v_o(cfg_w_v_lo)
   ,.cfg_addr_o(cfg_addr_lo)
   ,.cfg_data_o(cfg_data_lo)

   ,.soft_irq_o(soft_irq_lo)
   ,.timer_irq_o(timer_irq_lo)
   ,.external_irq_o(external_irq_lo)

   ,.my_cord_i(my_cord_i[clint_pos_lp])
   ,.dest_cord_i(dest_cord_i[clint_pos_lp])
   ,.clint_cord_i(my_cord_i[clint_pos_lp])

   ,.cmd_link_i(clint_cmd_link_i)
   ,.cmd_link_o(clint_cmd_link_o)
   ,.resp_link_i(clint_resp_link_i)
   ,.resp_link_o(clint_resp_link_o)
   );

/************************* Wormhole Link Stitching *************************/
for (genvar i = 0; i < num_routers_lp; i++)
  begin : rof1
    if (i == clint_pos_lp)
      begin : fi1
        assign resp_link_cast_o[i] = clint_resp_link_o;
        assign cmd_link_cast_o[i] = clint_cmd_link_o;
        assign clint_cmd_link_i = cmd_link_cast_i[i];
        assign clint_resp_link_i = resp_link_cast_i[i];
      end
    else
      begin : fi1
        // We subtract 1 if we're past the clint, so that the slice lines up with bp_top
        localparam core_id_lp = (i < clint_pos_lp) ? i : i-1;

        // assign the coordinate inputs for bp_top
        // These assignments transform the my_cord_i vector, which is num_routers_lp wide, into
        // the top_my_cord_li vector, which is num_core_p wide, effectively splicing out the
        // clint coordinate entry
        assign top_my_cord_li[core_id_lp] = my_cord_i[i];
        assign top_dest_cord_li[core_id_lp] = dest_cord_i[i];

        assign resp_link_cast_o[i] = tile_resp_link_o[core_id_lp];
        assign cmd_link_cast_o[i] = tile_cmd_link_o[core_id_lp];
        assign tile_cmd_link_i[core_id_lp] = cmd_link_cast_i[i];
        assign tile_resp_link_i[core_id_lp] = resp_link_cast_i[i];
      end
  end

endmodule : bp_core_complex


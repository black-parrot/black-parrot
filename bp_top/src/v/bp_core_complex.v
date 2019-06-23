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
   , parameter calc_trace_p = 1
   , parameter cce_trace_p  = 1

   , localparam x_cord_width_lp = `BSG_SAFE_CLOG2(num_lce_p)
   , localparam y_cord_width_lp = 1
   
   // FIXME: hardcoded
   , localparam noc_x_cord_width_lp = 8
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

bp_cce_mem_cmd_s       [num_core_p-1:0] tile_cmd_lo;
logic                  [num_core_p-1:0] tile_cmd_v_lo, tile_cmd_yumi_li;
bp_cce_mem_data_cmd_s  [num_core_p-1:0] tile_data_cmd_lo;
logic                  [num_core_p-1:0] tile_data_cmd_v_lo, tile_data_cmd_yumi_li;
bp_mem_cce_resp_s      [num_core_p-1:0] tile_resp_li;
logic                  [num_core_p-1:0] tile_resp_v_li, tile_resp_ready_lo;
bp_mem_cce_data_resp_s [num_core_p-1:0] tile_data_resp_li;
logic                  [num_core_p-1:0] tile_data_resp_v_li, tile_data_resp_ready_lo;
  
bp_cce_mem_cmd_s       clint_cmd_li;
logic                  clint_cmd_v_li, clint_cmd_yumi_lo;
bp_cce_mem_data_cmd_s  clint_data_cmd_li;
logic                  clint_data_cmd_v_li, clint_data_cmd_yumi_lo;
bp_mem_cce_resp_s      clint_resp_lo;
logic                  clint_resp_v_lo, clint_resp_ready_li;
bp_mem_cce_data_resp_s clint_data_resp_lo;
logic                  clint_data_resp_v_lo, clint_data_resp_ready_li;

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
localparam clint_pos_lp = `BSG_CDIV(num_core_p, 2);

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

   ,.mem_cmd_o(tile_cmd_lo)
   ,.mem_cmd_v_o(tile_cmd_v_lo)
   ,.mem_cmd_yumi_i(tile_cmd_yumi_li)

   ,.mem_data_cmd_o(tile_data_cmd_lo)
   ,.mem_data_cmd_v_o(tile_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_i(tile_data_cmd_yumi_li)

   ,.mem_resp_i(tile_resp_li)
   ,.mem_resp_v_i(tile_resp_v_li)
   ,.mem_resp_ready_o(tile_resp_ready_lo)

   ,.mem_data_resp_i(tile_data_resp_li)
   ,.mem_data_resp_v_i(tile_data_resp_v_li)
   ,.mem_data_resp_ready_o(tile_data_resp_ready_lo)
   );

bp_clint
 #(.cfg_p(cfg_p))
 clint
  (.clk_i(clk_i)
   ,.reset_i(reset_r)
   
   ,.cfg_w_v_o(cfg_w_v_lo)
   ,.cfg_addr_o(cfg_addr_lo)
   ,.cfg_data_o(cfg_data_lo)

   ,.soft_irq_o(soft_irq_lo)
   ,.timer_irq_o(timer_irq_lo)
   ,.external_irq_o(external_irq_lo)

   ,.mem_cmd_i(clint_cmd_li)
   ,.mem_cmd_v_i(clint_cmd_v_li)
   ,.mem_cmd_yumi_o(clint_cmd_yumi_lo)
   
   ,.mem_data_cmd_i(clint_data_cmd_li)
   ,.mem_data_cmd_v_i(clint_data_cmd_v_li)
   ,.mem_data_cmd_yumi_o(clint_data_cmd_yumi_lo)
   
   ,.mem_resp_o(clint_resp_lo)
   ,.mem_resp_v_o(clint_resp_v_lo)
   ,.mem_resp_ready_i(clint_resp_ready_li)
   
   ,.mem_data_resp_o(clint_data_resp_lo)
   ,.mem_data_resp_v_o(clint_data_resp_v_lo)
   ,.mem_data_resp_ready_i(clint_data_resp_ready_li)
   );

/************************* Adapters to wormhole *************************/
for (genvar i = 0; i < num_routers_lp; i++)
  begin : rof1
    bp_cce_mem_cmd_s       mem_cmd_li;
    logic                  mem_cmd_v_li, mem_cmd_yumi_lo;
    bp_cce_mem_data_cmd_s  mem_data_cmd_li;
    logic                  mem_data_cmd_v_li, mem_data_cmd_yumi_lo;
    bp_mem_cce_resp_s      mem_resp_lo;
    logic                  mem_resp_v_lo, mem_resp_ready_li;
    bp_mem_cce_data_resp_s mem_data_resp_lo;
    logic                  mem_data_resp_v_lo, mem_data_resp_ready_li;

    bp_cce_mem_cmd_s       mem_cmd_lo;
    logic                  mem_cmd_v_lo, mem_cmd_yumi_li;
    bp_cce_mem_data_cmd_s  mem_data_cmd_lo;
    logic                  mem_data_cmd_v_lo, mem_data_cmd_yumi_li;
    bp_mem_cce_resp_s      mem_resp_li;
    logic                  mem_resp_v_li, mem_resp_ready_lo;
    bp_mem_cce_data_resp_s mem_data_resp_li;
    logic                  mem_data_resp_v_li, mem_data_resp_ready_lo;
    
    if (i == clint_pos_lp)
      begin : fi1
        // Master link
        assign {mem_cmd_li, mem_cmd_v_li} = '0;
        assign {mem_data_cmd_li, mem_data_cmd_v_li} = '0;
        assign mem_resp_ready_li = 1'b1;
        assign mem_data_resp_ready_li = 1'b1;

        // Client link
        assign {clint_cmd_li, clint_cmd_v_li, mem_cmd_yumi_li} =
          {mem_cmd_lo, mem_cmd_v_lo, clint_cmd_yumi_lo};
        assign {clint_data_cmd_li, clint_data_cmd_v_li, mem_data_cmd_yumi_li} =
          {mem_data_cmd_lo, mem_data_cmd_v_lo, clint_data_cmd_yumi_lo};
        assign {mem_resp_li, mem_resp_v_li, clint_resp_ready_li} = 
          {clint_resp_lo, clint_resp_v_lo, mem_resp_ready_lo};
        assign {mem_data_resp_li, mem_data_resp_v_li, clint_data_resp_ready_li} = 
          {clint_data_resp_lo, clint_data_resp_v_lo, mem_data_resp_ready_lo};
      end
    else
      begin : fi1
        // We subtract 1 if we're past the clint, so that the slice lines up with bp_top
        localparam core_id_lp = (i < clint_pos_lp) ? i : i-1;
        // Master link
        assign {mem_cmd_li, mem_cmd_v_li, tile_cmd_yumi_li[core_id_lp]} =
          {tile_cmd_lo[core_id_lp], tile_cmd_v_lo[core_id_lp], mem_cmd_yumi_lo};
        assign {mem_data_cmd_li, mem_data_cmd_v_li, tile_data_cmd_yumi_li[core_id_lp]} =
          {tile_data_cmd_lo[core_id_lp], tile_data_cmd_v_lo[core_id_lp], mem_data_cmd_yumi_lo};
        assign {tile_resp_li[core_id_lp], tile_resp_v_li[core_id_lp], mem_resp_ready_li} =
          {mem_resp_lo, mem_resp_v_lo, tile_resp_ready_lo[core_id_lp]};
        assign {tile_data_resp_li[core_id_lp], tile_data_resp_v_li[core_id_lp], mem_data_resp_ready_li} =
          {mem_data_resp_lo, mem_data_resp_v_lo, tile_data_resp_ready_lo[core_id_lp]};

        // Client link
        assign mem_cmd_yumi_li = '0;
        assign mem_data_cmd_yumi_li = '0;
        assign {mem_resp_li, mem_resp_v_li} = '0;
        assign {mem_data_resp_li, mem_data_resp_v_li} = '0;
      end

   logic [noc_x_cord_width_lp-1:0] cmd_dest_x_lo;
   logic [noc_y_cord_width_lp-1:0] cmd_dest_y_lo;
   bp_addr_map
    #(.cfg_p(cfg_p)
      ,.x_cord_width_p(noc_x_cord_width_lp)
      ,.y_cord_width_p(noc_y_cord_width_lp)
      )
    cmd_map
     (.paddr_i(mem_cmd_li.addr)
     /* TODO: Genericize */
     ,.clint_x_cord_i(clint_pos_lp[0+:noc_x_cord_width_lp])
     ,.clint_y_cord_i(1'b0)
     ,.dram_x_cord_i(num_routers_lp[0+:noc_x_cord_width_lp])
     ,.dram_y_cord_i(1'b0)

     ,.dest_x_o(cmd_dest_x_lo)
     ,.dest_y_o(cmd_dest_y_lo)
     );
       
   logic [noc_x_cord_width_lp-1:0] data_cmd_dest_x_lo;
   logic [noc_y_cord_width_lp-1:0] data_cmd_dest_y_lo;
   bp_addr_map
    #(.cfg_p(cfg_p)
      ,.x_cord_width_p(noc_x_cord_width_lp)
      ,.y_cord_width_p(noc_y_cord_width_lp)
      )
    data_cmd_map
     (.paddr_i(mem_data_cmd_li.addr)
      ,.clint_x_cord_i(clint_pos_lp[0+:noc_x_cord_width_lp])
      ,.clint_y_cord_i(1'b0)
      ,.dram_x_cord_i(num_routers_lp[0+:noc_x_cord_width_lp])
      ,.dram_y_cord_i(1'b0)

      ,.dest_x_o(data_cmd_dest_x_lo)
      ,.dest_y_o(data_cmd_dest_y_lo)
      );
 
    bsg_ready_and_link_sif_s wh_master_link_li, wh_master_link_lo;
    bp_me_cce_to_wormhole_link_master
     #(.cfg_p(cfg_p)
       ,.x_cord_width_p(noc_x_cord_width_lp)
       ,.y_cord_width_p(noc_y_cord_width_lp)
       )
     master_link
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.mem_cmd_i(mem_cmd_li)
       ,.mem_cmd_v_i(mem_cmd_v_li)
       ,.mem_cmd_yumi_o(mem_cmd_yumi_lo)

       ,.mem_data_cmd_i(mem_data_cmd_li)
       ,.mem_data_cmd_v_i(mem_data_cmd_v_li)
       ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_lo)

       ,.mem_resp_o(mem_resp_lo)
       ,.mem_resp_v_o(mem_resp_v_lo)
       ,.mem_resp_ready_i(mem_resp_ready_li)

       ,.mem_data_resp_o(mem_data_resp_lo)
       ,.mem_data_resp_v_o(mem_data_resp_v_lo)
       ,.mem_data_resp_ready_i(mem_data_resp_ready_li)
      
       // TODO: Should change adapter to accept new wormhole coord format directly
       ,.my_x_i(my_cord_i[i][0+:noc_x_cord_width_lp])
       ,.my_y_i('0)
      
       // TODO: Split out addr map into generic 'dest_map' with variable number of dests
       ,.mem_cmd_dest_x_i(cmd_dest_x_lo)
       ,.mem_cmd_dest_y_i(cmd_dest_y_lo)
      
       ,.mem_data_cmd_dest_x_i(data_cmd_dest_x_lo)
       ,.mem_data_cmd_dest_y_i(data_cmd_dest_y_lo)

       ,.link_i(wh_master_link_li)
       ,.link_o(wh_master_link_lo)
       );

    bsg_ready_and_link_sif_s wh_client_link_li, wh_client_link_lo;
    bp_me_cce_to_wormhole_link_client
     #(.cfg_p(cfg_p)
       ,.x_cord_width_p(noc_x_cord_width_lp)
       ,.y_cord_width_p(noc_y_cord_width_lp)
       )
    client_link
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
        
       ,.mem_cmd_o(mem_cmd_lo)
       ,.mem_cmd_v_o(mem_cmd_v_lo)
       ,.mem_cmd_yumi_i(mem_cmd_yumi_li)
        
       ,.mem_data_cmd_o(mem_data_cmd_lo)
       ,.mem_data_cmd_v_o(mem_data_cmd_v_lo)
       ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li)
        
       ,.mem_resp_i(mem_resp_li)
       ,.mem_resp_v_i(mem_resp_v_li)
       ,.mem_resp_ready_o(mem_resp_ready_lo)
        
       ,.mem_data_resp_i(mem_data_resp_li)
       ,.mem_data_resp_v_i(mem_data_resp_v_li)
       ,.mem_data_resp_ready_o(mem_data_resp_ready_lo)
          
       // TODO: Should change adapter to accept new wormhole coord format directly
       ,.my_x_i(my_cord_i[i][0+:noc_x_cord_width_lp])
       ,.my_y_i('0)
          
       ,.link_i(wh_client_link_li)
       ,.link_o(wh_client_link_lo)
       );

    assign wh_client_link_li.v             = cmd_link_cast_i[i].v;
    assign wh_client_link_li.data          = cmd_link_cast_i[i].data;
    assign wh_client_link_li.ready_and_rev = resp_link_cast_i[i].ready_and_rev;

    assign wh_master_link_li.v             = resp_link_cast_i[i].v;
    assign wh_master_link_li.data          = resp_link_cast_i[i].data;
    assign wh_master_link_li.ready_and_rev = cmd_link_cast_i[i].ready_and_rev;

    assign resp_link_cast_o[i].v = wh_client_link_lo.v;
    assign resp_link_cast_o[i].data = wh_client_link_lo.data;
    assign resp_link_cast_o[i].ready_and_rev = wh_master_link_lo.ready_and_rev;

    assign cmd_link_cast_o[i].v = wh_master_link_lo.v;
    assign cmd_link_cast_o[i].data = wh_master_link_lo.data;
    assign cmd_link_cast_o[i].ready_and_rev = wh_client_link_lo.ready_and_rev;
  end

endmodule : bp_core_complex


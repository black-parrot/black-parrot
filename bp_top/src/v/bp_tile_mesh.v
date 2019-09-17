/**
 *
 * bp_tile_mesh.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_tile_mesh
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Tile parameters
   , localparam num_tiles_lp = num_core_p
   , localparam num_routers_lp = num_tiles_lp+1
   
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)

   // Arbitrarily set, should be set based on PD constraints
   , localparam reset_pipe_depth_lp = 10

   // TODO: This is hardcoded, should be set based on topology
   , localparam int repeater_depth_lp [15:0] = '{0, 0, 0, 0
                                                ,2, 0, 0, 0
                                                ,2, 0, 0, 0
                                                ,2, 0, 0, 0
                                                }
   )
  (input                                                    clk_i
   , input                                                  reset_i

   // Config channel
   , input [num_core_p-1:0]                                 cfg_w_v_i
   , input [num_core_p-1:0][cfg_addr_width_p-1:0]           cfg_addr_i
   , input [num_core_p-1:0][cfg_data_width_p-1:0]           cfg_data_i

   // Interrupts
   , input [num_core_p-1:0]                                 timer_irq_i
   , input [num_core_p-1:0]                                 soft_irq_i
   , input [num_core_p-1:0]                                 external_irq_i

   // Memory side connection
   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0]       tile_cord_i
   , input [mem_noc_cord_width_p-1:0]                       dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                       mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]                       host_cord_i

   , input [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0]  cmd_link_i
   , output [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0] cmd_link_o

   , input [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0]  resp_link_i
   , output [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0] resp_link_o

  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, coh_noc_ral_link_s);

coh_noc_ral_link_s [num_core_p:0][E:W] lce_req_link_stitch_lo, lce_req_link_stitch_li;
coh_noc_ral_link_s [num_core_p:0][E:W] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
coh_noc_ral_link_s [num_core_p:0][E:W] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;

/************************* BP Tiles *************************/
assign lce_req_link_stitch_lo[0][W]                = '0;
assign lce_resp_link_stitch_lo[0][W]               = '0;
assign lce_cmd_link_stitch_lo[0][W]                = '0;

assign lce_req_link_stitch_li[num_core_p][W]       = '0;
assign lce_resp_link_stitch_li[num_core_p][W]      = '0;
assign lce_cmd_link_stitch_li[num_core_p][W]       = '0;

for(genvar i = 0; i < num_core_p; i++) 
  begin : rof1
    localparam core_id   = i;
    localparam cce_id    = i;
    localparam icache_id = (i * 2 + 0);
    localparam dcache_id = (i * 2 + 1);

    localparam core_id_width_lp = `BSG_SAFE_CLOG2(num_core_p);
    localparam cce_id_width_lp  = `BSG_SAFE_CLOG2(num_cce_p);
    localparam lce_id_width_lp  = `BSG_SAFE_CLOG2(num_lce_p);

    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.core_id   = core_id[0+:core_id_width_lp];
    assign proc_cfg.cce_id    = cce_id[0+:cce_id_width_lp];
    assign proc_cfg.icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg.dcache_id = dcache_id[0+:lce_id_width_lp];

    bsg_noc_repeater_node
     #(.width_p(coh_noc_flit_width_p)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_req_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_req_link_stitch_li[i][E])
       ,.side_A_links_o(lce_req_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_req_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_req_link_stitch_lo[i+1][W])
       );

    bsg_noc_repeater_node
     #(.width_p(coh_noc_flit_width_p)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_cmd_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_cmd_link_stitch_li[i][E])
       ,.side_A_links_o(lce_cmd_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_cmd_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_cmd_link_stitch_lo[i+1][W])
       );

    bsg_noc_repeater_node
     #(.width_p(coh_noc_flit_width_p)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_resp_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_resp_link_stitch_li[i][E])
       ,.side_A_links_o(lce_resp_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_resp_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_resp_link_stitch_lo[i+1][W])
       );

    bp_tile
     #(.cfg_p(cfg_p))
     tile
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg)

       ,.cfg_w_v_i(cfg_w_v_i[i])
       ,.cfg_addr_i(cfg_addr_i[i])
       ,.cfg_data_i(cfg_data_i[i])

       // Router inputs
       ,.lce_req_link_i(lce_req_link_stitch_lo[i])
       ,.lce_resp_link_i(lce_resp_link_stitch_lo[i])
       ,.lce_cmd_link_i(lce_cmd_link_stitch_lo[i])

       // Router outputs
       ,.lce_req_link_o(lce_req_link_stitch_li[i])
       ,.lce_resp_link_o(lce_resp_link_stitch_li[i])
       ,.lce_cmd_link_o(lce_cmd_link_stitch_li[i])

       // CCE-MEM IF
       ,.my_cord_i(tile_cord_i[i])
       // TODO: configurable?
       ,.my_cid_i('0)
       ,.dram_cord_i(dram_cord_i)
       ,.mmio_cord_i(mmio_cord_i)
       ,.host_cord_i(host_cord_i)

       ,.cmd_link_i(cmd_link_i[i])
       ,.cmd_link_o(cmd_link_o[i])
       ,.resp_link_i(resp_link_i[i])
       ,.resp_link_o(resp_link_o[i])

       ,.timer_int_i(timer_irq_i[i])
       ,.software_int_i(soft_irq_i[i])
       ,.external_int_i(external_irq_i[i])
       );
  end

endmodule


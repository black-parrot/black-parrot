/**
 *
 * bp_chip.v
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
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Other parameters
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0] tile_cord_i
   , input [mem_noc_cord_width_p-1:0]                 dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                 mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]                 host_cord_i

   , input  [bsg_ready_and_link_sif_width_lp-1:0]     cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]     cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]      resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]     resp_link_o
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);

bsg_ready_and_link_sif_s [num_core_p-1:0] tile_cmd_link_li, tile_cmd_link_lo;
bsg_ready_and_link_sif_s [num_core_p-1:0] tile_resp_link_li, tile_resp_link_lo;
bsg_ready_and_link_sif_s mmio_cmd_link_li, mmio_cmd_link_lo;
bsg_ready_and_link_sif_s mmio_resp_link_li, mmio_resp_link_lo;

bp_core_complex
 #(.cfg_p(cfg_p))
 cc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.tile_cord_i(tile_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.mmio_cord_i(mmio_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.tile_cmd_link_i(tile_cmd_link_li)
   ,.tile_cmd_link_o(tile_cmd_link_lo)

   ,.tile_resp_link_i(tile_resp_link_li)
   ,.tile_resp_link_o(tile_resp_link_lo)

   ,.mmio_cmd_link_i(mmio_cmd_link_li)
   ,.mmio_cmd_link_o(mmio_cmd_link_lo)

   ,.mmio_resp_link_i(mmio_resp_link_li)
   ,.mmio_resp_link_o(mmio_resp_link_lo)
   );

bsg_ready_and_link_sif_s [num_core_p-1:0][mem_noc_dirs_p-1:P] 
  cmd_link_li, cmd_link_lo, resp_link_li, resp_link_lo;
    
if (mem_noc_dims_p == 1)
  begin : mesh_1d
    for (genvar i = 0; i < num_core_p; i++)
      begin: wh_router
        bsg_wormhole_router
         #(.flit_width_p(mem_noc_flit_width_p)
           ,.dims_p(1)
           ,.cord_dims_p(mem_noc_max_dims_p)
           ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
           ,.len_width_p(mem_noc_len_width_p)
           )
         cmd_router
         (.clk_i(clk_i)
    	    ,.reset_i(reset_i)
     	    ,.my_cord_i(tile_cord_i[i])
          ,.link_i(cmd_link_li[i])
          ,.link_o(cmd_link_lo[i])
    	    );
      
        bsg_wormhole_router
         #(.flit_width_p(mem_noc_flit_width_p)
           ,.dims_p(mem_noc_dims_p)
           ,.cord_dims_p(mem_noc_max_dims_p)
           ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
           ,.len_width_p(mem_noc_len_width_p)
           )
         resp_router
          (.clk_i(clk_i)
    	     ,.reset_i(reset_i)
    	     ,.my_cord_i(tile_cord_i[i])
           ,.link_i(resp_link_li[i])
           ,.link_o(resp_link_lo[i])
    	     );
        
        // Link to next router
        if (i != num_core_p-1)
          begin : fi2
            assign cmd_link_li[i][E]   = cmd_link_lo[i+1][W];
            assign cmd_link_li[i+1][W] = cmd_link_lo[i][E];
    
            assign resp_link_li[i][E]   = resp_link_lo[i+1][W];
            assign resp_link_li[i+1][W] = resp_link_lo[i][E];
          end
      end

    // Connect end of chain to off-chip
    assign cmd_link_li[0][W]             = '0;
    assign cmd_link_li[num_core_p-1][E]  = cmd_link_i;
    assign cmd_link_o                    = cmd_link_lo[num_core_p-1][E];
    
    assign resp_link_li[0][W]            = '0;
    assign resp_link_li[num_core_p-1][E] = resp_link_i;
    assign resp_link_o                   = resp_link_lo[num_core_p-1][E];

    // Connect endpoints in core_complex
    for (genvar i = 0; i < num_core_p; i++)
      if ((i == mmio_x_pos_p))
        begin : conc
          // TODO: This could be more efficent if concentrator had num in and num out
          //         since one link on each is stubbed
          bsg_wormhole_concentrator
           #(.flit_width_p(mem_noc_flit_width_p)
             ,.len_width_p(mem_noc_len_width_p)
             ,.cid_width_p(mem_noc_cid_width_p)
             ,.num_in_p(2)
             ,.cord_width_p(mem_noc_cord_width_p)
             )
           cmd_concentrator
            (.clk_i(clk_i)
             ,.reset_i(reset_i)

             ,.links_i({mmio_cmd_link_lo, tile_cmd_link_lo[i]})
             ,.links_o({mmio_cmd_link_li, tile_cmd_link_li[i]})

             ,.concentrated_link_i(cmd_link_lo[i][P])
             ,.concentrated_link_o(cmd_link_li[i][P])
             );

          bsg_wormhole_concentrator
           #(.flit_width_p(mem_noc_flit_width_p)
             ,.len_width_p(mem_noc_len_width_p)
             ,.cid_width_p(mem_noc_cid_width_p)
             ,.num_in_p(2)
             ,.cord_width_p(mem_noc_cord_width_p)
             )
           resp_concentrator
            (.clk_i(clk_i)
             ,.reset_i(reset_i)

             ,.links_i({mmio_resp_link_lo, tile_resp_link_lo[i]})
             ,.links_o({mmio_resp_link_li, tile_resp_link_li[i]})

             ,.concentrated_link_i(resp_link_lo[i][P])
             ,.concentrated_link_o(resp_link_li[i][P])
             );
        end
      else
        begin : no_conc
          assign tile_cmd_link_li[i]  = cmd_link_lo[i][P];
          assign cmd_link_li[i][P]    = tile_cmd_link_lo[i];
          assign tile_resp_link_li[i] = resp_link_lo[i][P];
          assign resp_link_li[i][P]   = tile_resp_link_lo[i];
        end
  end
else
  begin : mesh_2d
    //synopsys translate_off
    $fatal("2d memory mesh not yet supported!");
    //synopsys translate_on
  end

endmodule


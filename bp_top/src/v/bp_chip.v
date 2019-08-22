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

bsg_ready_and_link_sif_s [num_core_p-1:0] cc_cmd_link_li, cc_cmd_link_lo;
bsg_ready_and_link_sif_s [num_core_p-1:0] cc_resp_link_li, cc_resp_link_lo;

bp_core_complex
 #(.cfg_p(cfg_p))
 cc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.tile_cord_i(tile_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.mmio_cord_i(mmio_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.cmd_link_i(cc_cmd_link_li)
   ,.cmd_link_o(cc_cmd_link_lo)

   ,.resp_link_i(cc_resp_link_li)
   ,.resp_link_o(cc_resp_link_lo)
   );

bp_io_complex
 #(.cfg_p(cfg_p))
 io
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.tile_cord_i(tile_cord_i)

   ,.cmd_link_i(cc_cmd_link_lo)
   ,.cmd_link_o(cc_cmd_link_li)

   ,.resp_link_i(cc_resp_link_lo)
   ,.resp_link_o(cc_resp_link_li)

   ,.io_cmd_link_i(cmd_link_i)
   ,.io_cmd_link_o(cmd_link_o)

   ,.io_resp_link_i(resp_link_i)
   ,.io_resp_link_o(resp_link_o)
   );   
   
endmodule


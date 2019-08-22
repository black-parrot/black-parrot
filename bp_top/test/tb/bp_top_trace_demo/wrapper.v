/**
 *
 * wrapper.v
 *
 */
 
`include "bsg_noc_links.vh"

module wrapper
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   ,localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0] tile_cord_i
   , input [mem_noc_cord_width_p-1:0]                 dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                 mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]                 host_cord_i

   , input  [mem_noc_ral_link_width_lp-1:0]           cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]           cmd_link_o

   , input  [mem_noc_ral_link_width_lp-1:0]           resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]           resp_link_o
   );

  //synopsys translate_off
  //if (coh_noc_dims_p != mem_noc_dims_p)
  //  $fatal("Coherence and memory networks should be same dimensionality!");
  //synopsys translate_on

  bp_chip
   #(.cfg_p(cfg_p))
   dut
    (.*);

endmodule


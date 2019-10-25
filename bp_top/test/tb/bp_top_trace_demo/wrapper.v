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
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   ,localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   , localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(vcache_addr_width_p)
   )
  (input                                              core_clk_i
   , input                                            core_reset_i

   , input                                            coh_clk_i
   , input                                            coh_reset_i

   , input                                            mem_clk_i
   , input                                            mem_reset_i

   , input [num_io_p-1:0][mem_noc_cord_width_p-1:0]   io_cord_i
   , input [num_mem_p-1:0][mem_noc_cord_width_p-1:0]  mem_cord_i
   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0] tile_cord_i
   , input [mem_noc_cord_width_p-1:0]                 dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                 clint_cord_i
   , input [mem_noc_cord_width_p-1:0]                 host_cord_i

   , input  [mem_noc_ral_link_width_lp-1:0]           prev_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]           prev_cmd_link_o

   , input  [mem_noc_ral_link_width_lp-1:0]           prev_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]           prev_resp_link_o

   , input  [mem_noc_ral_link_width_lp-1:0]           next_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]           next_cmd_link_o

   , input  [mem_noc_ral_link_width_lp-1:0]           next_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]           next_resp_link_o
   
   // TODO: DMC Channels
   , output logic [num_mem_p-1:0][bsg_cache_dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [num_mem_p-1:0] dma_pkt_v_o
   , input [num_mem_p-1:0] dma_pkt_yumi_i
     
   , input [num_mem_p-1:0][dword_width_p-1:0] dma_data_i
   , input [num_mem_p-1:0] dma_data_v_i
   , output logic [num_mem_p-1:0] dma_data_ready_o
     
   , output logic [num_mem_p-1:0][dword_width_p-1:0] dma_data_o
   , output logic [num_mem_p-1:0] dma_data_v_o
   , input [num_mem_p-1:0] dma_data_yumi_i
   );

  bp_processor
   #(.bp_params_p(bp_params_p))
   dut
    (.*);

endmodule


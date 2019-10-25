/**
 *
 * bp_processor.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_processor
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
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

   , input  [bsg_ready_and_link_sif_width_lp-1:0]     prev_cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]     prev_cmd_link_o

   , input  [bsg_ready_and_link_sif_width_lp-1:0]     prev_resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]     prev_resp_link_o

   , input  [bsg_ready_and_link_sif_width_lp-1:0]     next_cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]     next_cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]      next_resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]     next_resp_link_o

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

`declare_bp_cfg_bus_s(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);

logic [num_core_p-1:0] timer_irq_lo, soft_irq_lo, external_irq_lo;

bsg_ready_and_link_sif_s [S:N][mem_noc_x_dim_p-1:0] mem_cmd_link_li, mem_cmd_link_lo;
bsg_ready_and_link_sif_s [S:N][mem_noc_x_dim_p-1:0] mem_resp_link_li, mem_resp_link_lo;

bp_core_complex
 #(.bp_params_p(bp_params_p))
 cc
  (.core_clk_i(core_clk_i)
   ,.core_reset_i(core_reset_i)

   ,.coh_clk_i(coh_clk_i)
   ,.coh_reset_i(coh_reset_i)

   ,.mem_clk_i(mem_clk_i)
   ,.mem_reset_i(mem_reset_i)

   ,.tile_cord_i(tile_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.clint_cord_i(clint_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.timer_irq_i(timer_irq_lo)
   ,.soft_irq_i(soft_irq_lo)
   ,.external_irq_i(external_irq_lo)

   ,.mem_cmd_link_i(mem_cmd_link_li)
   ,.mem_cmd_link_o(mem_cmd_link_lo)

   ,.mem_resp_link_i(mem_resp_link_li)
   ,.mem_resp_link_o(mem_resp_link_lo)
   );

bp_io_complex
 #(.bp_params_p(bp_params_p))
 ioc
  (.core_clk_i(core_clk_i)
   ,.core_reset_i(core_reset_i)

   ,.mem_clk_i(mem_clk_i)
   ,.mem_reset_i(mem_reset_i)

   ,.io_cord_i(io_cord_i)

   ,.timer_irq_o(timer_irq_lo)
   ,.soft_irq_o(soft_irq_lo)
   ,.external_irq_o(external_irq_lo)

   ,.mem_cmd_link_i(mem_cmd_link_lo[N])
   ,.mem_cmd_link_o(mem_cmd_link_li[N])

   ,.mem_resp_link_i(mem_resp_link_lo[N])
   ,.mem_resp_link_o(mem_resp_link_li[N])

   ,.prev_cmd_link_i(prev_cmd_link_i)
   ,.prev_cmd_link_o(prev_cmd_link_o)

   ,.next_cmd_link_i(next_cmd_link_i)
   ,.next_cmd_link_o(next_cmd_link_o)

   ,.prev_resp_link_i(prev_resp_link_i)
   ,.prev_resp_link_o(prev_resp_link_o)

   ,.next_resp_link_i(next_resp_link_i)
   ,.next_resp_link_o(next_resp_link_o)
   );

bp_mem_complex
 #(.bp_params_p(bp_params_p))
 mc
  (.core_clk_i(core_clk_i)
   ,.core_reset_i(core_reset_i)

   ,.mem_clk_i(mem_clk_i)
   ,.mem_reset_i(mem_reset_i)
   
   ,.mem_cord_i(mem_cord_i)

   ,.mem_cmd_link_i(mem_cmd_link_lo[S])
   ,.mem_cmd_link_o(mem_cmd_link_li[S])

   ,.mem_resp_link_i(mem_resp_link_lo[S])
   ,.mem_resp_link_o(mem_resp_link_li[S])

   // TODO: DMC Channels
   ,.dma_pkt_o(dma_pkt_o)
   ,.dma_pkt_v_o(dma_pkt_v_o)
   ,.dma_pkt_yumi_i(dma_pkt_yumi_i)
   
   ,.dma_data_i(dma_data_i)
   ,.dma_data_v_i(dma_data_v_i)
   ,.dma_data_ready_o(dma_data_ready_o)
   
   ,.dma_data_o(dma_data_o)
   ,.dma_data_v_o(dma_data_v_o)
   ,.dma_data_yumi_i(dma_data_yumi_i)
   );

endmodule


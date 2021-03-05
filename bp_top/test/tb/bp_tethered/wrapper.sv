/**
 *
 * wrapper.sv
 *
 */

`include "bsg_noc_links.vh"

module wrapper
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
   )
  (input                                                 clk_i
   , input                                               reset_i

   // Outgoing I/O
   , output [cce_mem_msg_width_lp-1:0]                   io_cmd_o
   , output                                              io_cmd_v_o
   , input                                               io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                    io_resp_i
   , input                                               io_resp_v_i
   , output                                              io_resp_yumi_o

   // Incoming I/O
   , input [cce_mem_msg_width_lp-1:0]                    io_cmd_i
   , input                                               io_cmd_v_i
   , output                                              io_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]                   io_resp_o
   , output                                              io_resp_v_o
   , input                                               io_resp_ready_i

   // DRAM interface
   , output logic [cc_x_dim_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [cc_x_dim_p-1:0]                       dma_pkt_v_o
   , input [cc_x_dim_p-1:0]                              dma_pkt_yumi_i

   , input [cc_x_dim_p-1:0][dword_width_gp-1:0]          dma_data_i
   , input [cc_x_dim_p-1:0]                              dma_data_v_i
   , output logic [cc_x_dim_p-1:0]                       dma_data_ready_o

   , output logic [cc_x_dim_p-1:0][dword_width_gp-1:0]   dma_data_o
   , output logic [cc_x_dim_p-1:0]                       dma_data_v_o
   , input [cc_x_dim_p-1:0]                              dma_data_yumi_i
   );

  if (multicore_p)
    begin : multicore
      $error("Not currently supported");
    end
  else
    begin : unicore
      bp_unicore
       #(.bp_params_p(bp_params_p))
       dut
        (.*);
    end

endmodule


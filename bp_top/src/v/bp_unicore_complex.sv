/**
 *
 * wrapper.sv
 *
 */

`include "bsg_noc_links.vh"

module bp_unicore_complex
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
   )
  (input                                                     clk_i
   , input                                                   reset_i

   , input [io_noc_did_width_p-1:0]                          my_did_i
   , input [io_noc_did_width_p-1:0]                          host_did_i

   // Outgoing I/O
   , output logic [uce_mem_msg_header_width_lp-1:0]          io_cmd_header_o
   , output logic [uce_mem_data_width_lp-1:0]                io_cmd_data_o
   , output logic                                            io_cmd_v_o
   , input                                                   io_cmd_ready_and_i
   , output logic                                            io_cmd_last_o

   , input [uce_mem_msg_header_width_lp-1:0]                 io_resp_header_i
   , input [uce_mem_data_width_lp-1:0]                       io_resp_data_i
   , input                                                   io_resp_v_i
   , output logic                                            io_resp_ready_and_o
   , input                                                   io_resp_last_i

   // Incoming I/O
   , input [uce_mem_msg_header_width_lp-1:0]                 io_cmd_header_i
   , input [uce_mem_data_width_lp-1:0]                       io_cmd_data_i
   , input                                                   io_cmd_v_i
   , output logic                                            io_cmd_ready_and_o
   , input                                                   io_cmd_last_i

   , output logic [uce_mem_msg_header_width_lp-1:0]          io_resp_header_o
   , output logic [uce_mem_data_width_lp-1:0]                io_resp_data_o
   , output logic                                            io_resp_v_o
   , input                                                   io_resp_ready_and_i
   , output logic                                            io_resp_last_o

   // DRAM interface
   , output logic [num_core_p-1:0][dma_pkt_width_lp-1:0]     dma_pkt_o
   , output logic [num_core_p-1:0]                           dma_pkt_v_o
   , input [num_core_p-1:0]                                  dma_pkt_yumi_i

   , input [num_core_p-1:0][l2_fill_width_p-1:0]             dma_data_i
   , input [num_core_p-1:0]                                  dma_data_v_i
   , output logic [num_core_p-1:0]                           dma_data_ready_and_o

   , output logic [num_core_p-1:0][l2_fill_width_p-1:0]      dma_data_o
   , output logic [num_core_p-1:0]                           dma_data_v_o
   , input [num_core_p-1:0]                                  dma_data_yumi_i
   );

  // Currently, this complex is flat, since we end up in a crossbar on top anyway
  for (genvar i = 0; i < cc_x_dim_p*cc_y_dim_p; i++)
    begin : c
      wire [coh_noc_cord_width_p-1:0] cord_li = {coh_noc_y_cord_width_p'(ic_y_dim_p+j)
                                                 ,coh_noc_x_cord_width_p'(sac_x_dim_p+i)
                                                 };
      bp_unicore
       #(.bp_params_p(bp_params_p))
       dut
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.my_did_i(my_did_i)
         ,.host_did_i(host_did_i)
         ,.my_cord_i(cord_li)

         ,.io_cmd_header_o(io_cmd_header_o[i])
         ,.io_cmd_data_o(io_cmd_data_o[i])
         ,.io_cmd_v_o(io_cmd_v_o[i])
         ,.io_cmd_ready_and_i(io_cmd_ready_and_i[i])
         ,.io_cmd_last_o(io_cmd_last_o[i])

         ,.io_resp_header_i(io_resp_header_i[i])
         ,.io_resp_data_i(io_resp_data_i[i])
         ,.io_resp_v_i(io_resp_v_i[i])
         ,.io_resp_ready_and_o(io_resp_ready_and_o[i])
         ,.io_resp_last_i(io_resp_last_i[i])

         ,.io_cmd_header_i(io_cmd_header_i[i])
         ,.io_cmd_data_i(io_cmd_data_i[i])
         ,.io_cmd_v_i(io_cmd_v_i[i])
         ,.io_cmd_ready_and_o(io_cmd_ready_and_o[i])
         ,.io_cmd_last_o(io_cmd_last_o[i])

         ,.io_resp_header_o(io_resp_header_o[i])
         ,.io_resp_data_o(io_resp_data_o[i])
         ,.io_resp_v_o(io_resp_v_o[i])
         ,.io_resp_ready_and_i(io_resp_ready_and_i[i])
         ,.io_resp_last_o(io_resp_last_o[i])

         ,.dma_pkt_o(dma_pkt_o[i])
         ,.dma_pkt_v_o(dma_pkt_v_o[i])
         ,.dma_pkt_yumi_i(dma_pkt_yumi_i[i])

         ,.dma_data_i(dma_data_i[i])
         ,.dma_data_v_i(dma_data_v_i[i])
         ,.dma_data_ready_and_o(dma_data_ready_and_o[i])

         ,.dma_data_o(dma_data_o[i])
         ,.dma_data_v_o(dma_data_v_o[i])
         ,.dma_data_yumi_i(dma_data_yumi_i[i])
         );
    end

endmodule


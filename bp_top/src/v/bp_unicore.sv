/**
 *
 * Name:
 *   bp_unicore.sv
 *
 * Description:
 *   This is the top level module for a unicore BlackParrot processor.
 *
 *   The unicore contains:
 *   - a BlackParrot processor core and devices (config, clint, CCE loopback) in bp_unicore_lite
 *   - L2 cache slice in bsg_cache
 *   - core to cache adapter in bp_me_cce_to_cache
 *
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.vh"
`include "bsg_noc_links.vh"

module bp_unicore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bp_top_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, uce)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)
   )
  (input                                                 clk_i
   , input                                               reset_i

   , input [io_noc_did_width_p-1:0]                      my_did_i
   , input [io_noc_did_width_p-1:0]                      host_did_i
   , input [coh_noc_cord_width_p-1:0]                    my_cord_i

   // Outgoing I/O
   , output logic [uce_mem_header_width_lp-1:0]          io_cmd_header_o
   , output logic [uce_fill_width_p-1:0]                 io_cmd_data_o
   , output logic                                        io_cmd_v_o
   , input                                               io_cmd_ready_and_i
   , output logic                                        io_cmd_last_o

   , input [uce_mem_header_width_lp-1:0]                 io_resp_header_i
   , input [uce_fill_width_p-1:0]                        io_resp_data_i
   , input                                               io_resp_v_i
   , output logic                                        io_resp_ready_and_o
   , input                                               io_resp_last_i

   // Incoming I/O
   , input [uce_mem_header_width_lp-1:0]                 io_cmd_header_i
   , input [uce_fill_width_p-1:0]                        io_cmd_data_i
   , input                                               io_cmd_v_i
   , output logic                                        io_cmd_ready_and_o
   , input                                               io_cmd_last_i

   , output logic [uce_mem_header_width_lp-1:0]          io_resp_header_o
   , output logic [uce_fill_width_p-1:0]                 io_resp_data_o
   , output logic                                        io_resp_v_o
   , input                                               io_resp_ready_and_i
   , output logic                                        io_resp_last_o

   // DRAM interface
   , output logic [l2_banks_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [l2_banks_p-1:0]                       dma_pkt_v_o
   , input [l2_banks_p-1:0]                              dma_pkt_ready_and_i

   , input [l2_banks_p-1:0][l2_fill_width_p-1:0]         dma_data_i
   , input [l2_banks_p-1:0]                              dma_data_v_i
   , output logic [l2_banks_p-1:0]                       dma_data_ready_and_o

   , output logic [l2_banks_p-1:0][l2_fill_width_p-1:0]  dma_data_o
   , output logic [l2_banks_p-1:0]                       dma_data_v_o
   , input [l2_banks_p-1:0]                              dma_data_ready_and_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, uce);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

  bp_bedrock_uce_mem_header_s mem_cmd_header_lo;
  logic [l2_data_width_p-1:0] mem_cmd_data_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_and_li, mem_cmd_last_lo;
  bp_bedrock_uce_mem_header_s mem_resp_header_li;
  logic [l2_data_width_p-1:0] mem_resp_data_li;
  logic mem_resp_v_li, mem_resp_ready_and_lo, mem_resp_last_li;
  bp_unicore_lite
   #(.bp_params_p(bp_params_p))
   unicore_lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.my_did_i(my_did_i)
     ,.host_did_i(host_did_i)
     ,.my_cord_i(my_cord_i)

     ,.mem_cmd_header_o(mem_cmd_header_lo)
     ,.mem_cmd_data_o(mem_cmd_data_lo)
     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_ready_and_i(mem_cmd_ready_and_li)
     ,.mem_cmd_last_o(mem_cmd_last_lo)

     ,.mem_resp_header_i(mem_resp_header_li)
     ,.mem_resp_data_i(mem_resp_data_li)
     ,.mem_resp_v_i(mem_resp_v_li)
     ,.mem_resp_ready_and_o(mem_resp_ready_and_lo)
     ,.mem_resp_last_i(mem_resp_last_li)

     // I/O
     ,.*
     );

  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   l2s
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(mem_cmd_header_lo)
     ,.mem_cmd_data_i(mem_cmd_data_lo)
     ,.mem_cmd_last_i(mem_cmd_last_lo)
     ,.mem_cmd_v_i(mem_cmd_v_lo)
     ,.mem_cmd_ready_and_o(mem_cmd_ready_and_li)

     ,.mem_resp_header_o(mem_resp_header_li)
     ,.mem_resp_data_o(mem_resp_data_li)
     ,.mem_resp_last_o(mem_resp_last_li)
     ,.mem_resp_v_o(mem_resp_v_li)
     ,.mem_resp_ready_and_i(mem_resp_ready_and_lo)

     ,.dma_pkt_o(dma_pkt_o)
     ,.dma_pkt_v_o(dma_pkt_v_o)
     ,.dma_pkt_ready_and_i(dma_pkt_ready_and_i)

     ,.dma_data_i(dma_data_i)
     ,.dma_data_v_i(dma_data_v_i)
     ,.dma_data_ready_and_o(dma_data_ready_and_o)

     ,.dma_data_o(dma_data_o)
     ,.dma_data_v_o(dma_data_v_o)
     ,.dma_data_ready_and_i(dma_data_ready_and_i)
     );

endmodule


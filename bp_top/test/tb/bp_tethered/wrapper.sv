/**
 *
 * wrapper.sv
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_noc_links.svh"

`ifndef BP_CFG_FLOWVAR
"BSG-ERROR BP_CFG_FLOWVAR must be set"
`endif

module wrapper
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = `BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p, l2_block_size_in_words_p)
   )
  (input                                                                clk_i
   , input                                                              reset_i

   , input [did_width_p-1:0]                                            my_did_i
   , input [did_width_p-1:0]                                            host_did_i

   , input [mem_fwd_header_width_lp-1:0]                                mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]                                   mem_fwd_data_i
   , input                                                              mem_fwd_v_i
   , output logic                                                       mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]                         mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]                            mem_rev_data_o
   , output logic                                                       mem_rev_v_o
   , input                                                              mem_rev_ready_and_i

   , output logic [mem_fwd_header_width_lp-1:0]                         mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]                            mem_fwd_data_o
   , output logic                                                       mem_fwd_v_o
   , input                                                              mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]                                mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]                                   mem_rev_data_i
   , input                                                              mem_rev_v_i
   , output logic                                                       mem_rev_ready_and_o

   , output logic [num_cce_p-1:0][l2_dmas_p-1:0][dma_pkt_width_lp-1:0]  dma_pkt_o
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0]                        dma_pkt_v_o
   , input [num_cce_p-1:0][l2_dmas_p-1:0]                               dma_pkt_ready_and_i

   , input [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0]          dma_data_i
   , input [num_cce_p-1:0][l2_dmas_p-1:0]                               dma_data_v_i
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0]                        dma_data_ready_and_o

   , output logic [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0]   dma_data_o
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0]                        dma_data_v_o
   , input [num_cce_p-1:0][l2_dmas_p-1:0]                               dma_data_ready_and_i
   );

  wire core_clk = clk_i;
  logic rt_clk;
  bsg_counter_clock_downsample
   #(.width_p(3))
   ds
    (.clk_i(core_clk)
     ,.reset_i(reset_i)
     ,.val_i('1)
     ,.clk_r_o(rt_clk)
     );

  bp_processor
   #(.bp_params_p(bp_params_p))
   processor
    (.clk_i(core_clk)
     ,.rt_clk_i(rt_clk)
     ,.*
     );

endmodule


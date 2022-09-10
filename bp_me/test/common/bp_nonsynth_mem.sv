
/**
 * bp_nonsynth_mem.v
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_cache.vh"

module bp_nonsynth_mem
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter preload_mem_p = 0
   , parameter mem_bytes_p = 0
   , parameter dram_type_p = ""
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [mem_header_width_lp-1:0]                mem_cmd_header_i
   , input [l2_data_width_p-1:0]                    mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , output logic                                   mem_cmd_ready_and_o
   , input                                          mem_cmd_last_i

   , output logic [mem_header_width_lp-1:0]         mem_resp_header_o
   , output logic [l2_data_width_p-1:0]             mem_resp_data_o
   , output logic                                   mem_resp_v_o
   , input                                          mem_resp_ready_and_i
   , output logic                                   mem_resp_last_o

   , input                                          dram_clk_i
   , input                                          dram_reset_i
   );

  `declare_bsg_cache_dma_pkt_s(daddr_width_p);
  bsg_cache_dma_pkt_s [l2_banks_p-1:0] dma_pkt_lo;
  logic [l2_banks_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [l2_banks_p-1:0] dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [l2_banks_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(mem_cmd_header_i)
     ,.mem_cmd_data_i(mem_cmd_data_i)
     ,.mem_cmd_v_i(mem_cmd_v_i)
     ,.mem_cmd_ready_and_o(mem_cmd_ready_and_o)
     ,.mem_cmd_last_i(mem_cmd_last_i)

     ,.mem_resp_header_o(mem_resp_header_o)
     ,.mem_resp_data_o(mem_resp_data_o)
     ,.mem_resp_v_o(mem_resp_v_o)
     ,.mem_resp_ready_and_i(mem_resp_ready_and_i)
     ,.mem_resp_last_o(mem_resp_last_o)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_ready_and_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_and_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_ready_and_i(dma_data_yumi_li)
     );

  bp_nonsynth_dram
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(preload_mem_p)
     ,.dram_type_p(dram_type_p)
     ,.mem_bytes_p(mem_bytes_p)
     ,.num_dma_p(l2_banks_p)
     )
   dram
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_and_i(dma_data_ready_and_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

endmodule


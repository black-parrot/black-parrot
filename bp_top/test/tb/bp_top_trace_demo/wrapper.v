/**
 *
 * wrapper.v
 *
 */
 
`include "bsg_noc_links.vh"

module wrapper
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(cfg_p)
   , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)

   , parameter calc_trace_p = 0
   , parameter cce_trace_p = 0
   
   ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   )
  (input                                       clk_i
   , input                                     reset_i

   , input [num_core_p-1:0][noc_cord_width_p-1:0] tile_cord_i
   , input [noc_cord_width_p-1:0]                 dram_cord_i
   , input [noc_cord_width_p-1:0]                 clint_cord_i

   , input  [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input  [bsg_ready_and_link_sif_width_lp-1:0] resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );

  bp_chip
   #(.cfg_p(cfg_p)
     ,.calc_trace_p(calc_trace_p)
     ,.cce_trace_p(cce_trace_p)
     )
   dut
    (.*);

endmodule : wrapper


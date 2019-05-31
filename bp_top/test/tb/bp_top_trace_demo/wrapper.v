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
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , parameter calc_trace_p = 0
   , parameter cce_trace_p = 0
   
   ,parameter width_p = "inv"
   ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

    ,input [bsg_ready_and_link_sif_width_lp-1:0]              link_i
    ,output [bsg_ready_and_link_sif_width_lp-1:0]             link_o

   , input [num_core_p-1:0]                                   external_irq_i
  );

  bp_top
   #(.cfg_p(cfg_p)
     ,.calc_trace_p(calc_trace_p)
     ,.cce_trace_p(cce_trace_p)
     ,.width_p(width_p)
     )
   dut
    (.*);

endmodule : wrapper


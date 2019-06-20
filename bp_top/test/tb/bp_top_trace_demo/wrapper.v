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
   
   // FIXME: not needed when IO complex is used
   , localparam link_width_lp = noc_width_p+2
   
   ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // channel tunnel interface
   , input [link_width_lp-1:0] multi_data_i
   , input multi_v_i
   , output multi_yumi_o
   
   , output [link_width_lp-1:0] multi_data_o
   , output multi_v_o
   , input multi_yumi_i
   );

  bp_multi_top
   #(.cfg_p(cfg_p)
     ,.calc_trace_p(calc_trace_p)
     ,.cce_trace_p(cce_trace_p)
     )
   dut
    (.*);

endmodule : wrapper


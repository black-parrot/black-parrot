`timescale 1ps/1ps

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

`ifndef BP_COMMON_FE_BE_IF_VH
`define BP_COMMON_FE_BE_IF_VH
`include "bp_common_fe_be_if.vh"
`endif

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH
`include "bp_fe_pc_gen.vh"
`endif

`ifndef BP_FE_ITLB_VH
`define BP_FE_ITLB_VH
`include "bp_fe_itlb.vh"
`endif

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH
`include "bp_fe_icache.vh"
`endif

//import bp_common_pkg::*;
//import itlb_pkg::*;
//import pc_gen_pkg::*;

module tb
#(
parameter vaddr_width_p          ="inv"
,parameter paddr_width_p         ="inv"
,parameter eaddr_width_p         ="inv"
,parameter data_width_p          ="inv"
,parameter inst_width_p          ="inv"
,parameter lce_sets_p            ="inv"
,parameter lce_assoc_p           ="inv"
,parameter tag_width_p           ="inv"
,parameter coh_states_p          ="inv"
,parameter num_cce_p             ="inv"
,parameter num_lce_p             ="inv"
,parameter lce_id_p              ="inv"
,parameter block_size_in_bytes_p ="inv"
);

logic clk_i;
logic reset_i;

// clock gen
bsg_nonsynth_clock_gen #(
  .cycle_time_p(10)
) clk_gen (
  .o(clk_i)
);

// reset gen
bsg_nonsynth_reset_gen #(
  .num_clocks_p(1)
  ,.reset_cycles_lo_p(4)
  ,.reset_cycles_hi_p(4)
) reset_gen (
  .clk_i(clk_i)
  ,.async_reset_o(reset_i)
);

bp_fe_top_wrapper
#(
.vaddr_width_p(vaddr_width_p)
,.paddr_width_p(paddr_width_p)
,.eaddr_width_p(eaddr_width_p)
,.data_width_p(data_width_p)
,.inst_width_p(inst_width_p)
,.lce_sets_p(lce_sets_p)
,.lce_assoc_p(lce_assoc_p)
,.tag_width_p(tag_width_p)
,.coh_states_p(coh_states_p)
,.num_cce_p(num_cce_p)
,.num_lce_p(num_lce_p)
,.lce_id_p(lce_id_p)
,.block_size_in_bytes_p(block_size_in_bytes_p)
) bp_fe_top_wrapper_1 (
.clk_i(clk_i)
,.reset_i(reset_i)
);
endmodule

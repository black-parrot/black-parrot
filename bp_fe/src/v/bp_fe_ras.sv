/*
 * bp_fe_ras.v
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_ras
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam num_entries_lp = ras_num_entries
   )
  (input                         clk_i
   , input                       reset_i

   , input logic push_pc_v_i
   , input logic push_pc_i,

   , input logic pop_pc_ready_and_i
   , output logic [vaddr_width_p-1:0] pop_pc_o
   , output logic pop_pc_v_o
   );

   logic [0:num_entries_lp][vaddr_width_p-1:0] ras_entries;

   assign pop_pc_o = ras_entries[0];
   assign pop_pc_v_o = 

endmodule
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
   )
  (  input        clk_i
   , input        reset_i

   , input logic  push_pc_v_i
   , input logic  [vaddr_width_p-1:0] push_pc_i

   , input logic  pop_pc_ready_and_i
   , output logic [vaddr_width_p-1:0] pop_pc_o
   , output logic pop_pc_v_o
   );

  // typedef struct packed
  // {
  //   logic                       v;
  //   logic [vaddr_width_p-1:0]   tgt;
  // } bp_ras_entry_s;

  // TODO: clear entries on reset
  logic [0:ras_num_entries_p-1][vaddr_width_p-1:0] ras_entries;
  logic [`BSG_WIDTH(ras_num_entries_p)-1:0] ras_num_valid_entries_r;

  assign pop_pc_o = ras_entries[0];
  assign pop_pc_v_o = ras_num_valid_entries_r != 0;

  wire is_pop = pop_pc_v_o & pop_pc_ready_and_i;
  wire is_push = push_pc_v_i;

  always_ff @(posedge clk_i) begin
    if (reset_i)
      begin
        ras_entries             <= '0;
        ras_num_valid_entries_r <= 0;
      end
    else if (is_push && !is_pop)
      begin
        ras_entries             <= { push_pc_i, ras_entries[0:ras_num_entries_p-2] };
        ras_num_valid_entries_r <= ras_num_valid_entries_r + 1;
      end
    else if (!is_push && is_pop)
      begin
        if (ras_num_valid_entries_r <= 1)
          ras_entries <= ras_entries;
        else
          ras_entries             <= { ras_entries[1:ras_num_entries_p-1], vaddr_width_p'('0) };
        ras_num_valid_entries_r <= ras_num_valid_entries_r - 1;
      end
    else if (is_push && is_pop)
      begin
        ras_entries             <= { push_pc_i, ras_entries[1:ras_num_entries_p-1] };
        ras_num_valid_entries_r <= ras_num_valid_entries_r;
      end
    else
      begin
        ras_entries             <= ras_entries;
        ras_num_valid_entries_r <= ras_num_valid_entries_r;
      end
  end
endmodule

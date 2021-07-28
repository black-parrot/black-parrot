/*
 * bp_fe_ras.v
 *
 * A configurable-depth Return Address Stack, with support for checkpointing of
 * the "top" pointer to restore upon misspeculation.
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_ras
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam ras_num_entries_lp = 2**ras_idx_width_p
   )
  (  input        clk_i
   , input        reset_i

   , input logic  push_pc_en_i
   , input logic  [vaddr_width_p-1:0] push_pc_i

   , input logic  pop_pc_en_i
   , output logic [vaddr_width_p-1:0] pop_pc_o

   , output logic [ras_idx_width_p] ckpt_top_ptr_o

   , input logic restore_ckpt_v_i
   , input logic [ras_idx_width_p] restore_ckpt_top_ptr_i
   );

  // Stack top pointer
  // we can't use bsg_circular_ptr because we need to be able to a) decrement the pointer and b) checkpoint the pointer.
  // top_ptr_r points to the current topmost element on the stack.
  logic [ras_idx_width_p-1:0] top_ptr_r, top_ptr_n;

  bsg_dff
    #(.width_p(ras_idx_width_p))
    top_ptr_reg
      (.clk_i(clk_i)

      ,.data_i(top_ptr_n)
      ,.data_o(top_ptr_r)
      );

  wire is_pop  = pop_pc_en_i;
  wire is_push = push_pc_en_i;

  logic [ras_num_entries_lp-1:0][vaddr_width_p-1:0] ras_entries;

  assign ckpt_top_ptr_o = top_ptr_r;
  assign pop_pc_o = ras_entries[top_ptr_r];

  always_ff @(posedge clk_i)
    begin
      ras_entries <= ras_entries;
      if (reset_i)
        ras_entries <= '0;
      else if (is_push && !restore_ckpt_v_i)
        ras_entries[top_ptr_n] <= push_pc_i;
    end

  always_comb
    begin
      if (reset_i)
        // Reset to 0 will mean index 1 is the first entry pushed. Not natural to read in simulation,
        // but the initial redirect packet on start will overwrite this to zero anyway.
        top_ptr_n = 0;
      else if (restore_ckpt_v_i)
        top_ptr_n = restore_ckpt_top_ptr_i;
      else
        top_ptr_n = top_ptr_r + is_push - is_pop;
    end
endmodule

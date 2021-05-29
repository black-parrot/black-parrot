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

   , output logic init_done_o

   , input logic  push_pc_en_i
   , input logic  [vaddr_width_p-1:0] push_pc_i

   , input logic  pop_pc_en_i
   , output logic [vaddr_width_p-1:0] pop_pc_o

   , output logic [ras_idx_width_p] ckpt_top_ptr_o

   , input logic restore_ckpt_v_i
   , input logic [ras_idx_width_p] restore_ckpt_top_ptr_i
   );

  // Initialization (zeroing) logic
  // Not necessary for proper operation in hardware, but prevents X propagation in sim
  logic [ras_idx_width_p-1:0] init_ptr;
  wire finished_init_n = (init_ptr == ras_num_entries_lp - 1);
  logic finished_init_r;
  bsg_counter_clear_up
    #(.max_val_p(ras_num_entries_lp-1), .init_val_p(0))
    init_counter
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.clear_i(1'b0)
      ,.up_i(!finished_init_n)
      ,.count_o(init_ptr)
      );

  bsg_dff
    #(.width_p(1))
    finished_init_reg
      (.clk_i(clk_i)

      ,.data_i(finished_init_n)
      ,.data_o(finished_init_r)
      );

  assign init_done_o = finished_init_r;

  // Stack top pointer
  // we can't use bsg_circular_ptr because we need to be able to a) decrement the pointer and b) checkpoint the pointer.
  // top_ptr_r points to the current topmost element on the stack.
  logic [ras_idx_width_p-1:0] top_ptr_r, top_ptr_n;

  assign ckpt_top_ptr_o = top_ptr_r;

  bsg_dff
    #(.width_p(ras_idx_width_p))
    top_ptr_reg
      (.clk_i(clk_i)

      ,.data_i(top_ptr_n)
      ,.data_o(top_ptr_r)
      );

  wire is_pop  = pop_pc_en_i;
  wire is_push = push_pc_en_i;

  // RAS memory
  logic mem_w_v_li;
  logic [ras_idx_width_p-1:0] mem_w_addr_li;
  logic [vaddr_width_p-1:0] mem_w_data_li;
  bsg_mem_1r1w
    #(.width_p(vaddr_width_p)
      ,.els_p(ras_num_entries_lp)
      ,.read_write_same_addr_p(1)
     )
    ras_mem
     (.w_clk_i(clk_i)
      ,.w_reset_i(reset_i)

      ,.w_v_i(mem_w_v_li)
      ,.w_addr_i(mem_w_addr_li)
      ,.w_data_i(mem_w_data_li)

      ,.r_v_i(init_done_o)
      ,.r_addr_i(top_ptr_r)
      ,.r_data_o(pop_pc_o)
      );

  always_comb begin
    if (reset_i)
      begin
        // Reset to 0 will mean index 1 is the first entry pushed. Not natural to read in simulation,
        // but the initial redirect packet on start will overwrite this to zero anyway.
        top_ptr_n = 0;

        mem_w_v_li    = 1'b0;
        mem_w_addr_li = '0;
        mem_w_data_li = '0;
      end
    else if (!init_done_o)
      begin
        top_ptr_n = top_ptr_r;

        mem_w_v_li    = 1'b1;
        mem_w_addr_li = init_ptr;
        mem_w_data_li = '0;
      end
    else if (restore_ckpt_v_i)
      begin
        top_ptr_n = restore_ckpt_top_ptr_i;

        mem_w_v_li    = 1'b0;
        mem_w_addr_li = '0;
        mem_w_data_li = '0;
      end
    else
      begin
        top_ptr_n = top_ptr_r + is_push - is_pop;

        mem_w_v_li    = is_push;
        mem_w_addr_li = top_ptr_n;
        mem_w_data_li = push_pc_i;
      end
  end
endmodule

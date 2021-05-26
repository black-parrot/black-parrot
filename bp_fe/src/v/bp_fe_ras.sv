/*
 * bp_fe_ras.v
 *
 * A configurable-depth Return Address Stack, with support for checkpointing of
 * the "top" pointer and topmost element.
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_ras
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   ,localparam ptr_width_lp = `BSG_WIDTH(ras_num_entries_p-1)
   )
  (  input        clk_i
   , input        reset_i

   , input logic  push_pc_en_i
   , input logic  [vaddr_width_p-1:0] push_pc_i

   , input logic  pop_pc_en_i
   , output logic [vaddr_width_p-1:0] pop_pc_o

   , output logic [ptr_width_lp] ckpt_top_ptr_o

   , input logic restore_ckpt_v_i
   , input logic [ptr_width_lp] restore_ckpt_top_ptr_i
   , input logic [vaddr_width_p-1:0] restore_ckpt_top_pc_i
   );

  //synopsys translate_off
  initial begin
    assert(`BSG_IS_POW2(ras_num_entries_p))
      else $error("Number of entries in the RAS must be a power of two");
  end
  //synopsys translate_on

  // we can't use bsg_circular_ptr because we need to be able to a) decrement the pointer and b) checkpoint the pointer.
  // top_ptr_r points to the current topmost element on the stack.
  logic [ptr_width_lp-1:0] top_ptr_r, top_ptr_n;

  assign ckpt_top_ptr_o = top_ptr_r;

  bsg_dff
   #(.width_p(ptr_width_lp))
   top_ptr_reg
    (.clk_i(clk_i)

     ,.data_i(top_ptr_n)
     ,.data_o(top_ptr_r)
     );

  wire is_pop  = pop_pc_en_i;
  wire is_push = push_pc_en_i;

  // TODO: zero out all entries on reset?
  bsg_mem_1r1w
    #(.width_p(vaddr_width_p)
      ,.els_p(ras_num_entries_p)
      ,.read_write_same_addr_p(1)
     )
    ras_mem
     (.w_clk_i(clk_i)
      ,.w_reset_i(reset_i)

      ,.w_v_i(is_push || restore_ckpt_v_i)
      ,.w_addr_i(top_ptr_n)
      ,.w_data_i(restore_ckpt_v_i ? restore_ckpt_top_pc_i : push_pc_i)

      ,.r_v_i(1'b1)
      ,.r_addr_i(top_ptr_r)
      ,.r_data_o(pop_pc_o)
      );

  always_comb begin
    if (reset_i)
      // reset to end of memory for readability in sim; first pushed element will be at address 0
      // TODO: there's a redirect immediately on start which overwrites this to 0
      top_ptr_n = ras_num_entries_p-1;
    else if (restore_ckpt_v_i)
      top_ptr_n = restore_ckpt_top_ptr_i;
    else
      top_ptr_n = top_ptr_r + is_push - is_pop;
  end
endmodule

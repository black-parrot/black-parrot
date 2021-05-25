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

   ,localparam ptr_width_lp = `BSG_WIDTH(ras_num_entries_p-1)
   )
  (  input        clk_i
   , input        reset_i

   , input logic  push_pc_v_i
   , input logic  [vaddr_width_p-1:0] push_pc_i

   , input logic  pop_pc_ready_and_i
   , output logic [vaddr_width_p-1:0] pop_pc_o
   , output logic pop_pc_v_o
   );

  //synopsys translate_off
  initial begin
    assert(`BSG_IS_POW2(ras_num_entries_p))
      else $error("Number of entries in the RAS must be a power of two");
  end
  //synopsys translate_on

  // we can't use bsg_circular_ptr because we need to be able to a) decrement the pointer and b) checkpoint the pointer.
  // top_ptr_r points to the current element on the top of the stack.
  logic [ptr_width_lp-1:0] num_valid_entries_r, num_valid_entries_n, top_ptr_r, top_ptr_n;

  bsg_dff
   #(.width_p(ptr_width_lp))
   num_valid_entries_reg
    (.clk_i(clk_i)

     ,.data_i(num_valid_entries_n)
     ,.data_o(num_valid_entries_r)
     );

  bsg_dff
   #(.width_p(ptr_width_lp))
   top_ptr_reg
    (.clk_i(clk_i)

     ,.data_i(top_ptr_n)
     ,.data_o(top_ptr_r)
     );

  assign pop_pc_v_o = num_valid_entries_r != 0;

  wire is_pop = pop_pc_v_o & pop_pc_ready_and_i;
  wire is_push = push_pc_v_i;

  // TODO: zero out top value on reset?
  // TODO: implement checkpointing
  bsg_mem_1r1w
    #(.width_p(vaddr_width_p)
      ,.els_p(ras_num_entries_p)
      ,.read_write_same_addr_p(1)
     )
    ras_mem
     (.w_clk_i(clk_i)
      ,.w_reset_i(reset_i)

      ,.w_v_i(is_push)
      ,.w_addr_i(top_ptr_n)
      ,.w_data_i(push_pc_i)

      ,.r_v_i(pop_pc_ready_and_i)
      ,.r_addr_i(top_ptr_r)
      ,.r_data_o(pop_pc_o)
      );

  always_comb begin
    if (reset_i)
      begin
        num_valid_entries_n = '0;
        // reset to end of memory for readability in sim; first pushed element will be at address 0
        top_ptr_n           = ras_num_entries_p-1;
      end
    else
      begin
        if (num_valid_entries_r == ras_num_entries_p && is_push && !is_pop)
          // saturate num_valid_entries_r if we're pushing more elements than capacity
          num_valid_entries_n = num_valid_entries_r;
        else
          num_valid_entries_n = num_valid_entries_r + is_push - is_pop;
        top_ptr_n             = top_ptr_r + is_push - is_pop;
      end
  end
endmodule

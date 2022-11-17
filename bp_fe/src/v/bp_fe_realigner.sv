/*
 * bp_fe_realigner.sv
 *
 * 32-bit I$ output buffer which reconstructs 32-bit instructions fetched as two halves.
 * Passes through the input data unmodified when the fetch is aligned.
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_realigner
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
 )
  (input                             clk_i
   , input                           reset_i

   // Fetch PC and I$ data
   , input                           if2_v_i
   , input [vaddr_width_p-1:0]       if2_pc_i
   , input [instr_width_gp-1:0]      if2_data_i
   , input                           if2_taken_branch_site_i

   // Redirection from backend
   //   and whether to restore the instruction data
   //   and PC to resume a fetch
   , input                           redirect_v_i
   , input                           redirect_resume_v_i
   , input [hinstr_width_gp-1:0]     redirect_instr_i
   , input [vaddr_width_p-1:0]       redirect_pc_i

   , output [vaddr_width_p-1:0]      fetch_pc_o
   , output [instr_width_gp-1:0]     fetch_instr_o
   , output                          fetch_instr_v_o
   , output                          fetch_partial_o
   , output                          fetch_linear_o
   , input                           fetch_instr_yumi_i
   );

  wire [hinstr_width_gp-1:0] icache_data_lower_half_li = if2_data_i[0                  +:hinstr_width_gp];
  wire [hinstr_width_gp-1:0] icache_data_upper_half_li = if2_data_i[hinstr_width_gp+:hinstr_width_gp];

  logic [vaddr_width_p-1:0] partial_pc_n, partial_pc_r;
  logic [hinstr_width_gp-1:0] partial_instr_n, partial_instr_r;
  logic partial_v_r;

  wire if2_pc_is_aligned  = `bp_addr_is_aligned(if2_pc_i, (instr_width_gp>>3));
  wire if2_store_v = if2_v_i &
    // Transition from aligned to misaligned
    ((~partial_v_r & ~if2_pc_is_aligned)
     // Continue misaligned to aligned/misaligned
     || (partial_v_r & ~if2_taken_branch_site_i)
     );

  wire [vaddr_width_p-1:0] redirect_pc_adjusted = redirect_pc_i - 2'b10;
  wire [vaddr_width_p-1:0] if2_pc_adjusted = (partial_v_r & if2_pc_is_aligned) ? (if2_pc_i + 2'b10) : if2_pc_i;
  wire [hinstr_width_gp-1:0] if2_data_lower = if2_data_i[0+:hinstr_width_gp];
  wire [hinstr_width_gp-1:0] if2_data_upper = if2_data_i[hinstr_width_gp+:hinstr_width_gp];
  bsg_mux
   #(.width_p(hinstr_width_gp+vaddr_width_p), .els_p(2))
   partial_mux
    (.data_i({{redirect_instr_i, redirect_pc_adjusted}, {if2_data_upper, if2_pc_adjusted}})
     ,.sel_i(redirect_v_i)
     ,.data_o({partial_instr_n, partial_pc_n})
     );

  wire partial_w_v = if2_store_v | redirect_v_i | fetch_instr_yumi_i;
  wire partial_v_n = (if2_store_v & ~redirect_v_i) | (redirect_v_i & redirect_resume_v_i);
  bsg_dff_reset_en
   #(.width_p(1))
   partial_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(partial_w_v)
     ,.data_i(partial_v_n)
     ,.data_o(partial_v_r)
     );

  bsg_dff_reset_en
   #(.width_p(hinstr_width_gp+vaddr_width_p))
   partial_instr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(partial_w_v)
     ,.data_i({partial_pc_n, partial_instr_n})
     ,.data_o({partial_pc_r, partial_instr_r})
     );

  wire [instr_width_gp-1:0] instr_assembled = {if2_data_lower, partial_instr_r};
  bsg_mux
   #(.width_p(instr_width_gp+vaddr_width_p), .els_p(2))
   fetch_mux
    (.data_i({{instr_assembled, partial_pc_r}, {if2_data_i, if2_pc_i}})
     ,.sel_i(partial_v_r)
     ,.data_o({fetch_instr_o, fetch_pc_o})
     );

  // Either completing a partial instruction or fetching aligned instruction
  assign fetch_instr_v_o = if2_v_i & (partial_v_r | if2_pc_is_aligned);
  // Force a linear fetch if we're storing in the realigner (need to complete instruction)
  //   or if we need to complete an instruction and are not currently completing an instruction
  assign fetch_linear_o  = if2_store_v;
  assign fetch_partial_o = partial_v_r;

endmodule


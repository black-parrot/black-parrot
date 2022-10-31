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
  (input   clk_i
   , input reset_i

   // Fetch PC and I$ data
   , input                       if2_v_i
   , input                       if2_yumi_i
   , input                       if2_taken_branch_site_i
   , input [vaddr_width_p-1:0]   if2_pc_i
   , input [instr_width_gp-1:0]  if2_data_i

   // Redirection from backend
   , input                           redirect_v_i
   // Whether to restore the instruction data
   , input                           redirect_resume_i
   , input [instr_half_width_gp-1:0] redirect_partial_i
   , input [vaddr_width_p-1:0]       redirect_vaddr_i

   , output [vaddr_width_p-1:0]  fetch_instr_pc_o
   , output [instr_width_gp-1:0] fetch_instr_o
   , output                      fetch_instr_v_o
   , output                      fetch_partial_o
   , output                      fetch_linear_o
   , input                       fetch_instr_yumi_i
   );

  wire [instr_half_width_gp-1:0] icache_data_lower_half_li = if2_data_i[0                  +:instr_half_width_gp];
  wire [instr_half_width_gp-1:0] icache_data_upper_half_li = if2_data_i[instr_half_width_gp+:instr_half_width_gp];

  logic [vaddr_width_p-1:0] fetch_instr_pc_n, fetch_instr_pc_r;
  logic [instr_half_width_gp-1:0] partial_n, partial_r;
  logic partial_v_r;

  wire if2_pc_is_aligned  = `bp_addr_is_aligned(if2_pc_i, rv64_instr_width_bytes_gp);

  wire fetch_store_v = if2_yumi_i &
    ((!fetch_partial_o && !if2_pc_is_aligned) || ( fetch_partial_o && !if2_taken_branch_site_i));

  assign fetch_instr_pc_n = (redirect_v_i & redirect_resume_i)
                            ? (redirect_vaddr_i - vaddr_width_p'(2))
                            : (partial_v_r & if2_pc_is_aligned)
                              ? (if2_pc_i + vaddr_width_p'(2))
                              : if2_pc_i;
  assign partial_n = redirect_resume_i ? redirect_partial_i : icache_data_upper_half_li;

  wire poison_li = redirect_v_i & ~redirect_resume_i;

  bsg_dff_reset_en
   #(.width_p(vaddr_width_p+instr_half_width_gp))
   partial_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i  (fetch_store_v | (redirect_v_i & redirect_resume_i))
     ,.data_i({fetch_instr_pc_n, partial_n})
     ,.data_o({fetch_instr_pc_r, partial_r})
     );

  bsg_dff_reset_set_clear
   #(.width_p(1))
   partial_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i  (~poison_li & fetch_store_v)
     ,.clear_i((redirect_v_i & ~redirect_resume_i) | fetch_instr_yumi_i) // set overrides clear
     ,.data_o (partial_v_r)
     );

  assign fetch_partial_o = partial_v_r;

  assign fetch_instr_v_o  = (partial_v_r | if2_pc_is_aligned) & if2_v_i;
  assign fetch_instr_pc_o = partial_v_r ? fetch_instr_pc_r : if2_pc_i;
  assign fetch_instr_o    = partial_v_r ? { icache_data_lower_half_li, partial_r } : if2_data_i;
  assign fetch_linear_o   = if2_v_i & fetch_store_v || (partial_v_r && !fetch_instr_v_o);

endmodule

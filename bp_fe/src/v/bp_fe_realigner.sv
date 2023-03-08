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
  (input                               clk_i
   , input                             reset_i

   // Fetch PC and I$ data
   , input                             if2_instr_v_i
   , input [vaddr_width_p-1:0]         if2_pc_i
   , input [instr_width_gp-1:0]        if2_data_i
   , input                             if2_taken_branch_site_i
   , output logic                      if2_yumi_o

   // Redirection from backend
   //   and whether to restore the instruction data
   //   and PC to resume a fetch
   , input                             redirect_v_i
   , input                             redirect_resume_v_i
   , input [vaddr_width_p-1:0]         redirect_pc_i
   , input [cinstr_width_gp-1:0]       redirect_instr_i
   , input [branch_metadata_fwd_width_p-1:0] redirect_br_metadata_fwd_i

   , output logic                      fetch_instr_v_o
   , output logic [vaddr_width_p-1:0]  fetch_pc_o
   , output logic [instr_width_gp-1:0] fetch_instr_o
   , output logic                      fetch_linear_o
   , output logic                      fetch_partial_o
   , output logic                      fetch_realign_o
   , output logic                      fetch_scan_o
   , output logic                      fetch_stall_o
   , output logic [1:0]                fetch_mask_o
   , output logic                      fetch_eager_o
   , input                             fetch_ready_and_i
   );

  logic partial_v_n, partial_v_r;
  logic [cinstr_width_gp-1:0] partial_instr_n, partial_instr_r;
  logic [vaddr_width_p-1:0] partial_pc_n, partial_pc_r;

  wire if2_pc_aligned = `bp_addr_is_aligned(if2_pc_i, (instr_width_gp>>3));
  wire [1:0] if2_compressed = ~{&if2_data_i[cinstr_width_gp+:2], &if2_data_i[0+:2]};

  wire [vaddr_width_p-1:0] redirect_partial_pc = redirect_pc_i - (redirect_resume_v_i ? 2'b10 : 2'b00);
  wire [vaddr_width_p-1:0] if2_partial_pc = if2_pc_i + (if2_pc_aligned ? 2'b10 : 2'b00);
  wire [cinstr_width_gp-1:0] if2_data_lower = if2_data_i[0+:cinstr_width_gp];
  wire [cinstr_width_gp-1:0] if2_data_upper = if2_data_i[cinstr_width_gp+:cinstr_width_gp];
  bsg_mux
   #(.width_p(cinstr_width_gp+vaddr_width_p), .els_p(2))
   redirect_mux
    (.data_i({{redirect_instr_i, redirect_partial_pc}, {if2_data_upper, if2_partial_pc}})
     ,.sel_i(redirect_v_i)
     ,.data_o({partial_instr_n, partial_pc_n})
     );

  wire if2_store_v = if2_yumi_o & fetch_linear_o;
  wire partial_w_v = if2_store_v | redirect_v_i | fetch_instr_v_o;
  assign partial_v_n = if2_store_v | redirect_resume_v_i;
  bsg_dff_reset_en
   #(.width_p(1+cinstr_width_gp+vaddr_width_p))
   partial_instr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(partial_w_v)
     ,.data_i({partial_v_n, partial_instr_n, partial_pc_n})
     ,.data_o({partial_v_r, partial_instr_r, partial_pc_r})
     );
  
  wire [instr_width_gp-1:0] instr_aligned = if2_pc_aligned ? if2_data_i : {if2_data_lower, if2_data_upper};
  wire [instr_width_gp-1:0] instr_assembled = {if2_data_lower, partial_instr_r};
  bsg_mux
   #(.width_p(instr_width_gp+vaddr_width_p), .els_p(2))
   instr_mux
    (.data_i({{instr_assembled, partial_pc_r}, {instr_aligned, if2_pc_i}})
     ,.sel_i(partial_v_r)
     ,.data_o({fetch_instr_o, fetch_pc_o})
     );

  // Here is a table of the possible cases:
  // partial_v  if2_aligned if2_comp[1] if2_comp[0] | fetch_mask fetch_eager fetch_linear fetch_stall fetch_realign fetch_scan |
  //     0           0          0           x       |    00           0           1            0            0            0     | 
  //     0           0          1           x       |    01           1           0            0            1            0     | 
  //     0           1          0           0       |    11           0           0            0            0            0     | 
  //     0           1          0           1       |    01           1         !if2_br        0            0            0     | 
  //     0           1          1           0       |    --           0           -            -            -            -     |
  //     0           1          1           1       |    11         !if2_br       0            0            0            0     | 
  //     1           x          0           0       |    11           0         !if2_br        0            0            0     |
  //     1           0          0           1       |    --           0           -            -            -            -     |
  //     1           0          1           0       |    11           0           0            1            0            0     |
  //     1           0          1           1       |    --           0           -            -            -            -     |
  //     1           1          0           1       |    --           0           -            -            -            -     |
  //     1           1          1           0       |    11           0           0            1            0            1     |
  //     1           1          1           1       |    --           0           -            -            -            -     |

  // Fetching at least one valid instruction
  assign fetch_instr_v_o = fetch_ready_and_i & if2_instr_v_i & (if2_pc_aligned | partial_v_r | if2_compressed[1]);
  assign fetch_partial_o = partial_v_r;
  // Force a linear fetch if we're storing in the realigner (need to complete instruction)
  assign fetch_linear_o = if2_instr_v_i &&
    // starting misaligned high
    ((~partial_v_r & ~if2_pc_aligned & ~if2_compressed[1])
     // starting misaligned after compressed
     || (~partial_v_r &  if2_pc_aligned &  if2_compressed[0] & ~if2_compressed[1] & ~if2_taken_branch_site_i)
     // continuing misaligned high
     || ( partial_v_r & ~if2_compressed[1] & ~if2_taken_branch_site_i));
  // Completing full instruction, still have compressed left
  assign fetch_realign_o = if2_instr_v_i & ~partial_v_r & ~if2_pc_aligned & if2_compressed[1] & ~if2_taken_branch_site_i;
  // Adjust the IF2 PC up to catchup after completing a misaligned instruction 
  assign fetch_scan_o = if2_instr_v_i & partial_v_r & if2_compressed[1] & if2_pc_aligned & ~if2_taken_branch_site_i;
  // Stall the pipeline to keep the same I$ data
  assign fetch_stall_o = if2_instr_v_i & partial_v_r & if2_compressed[1] & ~if2_taken_branch_site_i;
  // Eagerly fetch a low or high compressed instruction
  assign fetch_eager_o = (~partial_v_r & ~if2_pc_aligned & if2_compressed[1])
                         || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & ~if2_compressed[1])
                         // This messes up for {compressed branch, compressed}, saying eager even
                         // though we have fetched two instructions, one of which is a branch
                         || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & if2_taken_branch_site_i);
  assign fetch_mask_o[0] = partial_v_r | if2_pc_aligned | if2_compressed[0] | if2_compressed[1];
  assign fetch_mask_o[1] = partial_v_r | (if2_pc_aligned & ~if2_compressed[0] & ~if2_compressed[1]) | (if2_pc_aligned & if2_compressed[0] & if2_compressed[1]);

  assign if2_yumi_o = fetch_ready_and_i & if2_instr_v_i & ~fetch_stall_o;

endmodule



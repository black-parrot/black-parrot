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
  (input                                                     clk_i
   , input                                                   reset_i

   // Fetch PC and I$ data
   , input                                                   if2_v_i
   , input [vaddr_width_p-1:0]                               if2_pc_i
   , input [instr_width_gp-1:0]                              if2_data_i
   , input [branch_metadata_fwd_width_p-1:0]                 if2_br_metadata_fwd_i
   , output logic                                            if2_yumi_o

   // Redirection from backend
   //   and whether to restore the instruction data
   //   and PC to resume a fetch
   , input                                                   redirect_v_i
   , input                                                   redirect_resume_i
   , input [cinstr_width_gp-1:0]                             redirect_instr_i
   , input [vaddr_width_p-1:0]                               redirect_pc_i
   , input [branch_metadata_fwd_width_p-1:0]                 redirect_br_metadata_fwd_i

   // Assembled instruction, PC and count
   , output logic                                            assembled_v_o
   , output logic [vaddr_width_p-1:0]                        assembled_pc_o
   , output logic [fetch_cinstr_gp  :0][cinstr_width_gp-1:0] assembled_instr_o
   , output logic [branch_metadata_fwd_width_p-1:0]          assembled_br_metadata_fwd_o
   , output logic [fetch_ptr_gp-1:0]                         assembled_count_o
   , input [fetch_ptr_gp-1:0]                                assembled_count_i
   , output logic                                            assembled_partial_o
   , input                                                   assembled_yumi_i

   , output logic                                            fetch_linear_o
   , output logic                                            fetch_catchup_o
   , input                                                   fetch_taken_i
   );

  logic partial_v_n, partial_v_r;
  logic partial_br_site_n, partial_br_site_r;
  logic [cinstr_width_gp-1:0] partial_instr_n, partial_instr_r;
  logic [vaddr_width_p-1:0] partial_pc_n, partial_pc_r;

  wire if2_pc_aligned = `bp_addr_is_aligned(if2_pc_i, (instr_width_gp>>3));
  wire [fetch_sel_gp-1:0] if2_pc_sel = if2_pc_i[1+:fetch_sel_gp];
  wire [fetch_width_gp-1:0] if2_shift = if2_pc_sel << 3'd4;
  wire [fetch_width_gp-1:0] if2_instr = if2_data_i >> if2_shift;
  wire [fetch_ptr_gp-1:0] if2_count = fetch_cinstr_gp - if2_pc_sel;

  wire [cinstr_width_gp-1:0] if2_data_upper = if2_data_i[cinstr_width_gp+:cinstr_width_gp];
  wire [cinstr_width_gp-1:0] if2_data_lower = if2_data_i[0+:cinstr_width_gp];

  wire if2_low_branch = if2_data_lower
    inside {`RV64_BRANCH, `RV64_JAL, `RV64_JALR, `RV64_CJ, `RV64_CJR, `RV64_CJALR, `RV64_CBEQZ, `RV64_CBNEZ};
  wire if2_high_branch = if2_data_upper
    inside {`RV64_BRANCH, `RV64_JAL, `RV64_JALR, `RV64_CJ, `RV64_CJR, `RV64_CJALR, `RV64_CBEQZ, `RV64_CBNEZ};
  wire [1:0] if2_compressed = ~{&if2_data_upper[0+:2], &if2_data_lower[0+:2]};

  wire [vaddr_width_p-1:0] redirect_partial_pc = redirect_pc_i;
  wire [vaddr_width_p-1:0] if2_partial_pc = if2_pc_i + (if2_pc_aligned ? 2'b10 : 2'b00);
  wire [cinstr_width_gp-1:0] if2_partial_instr = if2_data_upper;
  bsg_mux
   #(.width_p(cinstr_width_gp+vaddr_width_p), .els_p(2))
   redirect_mux
    (.data_i({{redirect_instr_i, redirect_partial_pc}, {if2_partial_instr, if2_partial_pc}})
     ,.sel_i(redirect_v_i)
     ,.data_o({partial_instr_n, partial_pc_n})
     );

  wire if2_store_v = if2_yumi_o & fetch_linear_o;
  wire partial_w_v = if2_store_v | redirect_v_i | assembled_yumi_i;
  assign partial_v_n = (if2_store_v & ~redirect_v_i) | (redirect_v_i & redirect_resume_i);
  assign partial_br_site_n = if2_high_branch;
  bsg_dff_reset_en
   #(.width_p(2+cinstr_width_gp+vaddr_width_p))
   partial_instr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(partial_w_v)
     ,.data_i({partial_v_n, partial_br_site_n, partial_instr_n, partial_pc_n})
     ,.data_o({partial_v_r, partial_br_site_r, partial_instr_r, partial_pc_r})
     );

  wire [vaddr_width_p-1:0] realigned_pc = partial_pc_r;
  wire [fetch_width_gp-1:0] realigned_instr = {if2_data_i, partial_instr_r};
  wire [fetch_ptr_gp-1:0] realigned_count = fetch_cinstr_gp + 1'b1;

  // Here is a table of the possible cases:
  // partial_v  if2_aligned if2_comp[1] if2_comp[0] | fetch_linear fetch_eager fetch_catchup fetch_rebase |
  //     0           0          0           x       |      1            0           0          0       |
  //     0           0          1           x       |      0            1           0          0       |
  //     0           1          0           0       |      0            0           0          0       |
  //     0           1          0           1       |  !if2_tbr         1       !if2_tbr    if2_dbr    |
  //     0           1          1           0       |      -            -           -          -       |
  //     0           1          1           1       |      0         if2_lbr    !if2_tbr    if2_dbr    |
  //     1           x          0           0       |  !if2_tbr         0           0          0       |
  //     1           0          0           1       |      -            -           -          -       |
  //     1           0          1           0       |      -            -           -          -       |
  //     1           0          1           1       |      -            -           -          -       |
  //     1           1          0           1       |      -            -           -          -       |
  //     1           1          1           0       |      0            0       !if2_tbr    if2_hbr    |
  //     1           1          1           1       |      -            -           -          -       |

  // Fetching at least one valid instruction
  assign assembled_v_o = if2_v_i & (if2_pc_aligned | partial_v_r | if2_compressed[1]);
  assign assembled_pc_o = partial_v_r ? realigned_pc : if2_pc_i;
  assign assembled_instr_o = partial_v_r ? realigned_instr : if2_instr;
  assign assembled_partial_o = partial_v_r ? 1'b1 : 1'b0;
  // Force a linear fetch if we're storing in the realigner (need to complete instruction)
  assign fetch_linear_o = if2_v_i &&
    // starting misaligned high
    ((~partial_v_r & ~if2_pc_aligned & ~if2_compressed[1])
     // starting misaligned after compressed
     || (~partial_v_r &  if2_pc_aligned & if2_compressed[0] & ~if2_compressed[1] & ~fetch_taken_i)
     // continuing misaligned high
     || ( partial_v_r & ~if2_compressed[1] & ~fetch_taken_i));
  // Eagerly fetch a low or high compressed instruction
  //assign assembled_count_o = partial_v_r ? realigned_count : if2_count;
  assign assembled_count_o = (if2_v_i &
    ((~partial_v_r & ~if2_pc_aligned & if2_compressed[1])
      || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & ~if2_compressed[1])
      || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & if2_low_branch)
      )) ? 2'b01 : 2'b10;
  // Adjust the IF2 PC up to catchup after completing a misaligned instruction or low compressed branch
  assign fetch_catchup_o = assembled_yumi_i &
    ((partial_v_r & if2_compressed[1] & ~fetch_taken_i)
     || (partial_v_r & if2_compressed[1] & ~partial_br_site_r & if2_high_branch & fetch_taken_i)
     || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & if2_low_branch & ~fetch_taken_i)
     );

  assign if2_yumi_o = if2_v_i & ~fetch_catchup_o & (~assembled_v_o | assembled_yumi_i);
  assign assembled_br_metadata_fwd_o = if2_br_metadata_fwd_i;

endmodule


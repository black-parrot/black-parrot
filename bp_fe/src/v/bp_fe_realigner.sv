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

   , localparam scan_width_lp = $bits(bp_fe_instr_scan_s)
   )
  (input                               clk_i
   , input                             reset_i

   // Fetch PC and I$ data
   , input                             if2_instr_v_i
   , input                             if2_exception_v_i
   , input [vaddr_width_p-1:0]         if2_pc_i
   , input [instr_width_gp-1:0]        if2_data_i
   , input [scan_width_lp-1:0]         if2_instr_scan_i
   , input                             if2_taken_branch_site_i
   , output logic                      if2_yumi_o

   // Redirection from backend
   //   and whether to restore the instruction data
   //   and PC to resume a fetch
   , input                             redirect_v_i
   , input                             redirect_resume_i
   , input [cinstr_width_gp-1:0]       redirect_instr_i
   , input [vaddr_width_p-1:0]         redirect_pc_i

   , output logic [vaddr_width_p-1:0]  fetch_pc_o
   , output logic [instr_width_gp-1:0] fetch_instr_o
   , output logic [scan_width_lp-1:0]  fetch_instr_scan_o
   , output logic                      fetch_instr_v_o
   , output logic                      fetch_exception_v_o
   , output logic                      fetch_partial_o
   , output logic                      fetch_eager_o
   , output logic                      fetch_linear_o
   , output logic                      fetch_scan_o
   , output logic                      fetch_rebase_o
   );

  logic partial_v_n, partial_v_r;
  bp_fe_instr_scan_s partial_scan_n, partial_scan_r;
  logic partial_br_site_n, partial_br_site_r;
  logic [cinstr_width_gp-1:0] partial_instr_n, partial_instr_r;
  logic [vaddr_width_p-1:0] partial_pc_n, partial_pc_r;

  wire if2_pc_aligned = `bp_addr_is_aligned(if2_pc_i, (instr_width_gp>>3));
  wire [1:0] if2_compressed = ~{&if2_data_i[cinstr_width_gp+:2], &if2_data_i[0+:2]};
  wire if2_low_branch = if2_data_i[0+:cinstr_width_gp]
    inside {`RV64_BRANCH, `RV64_JAL, `RV64_JALR, `RV64_CJ, `RV64_CJR, `RV64_CJALR, `RV64_CBEQZ, `RV64_CBNEZ};
  wire if2_high_branch = if2_data_i[cinstr_width_gp+:cinstr_width_gp]
    inside {`RV64_BRANCH, `RV64_JAL, `RV64_JALR, `RV64_CJ, `RV64_CJR, `RV64_CJALR, `RV64_CBEQZ, `RV64_CBNEZ};
  wire [cinstr_width_gp-1:0] if2_data_upper = if2_data_i[cinstr_width_gp+:cinstr_width_gp];
  wire [cinstr_width_gp-1:0] if2_data_lower = if2_data_i[0+:cinstr_width_gp];

  wire [vaddr_width_p-1:0] redirect_partial_pc = redirect_pc_i;
  wire [vaddr_width_p-1:0] if2_partial_pc = if2_pc_i + (if2_pc_aligned ? 2'b10 : 2'b00);
  wire [cinstr_width_gp-1:0] if2_partial_instr = if2_pc_aligned ? if2_data_upper : if2_data_lower;
  bsg_mux
   #(.width_p(cinstr_width_gp+vaddr_width_p), .els_p(2))
   redirect_mux
    (.data_i({{redirect_instr_i, redirect_partial_pc}, {if2_partial_instr, if2_partial_pc}})
     ,.sel_i(redirect_v_i)
     ,.data_o({partial_instr_n, partial_pc_n})
     );

  bp_fe_instr_scan
   #(.bp_params_p(bp_params_p))
   partial_instr_scan
    (.instr_i({16'b0, partial_instr_n})
     ,.scan_o(partial_scan_n)
     );

  wire if2_store_v = if2_yumi_o & fetch_linear_o;
  wire partial_w_v = if2_store_v | redirect_v_i | fetch_instr_v_o;
  assign partial_v_n = (if2_store_v & ~redirect_v_i) | (redirect_v_i & redirect_resume_i);
  assign partial_br_site_n = if2_high_branch;
  bsg_dff_reset_en
   #(.width_p(scan_width_lp+2+cinstr_width_gp+vaddr_width_p))
   partial_instr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(partial_w_v)
     ,.data_i({partial_scan_n, partial_v_n, partial_br_site_n, partial_instr_n, partial_pc_n})
     ,.data_o({partial_scan_r, partial_v_r, partial_br_site_r, partial_instr_r, partial_pc_r})
     );

  // Scan data for assembled instructions depends on the second half
  bp_fe_instr_scan_s scan_assembled;
  rv64_instr_rtype_s instr_assembled, instr_aligned;
  assign instr_assembled = {if2_data_lower, partial_instr_r};
  assign instr_aligned   = {if2_data_upper, if2_data_lower};
  bsg_mux
   #(.width_p(scan_width_lp+instr_width_gp+vaddr_width_p), .els_p(2))
   instr_mux
    (.data_i({{scan_assembled, instr_assembled, partial_pc_r}, {if2_instr_scan_i, instr_aligned, if2_pc_i}})
     ,.sel_i(partial_v_r)
     ,.data_o({fetch_instr_scan_o, fetch_instr_o, fetch_pc_o})
     );

  wire dest_link   = (instr_assembled.rd_addr inside {32'h1, 32'h5});
  wire src_link    = (instr_assembled.rs1_addr inside {32'h1, 32'h5});
  wire dest_src_eq = (instr_assembled.rd_addr == instr_assembled.rs1_addr);
  assign scan_assembled =
    '{full     : partial_scan_r.full
      ,branch  : partial_scan_r.branch
      ,jal     : partial_scan_r.jal
      ,jalr    : partial_scan_r.jalr
      ,call    : (partial_scan_r.jal | partial_scan_r.jalr) & dest_link
      ,_return : partial_scan_r.jalr & src_link & !dest_src_eq
      ,default: '0
      };

  // Here is a table of the possible cases:
  // partial_v  if2_aligned if2_comp[1] if2_comp[0] | fetch_linear fetch_eager fetch_scan fetch_rebase |
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
  assign fetch_instr_v_o = if2_instr_v_i & (if2_pc_aligned | partial_v_r | if2_compressed[1]);
  assign fetch_exception_v_o = if2_exception_v_i;
  assign fetch_partial_o = partial_v_r;
  // Force a linear fetch if we're storing in the realigner (need to complete instruction)
  assign fetch_linear_o = if2_instr_v_i &&
    // starting misaligned high
    ((~partial_v_r & ~if2_pc_aligned & ~if2_compressed[1])
     // starting misaligned after compressed
     || (~partial_v_r &  if2_pc_aligned & if2_compressed[0] & ~if2_compressed[1] & ~if2_taken_branch_site_i)
     // continuing misaligned high
     || ( partial_v_r & ~if2_compressed[1] & ~if2_taken_branch_site_i));
  // Eagerly fetch a low or high compressed instruction
  assign fetch_eager_o = if2_instr_v_i &
    ((~partial_v_r & ~if2_pc_aligned & if2_compressed[1])
      || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & ~if2_compressed[1])
      || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & if2_low_branch)
      );
  // Adjust the IF2 PC up to catchup after completing a misaligned instruction or low compressed branch
  assign fetch_scan_o = if2_instr_v_i &
    ((partial_v_r & if2_compressed[1] & ~if2_taken_branch_site_i)
     || (partial_v_r & if2_compressed[1] & ~partial_br_site_r & if2_high_branch & if2_taken_branch_site_i)
     || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & if2_low_branch & ~if2_taken_branch_site_i)
     );
  // Refetch a high branch because its site has been aliased
  assign fetch_rebase_o = if2_instr_v_i &
    ((partial_v_r & if2_compressed[1] & if2_high_branch & partial_br_site_r)
     || (~partial_v_r & if2_pc_aligned & if2_compressed[0] & if2_low_branch & if2_high_branch)
     );

  assign if2_yumi_o = (if2_instr_v_i & ~fetch_scan_o) | if2_exception_v_i;

endmodule


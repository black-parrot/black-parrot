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

   , localparam icache_cinstr_lp = icache_data_width_p / cinstr_width_gp
   , localparam icache_sel_lp = `BSG_SAFE_CLOG2(icache_cinstr_lp)
   , localparam scan_width_lp = $bits(bp_fe_scan_s)
   )
  (input                                                    clk_i
   , input                                                  reset_i

   // Fetch PC and I$ data
   , input                                                  if2_hit_v_i
   , input                                                  if2_miss_v_i
   , input [vaddr_width_p-1:0]                              if2_pc_i
   , input [icache_cinstr_lp-1:0][cinstr_width_gp-1:0]      if2_data_i
   , input [branch_metadata_fwd_width_p-1:0]                if2_br_metadata_fwd_i
   , output logic                                           if2_yumi_o

   // Redirection from backend
   //   and whether to restore the instruction data
   //   and PC to resume a fetch
   , input                                                  redirect_v_i
   , input [vaddr_width_p-1:0]                              redirect_pc_i
   , input [cinstr_width_gp-1:0]                            redirect_instr_i
   , input [branch_metadata_fwd_width_p-1:0]                redirect_br_metadata_fwd_i
   , input                                                  redirect_resume_i

   // Assembled instruction, PC and count
   , output logic                                           assembled_v_o
   , output logic [vaddr_width_p-1:0]                       assembled_pc_o
   , output logic [fetch_cinstr_p-1:0][cinstr_width_gp-1:0] assembled_instr_o
   , output logic [branch_metadata_fwd_width_p-1:0]         assembled_br_metadata_fwd_o
   , output logic [fetch_ptr_p-1:0]                         assembled_count_o
   , output logic                                           assembled_partial_o
   , input [fetch_ptr_p-1:0]                                assembled_count_i
   , input                                                  assembled_yumi_i
   );

  `declare_bp_fe_branch_metadata_fwd_s(ras_idx_width_p, btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_els_p);

  logic partial_w_v, partial_v_n, partial_v_r;
  logic [vaddr_width_p-1:0] partial_pc_n, partial_pc_r;
  logic [cinstr_width_gp-1:0] partial_instr_n, partial_instr_r;

  wire [icache_sel_lp-1:0] if2_pc_sel = if2_pc_i[1+:icache_sel_lp];
  wire [fetch_width_p-1:0] if2_shift = if2_pc_sel << 3'd4;
  wire [fetch_width_p-1:0] if2_instr = if2_data_i >> if2_shift;
  wire [fetch_ptr_p-1:0] if2_count = if2_hit_v_i ? (icache_cinstr_lp - if2_pc_sel) : 1'b0;

  bsg_dff_reset_en
   #(.width_p(cinstr_width_gp+vaddr_width_p+1))
   partial_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(partial_w_v)

     ,.data_i({partial_instr_n, partial_pc_n, partial_v_n})
     ,.data_o({partial_instr_r, partial_pc_r, partial_v_r})
     );

  wire [vaddr_width_p-1:0] realigned_pc = partial_pc_r;
  wire [fetch_cinstr_p:0][cinstr_width_gp-1:0] realigned_instr = {if2_data_i, partial_instr_r};
  wire [fetch_ptr_p-1:0] realigned_count = if2_hit_v_i ? fetch_cinstr_p : 1'b1;

  // Store leftover into realigner
  wire partial_store = (assembled_count_o - assembled_count_i == 2'd1);
  // Drain leftover from realigner
  wire partial_drain = (assembled_count_o - assembled_count_i > 2'd1);

  assign partial_w_v = redirect_v_i
    | assembled_yumi_i
    | if2_yumi_o;
  assign partial_v_n = redirect_v_i ? redirect_resume_i
    : assembled_yumi_i ? partial_store
    : partial_v_r;
  assign partial_pc_n = redirect_v_i ? redirect_pc_i
    : assembled_yumi_i ? assembled_pc_o + (assembled_count_i << 1'b1)
    : if2_pc_i;
  assign partial_instr_n = redirect_v_i ? redirect_instr_i
    : assembled_yumi_i ? if2_data_i[icache_cinstr_lp-1]
    : if2_data_i[icache_cinstr_lp-1];

  assign assembled_pc_o              = partial_v_r ? realigned_pc    : if2_pc_i;
  assign assembled_instr_o           = partial_v_r ? realigned_instr : if2_instr;
  assign assembled_br_metadata_fwd_o =                                 if2_br_metadata_fwd_i;
  assign assembled_count_o           = partial_v_r ? realigned_count : if2_count;
  assign assembled_partial_o         = partial_v_r;

  assign assembled_v_o = if2_hit_v_i | if2_miss_v_i;
  assign if2_yumi_o = if2_hit_v_i & ~partial_drain & assembled_yumi_i;

endmodule


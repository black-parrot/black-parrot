/*
 * bp_fe_pc_gen.v
 *
 * pc_gen provides the pc for the itlb and icache.
 * pc_gen also provides the BTB, BHT and RAS indexes for the backend (the queue
 * between the frontend and the backend, i.e. the frontend queue).
*/

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_pc_gen
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   , localparam instr_scan_width_lp = $bits(bp_fe_instr_scan_s)
   )
  (input                                             clk_i
   , input                                           reset_i

   , output logic                                    init_done_o

   , input                                           attaboy_v_i
   , input                                           attaboy_force_i
   , input [vaddr_width_p-1:0]                       attaboy_pc_i
   , input [branch_metadata_fwd_width_p-1:0]         attaboy_br_metadata_fwd_i
   , input                                           attaboy_taken_i
   , input                                           attaboy_ntaken_i
   , output logic                                    attaboy_yumi_o

   , input                                           redirect_v_i
   , input [vaddr_width_p-1:0]                       redirect_pc_i
   , input [vaddr_width_p-1:0]                       redirect_npc_i
   , input                                           redirect_resume_i
   , input                                           redirect_br_v_i
   , input [branch_metadata_fwd_width_p-1:0]         redirect_br_metadata_fwd_i
   , input                                           redirect_br_taken_i
   , input                                           redirect_br_ntaken_i
   , input                                           redirect_br_nonbr_i

   , output logic [vaddr_width_p-1:0]                next_pc_o
   , input                                           if1_we_i

   , output logic                                    ovr_o
   , input                                           if2_we_i

   , output logic [vaddr_width_p-1:0]                if2_pc_o
   , output logic [branch_metadata_fwd_width_p-1:0]  if2_br_metadata_fwd_o
   , output logic                                    if2_taken_branch_site_o

   , input                                           fetch_instr_v_i
   , input [instr_scan_width_lp-1:0]                 fetch_instr_scan_i
   , input [vaddr_width_p-1:0]                       fetch_pc_i
   , input [instr_width_gp-1:0]                      fetch_instr_i
   , input                                           fetch_linear_i
   , input                                           fetch_scan_i
   , input                                           fetch_rebase_i
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(ras_idx_width_p, btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_els_p);
  `bp_cast_i(bp_fe_branch_metadata_fwd_s, redirect_br_metadata_fwd);
  `bp_cast_i(bp_fe_branch_metadata_fwd_s, attaboy_br_metadata_fwd);

  /////////////////////////////////////////////////////////////////////////////////////
  // IF0
  /////////////////////////////////////////////////////////////////////////////////////
  logic [ghist_width_p-1:0] ghistory_n, ghistory_r;

  logic [vaddr_width_p-1:0] next_pc;
  logic [bht_row_width_p-1:0] bht_row_lo;
  logic bht_pred_lo;
  logic [vaddr_width_p-1:0] btb_br_tgt_lo;
  logic btb_br_tgt_v_lo, btb_br_tgt_jmp_lo;

  ///////////////////////////
  // Next PC calculation
  ///////////////////////////
  bp_fe_branch_metadata_fwd_s next_metadata, ovr_metadata;
  logic next_pred, next_taken;
  logic ovr_ret, ovr_btaken, ovr_jmp, ovr_ntaken, ovr_dbranch, btb_taken;
  logic [vaddr_width_p-1:0] pc_plus;
  logic [vaddr_width_p-1:0] ras_tgt_lo, br_tgt_lo, linear_tgt_lo;
  logic [ras_idx_width_p-1:0] ras_next, ras_tos;
  logic [btb_tag_width_p-1:0] btb_tag;
  logic [btb_idx_width_p-1:0] btb_idx;
  logic [bht_idx_width_p-1:0] bht_idx;
  logic [bht_offset_width_p-1:0] bht_offset;

  // Note: "if" chain duplicated in in bp_fe_nonsynth_pc_gen_tracer.sv
  always_comb begin
    if (redirect_v_i)
      begin
        next_pred  = 1'b0;
        next_taken = redirect_br_taken_i;
        next_pc    = redirect_npc_i;

        next_metadata = redirect_br_metadata_fwd_cast_i;
      end
    else if (ovr_o)
      begin
        next_pred  = ovr_btaken;
        next_taken = ovr_ret | ovr_btaken | ovr_jmp;
        next_pc    = ovr_ret ? ras_tgt_lo : (ovr_btaken | ovr_jmp) ? br_tgt_lo : linear_tgt_lo;

        next_metadata = ovr_metadata;
      end
    else
      begin
        next_pred  = bht_pred_lo;
        next_taken = btb_taken;
        next_pc    = btb_taken ? btb_br_tgt_lo : `bp_addr_align(pc_plus, fetch_bytes_gp);

        next_metadata = '0;
        next_metadata.src_btb = btb_br_tgt_v_lo;
        next_metadata.bht_row = bht_row_lo;
        next_metadata.ghist   = ghistory_r;
        next_metadata.btb_tag = btb_tag;
        next_metadata.btb_idx = btb_idx;
        next_metadata.bht_idx = bht_idx;
        next_metadata.bht_offset = bht_offset;
      end
  end
  assign next_pc_o = next_pc;

  ///////////////////////////
  // BTB
  ///////////////////////////
  logic btb_w_yumi_lo, btb_init_done_lo;
  wire btb_r_v_li = if1_we_i;
  wire btb_w_v_li = (redirect_br_v_i & redirect_br_taken_i & ~redirect_br_metadata_fwd_cast_i.src_btb & ~redirect_br_metadata_fwd_cast_i.src_ras)
    | (redirect_br_v_i & redirect_br_taken_i & redirect_br_metadata_fwd_cast_i.src_btb & ~redirect_br_metadata_fwd_cast_i.src_ras)
    | (attaboy_v_i & attaboy_taken_i & ~attaboy_br_metadata_fwd_cast_i.src_btb & ~attaboy_br_metadata_fwd_cast_i.src_ras)
    | (redirect_br_v_i & redirect_br_taken_i & redirect_br_metadata_fwd_cast_i.src_btb & redirect_br_metadata_fwd_cast_i.src_ras)
    | (redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd_cast_i.src_btb);
  wire btb_w_force_li = redirect_br_v_i | attaboy_force_i;
  wire btb_clr_li = (redirect_br_v_i & redirect_br_taken_i & redirect_br_metadata_fwd_cast_i.src_btb & redirect_br_metadata_fwd_cast_i.src_ras)
    | (redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd_cast_i.src_btb);
  wire btb_jmp_li = redirect_br_v_i ? (redirect_br_metadata_fwd_cast_i.site_jal | redirect_br_metadata_fwd_cast_i.site_jalr) : (attaboy_br_metadata_fwd_cast_i.site_jal | attaboy_br_metadata_fwd_cast_i.site_jalr);
  wire [btb_tag_width_p-1:0]  btb_tag_li = redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.btb_tag : attaboy_br_metadata_fwd_cast_i.btb_tag;
  wire [btb_idx_width_p-1:0]  btb_idx_li = redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.btb_idx : attaboy_br_metadata_fwd_cast_i.btb_idx;
  wire [vaddr_width_p-1:0]    btb_tgt_li = redirect_br_v_i ? redirect_pc_i : attaboy_pc_i;
  wire [vaddr_width_p-1:0] btb_r_addr_li = next_pc;

  bp_fe_btb
   #(.bp_params_p(bp_params_p))
   btb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.r_addr_i(btb_r_addr_li)
     ,.r_v_i(btb_r_v_li)
     ,.r_idx_o(btb_idx)
     ,.r_tag_o(btb_tag)
     ,.r_tgt_o(btb_br_tgt_lo)
     ,.r_tgt_v_o(btb_br_tgt_v_lo)
     ,.r_tgt_jmp_o(btb_br_tgt_jmp_lo)

     ,.w_v_i(btb_w_v_li)
     ,.w_force_i(btb_w_force_li)
     ,.w_clr_i(btb_clr_li)
     ,.w_jmp_i(btb_jmp_li)
     ,.w_tag_i(btb_tag_li)
     ,.w_idx_i(btb_idx_li)
     ,.w_tgt_i(btb_tgt_li)
     ,.w_yumi_o(btb_w_yumi_lo)

     ,.init_done_o(btb_init_done_lo)
     );

  ///////////////////////////
  // BHT
  ///////////////////////////
  wire bht_r_v_li = if1_we_i;
  wire [vaddr_width_p-1:0] bht_r_addr_li = next_pc;
  wire [ghist_width_p-1:0] bht_r_ghist_li = ghistory_n;
  wire bht_w_v_li =
    (redirect_br_v_i & redirect_br_metadata_fwd_cast_i.site_br) | (attaboy_v_i & attaboy_br_metadata_fwd_cast_i.site_br);
  wire bht_w_force_li = redirect_br_v_i | attaboy_force_i;
  wire [bht_idx_width_p-1:0] bht_w_idx_li =
    redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.bht_idx : attaboy_br_metadata_fwd_cast_i.bht_idx;
  wire [bht_offset_width_p-1:0] bht_w_offset_li =
    redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.bht_offset : attaboy_br_metadata_fwd_cast_i.bht_offset;
  wire [ghist_width_p-1:0] bht_w_ghist_li =
    redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.ghist : attaboy_br_metadata_fwd_cast_i.ghist;
  wire [bht_row_width_p-1:0] bht_row_li =
    redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.bht_row : attaboy_br_metadata_fwd_cast_i.bht_row;
  logic bht_w_yumi_lo, bht_init_done_lo;
  bp_fe_bht
   #(.bp_params_p(bp_params_p))
   bht
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.r_v_i(bht_r_v_li)
     ,.r_addr_i(bht_r_addr_li)
     ,.r_ghist_i(bht_r_ghist_li)
     ,.r_val_o(bht_row_lo)
     ,.r_pred_o(bht_pred_lo)
     ,.r_idx_o(bht_idx)
     ,.r_offset_o(bht_offset)

     ,.w_v_i(bht_w_v_li)
     ,.w_force_i(bht_w_force_li)
     ,.w_idx_i(bht_w_idx_li)
     ,.w_offset_i(bht_w_offset_li)
     ,.w_ghist_i(bht_w_ghist_li)
     ,.w_correct_i(attaboy_yumi_o)
     ,.w_val_i(bht_row_li)
     ,.w_yumi_o(bht_w_yumi_lo)

     ,.init_done_o(bht_init_done_lo)
     );

  /////////////////////////////////////////////////////////////////////////////////////
  // IF1
  /////////////////////////////////////////////////////////////////////////////////////
  logic [vaddr_width_p-1:0] pc_if1_r;
  bp_fe_branch_metadata_fwd_s metadata_if1_r;
  logic pred_if1_r, taken_if1_r;
  bsg_dff_reset_en
   #(.width_p(2+branch_metadata_fwd_width_p+vaddr_width_p))
   if1_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(if1_we_i)

     ,.data_i({next_pred, next_taken, next_metadata, next_pc})
     ,.data_o({pred_if1_r, taken_if1_r, metadata_if1_r, pc_if1_r})
     );

  // Set the site type as it arrives in IF2
  bp_fe_branch_metadata_fwd_s metadata_if1;
  always_comb
    begin
      metadata_if1 = metadata_if1_r;
      if (fetch_instr_v_i)
        begin
          metadata_if1.ras_next    = ras_next;
          metadata_if1.ras_tos     = ras_tos;
          metadata_if1.src_ras     = ovr_ret;
          metadata_if1.site_br     = fetch_instr_scan.branch;
          metadata_if1.site_jal    = fetch_instr_scan.jal;
          metadata_if1.site_jalr   = fetch_instr_scan.jalr;
          metadata_if1.site_call   = fetch_instr_scan.call;
          metadata_if1.site_return = fetch_instr_scan._return;
        end
    end
  assign ovr_metadata = metadata_if1;

  assign btb_taken = btb_br_tgt_v_lo & (bht_pred_lo | btb_br_tgt_jmp_lo);
  assign pc_plus  = pc_if1_r + fetch_bytes_gp;

  /////////////////////////////////////////////////////////////////////////////////////
  // IF2
  /////////////////////////////////////////////////////////////////////////////////////
  bp_fe_branch_metadata_fwd_s metadata_if2_n, metadata_if2_r;
  assign metadata_if2_n = (fetch_linear_i & ~fetch_instr_v_i) ? metadata_if2_r : metadata_if1;
  bsg_dff_reset_en
   #(.width_p(branch_metadata_fwd_width_p))
   if2_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(if2_we_i | fetch_scan_i)

     ,.data_i(metadata_if2_n)
     ,.data_o(metadata_if2_r)
     );

  logic [vaddr_width_p-1:0] pc_if2_n, pc_if2_r;
  assign pc_if2_n = fetch_scan_i ? {pc_if2_r[vaddr_width_p-1:2], 2'b10} : pc_if1_r;
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p))
   pc_if2_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(if2_we_i | fetch_scan_i)
     ,.data_i(pc_if2_n)
     ,.data_o(pc_if2_r)
     );

  ///////////////////////////
  // RAS Storage
  ///////////////////////////
  logic ras_init_done_lo;
  logic ras_valid_lo, ras_call_li, ras_return_li;
  logic [vaddr_width_p-1:0] ras_addr_li;

  wire ras_w_v_li = redirect_br_v_i;
  wire [ras_idx_width_p-1:0] ras_w_next_li = redirect_br_metadata_fwd_cast_i.ras_next;
  wire [ras_idx_width_p-1:0] ras_w_tos_li = redirect_br_metadata_fwd_cast_i.ras_tos;
  bp_fe_ras
   #(.bp_params_p(bp_params_p))
   ras
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.init_done_o(ras_init_done_lo)

     ,.restore_i(ras_w_v_li)
     ,.w_next_i(ras_w_next_li)
     ,.w_tos_i(ras_w_tos_li)

     ,.call_i(ras_call_li)
     ,.addr_i(ras_addr_li)

     ,.v_o(ras_valid_lo)
     ,.tgt_o(ras_tgt_lo)
     ,.next_o(ras_next)
     ,.tos_o(ras_tos)
     ,.return_i(ras_return_li)
     );

  // Scan fetched instruction
  bp_fe_instr_scan_s fetch_instr_scan;
  assign fetch_instr_scan = fetch_instr_scan_i;

  assign ras_call_li = fetch_instr_v_i & fetch_instr_scan.call;
  assign ras_return_li = fetch_instr_v_i & fetch_instr_scan._return;
  assign ras_addr_li = fetch_pc_i + (fetch_instr_scan.clow ? 3'd2 : 3'd4);

  // Override calculations
  wire btb_miss_ras = pc_if1_r != ras_tgt_lo;
  wire btb_miss_br  = pc_if1_r != br_tgt_lo;

  wire taken_ret_if2 = fetch_instr_v_i & btb_miss_ras & fetch_instr_scan._return & ras_valid_lo;
  wire taken_br_if2  = fetch_instr_v_i & btb_miss_br  & fetch_instr_scan.branch & pred_if1_r;
  wire taken_jmp_if2 = fetch_instr_v_i & btb_miss_br  & fetch_instr_scan.jal;

  assign ovr_ret     = taken_ret_if2;
  assign ovr_btaken  = taken_br_if2;
  assign ovr_jmp     = taken_jmp_if2;
  assign ovr_dbranch = fetch_rebase_i & ~taken_if1_r;
  assign ovr_ntaken  = fetch_linear_i &  taken_if1_r;
  assign ovr_o       = ovr_btaken | ovr_jmp | ovr_ret | ovr_dbranch | ovr_ntaken;

  logic [vaddr_width_p-1:0] br_imm;
  wire [cinstr_width_gp-1:0] fetch_cinstr_lo = fetch_instr_i[0+:cinstr_width_gp];
  wire [cinstr_width_gp-1:0] fetch_cinstr_hi = fetch_instr_i[cinstr_width_gp+:cinstr_width_gp];
  always_comb
    unique if (fetch_instr_scan.clow & fetch_instr_scan.jal)
      br_imm = `rv64_signext_cj_imm(fetch_cinstr_lo);
    else if (fetch_instr_scan.chigh & fetch_instr_scan.jal)
      br_imm = `rv64_signext_cj_imm(fetch_cinstr_hi);
    else if (fetch_instr_scan.clow & fetch_instr_scan.branch)
      br_imm = `rv64_signext_cb_imm(fetch_cinstr_lo);
    else if (fetch_instr_scan.chigh & fetch_instr_scan.branch)
      br_imm = `rv64_signext_cb_imm(fetch_cinstr_hi);
    else if (fetch_instr_scan.full & fetch_instr_scan.jal)
      br_imm = `rv64_signext_j_imm(fetch_instr_i);
    else
      br_imm = `rv64_signext_b_imm(fetch_instr_i);
  wire [1:0] cimm = fetch_instr_scan.chigh ? 2'b10 : 2'b00;

  assign br_tgt_lo     = fetch_pc_i + br_imm + cimm;
  assign linear_tgt_lo = pc_if2_r + 3'd2;

  assign if2_br_metadata_fwd_o = metadata_if2_r;
  assign if2_pc_o = pc_if2_r;

  assign if2_taken_branch_site_o = taken_if1_r || taken_ret_if2 || taken_br_if2 || taken_jmp_if2;

  assign attaboy_yumi_o = attaboy_v_i & ~(bht_w_v_li & ~bht_w_yumi_lo) & ~(btb_w_v_li & ~btb_w_yumi_lo);
  assign init_done_o = bht_init_done_lo & btb_init_done_lo & ras_init_done_lo;

  ///////////////////////////
  // Global history
  ///////////////////////////
  assign ghistory_n = redirect_br_v_i
    ? redirect_br_metadata_fwd_cast_i.ghist
    : metadata_if1.site_br & ~ovr_o
      ? {ghistory_r[0+:ghist_width_p-1], taken_if1_r}
      : ghistory_r;
  wire ghistory_w_v = redirect_br_v_i | if2_we_i;
  bsg_dff_reset_en
   #(.width_p(ghist_width_p))
   ghist_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ghistory_w_v)

     ,.data_i(ghistory_n)
     ,.data_o(ghistory_r)
     );

endmodule


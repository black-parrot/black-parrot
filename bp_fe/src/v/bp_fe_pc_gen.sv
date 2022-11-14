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

   , input                                           redirect_v_i
   , input [vaddr_width_p-1:0]                       redirect_pc_i
   , input                                           redirect_br_v_i
   , input [branch_metadata_fwd_width_p-1:0]         redirect_br_metadata_fwd_i
   , input                                           redirect_br_taken_i
   , input                                           redirect_br_ntaken_i
   , input                                           redirect_br_nonbr_i

   , output logic [vaddr_width_p-1:0]                next_pc_o
   , input                                           if1_we_i

   , output logic                                    ovr_o
   , input                                           if2_we_i

   , output logic [branch_metadata_fwd_width_p-1:0]  if2_br_metadata_fwd_o
   , output logic                                    if2_taken_branch_site_o
   , output logic [vaddr_width_p-1:0]                if2_pc_o

   , input [instr_scan_width_lp-1:0]                 fetch_scan_i
   , input [vaddr_width_p-1:0]                       fetch_pc_i
   , input                                           fetch_partial_i
   , input                                           fetch_linear_i

   , input [vaddr_width_p-1:0]                       attaboy_pc_i
   , input [branch_metadata_fwd_width_p-1:0]         attaboy_br_metadata_fwd_i
   , input                                           attaboy_taken_i
   , input                                           attaboy_ntaken_i
   , input                                           attaboy_v_i
   , output logic                                    attaboy_yumi_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_width_p);
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
  logic ovr_ret, ovr_btaken, ovr_jmp, ovr_ntaken, btb_taken;
  logic [vaddr_width_p-1:0] pc_plus4;
  logic [vaddr_width_p-1:0] ras_tgt_lo;
  logic [vaddr_width_p-1:0] br_tgt_lo;
  logic [vaddr_width_p-1:0] linear_tgt_lo;
  logic [btb_tag_width_p-1:0] btb_tag;
  logic [btb_idx_width_p-1:0] btb_idx;
  logic [bht_idx_width_p-1:0] bht_idx;

  // Note: "if" chain duplicated in in bp_fe_nonsynth_pc_gen_tracer.sv
  always_comb begin
    if (redirect_v_i)
      begin
        next_pred  = redirect_br_taken_i;
        next_taken = redirect_br_taken_i;
        next_pc    = redirect_pc_i;

        next_metadata = redirect_br_metadata_fwd_cast_i;
      end
    else if (ovr_o)
      begin
        next_pred  = ovr_btaken;
        next_taken = ovr_ret | ovr_btaken | ovr_jmp;
        next_pc    = ovr_ntaken ? linear_tgt_lo : ovr_ret ? ras_tgt_lo : br_tgt_lo;

        next_metadata = ovr_metadata;
        next_metadata.site_br     = fetch_scan.branch;
        next_metadata.site_jal    = fetch_scan.jal;
        next_metadata.site_jalr   = fetch_scan.jalr;
        next_metadata.site_call   = fetch_scan.call;
        next_metadata.site_return = fetch_scan._return;
      end
    else
      begin
        next_pred  = bht_pred_lo;
        next_taken = btb_taken;
        next_pc    = btb_taken ? btb_br_tgt_lo : pc_plus4;

        next_metadata = '0;
        next_metadata.src_btb = btb_br_tgt_v_lo;
        next_metadata.src_ras = ovr_ret;
        next_metadata.bht_row = bht_row_lo;
        next_metadata.ghist   = ghistory_r;
        next_metadata.btb_tag = btb_tag;
        next_metadata.btb_idx = btb_idx;
        next_metadata.bht_idx = bht_idx;
      end
  end
  assign next_pc_o = next_pc;

  ///////////////////////////
  // BTB
  ///////////////////////////
  logic btb_w_yumi_lo, btb_init_done_lo; 
  wire btb_r_v_li = if1_we_i;
  wire btb_w_v_li = (redirect_br_v_i & redirect_br_taken_i)
    | (redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd_cast_i.src_btb)
    | (attaboy_v_i & attaboy_taken_i & (~attaboy_br_metadata_fwd_cast_i.src_btb | attaboy_br_metadata_fwd_cast_i.src_ras));
  wire btb_clr_li = redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd_cast_i.src_btb;
  wire btb_jmp_li = redirect_br_v_i ? (redirect_br_metadata_fwd_cast_i.site_jal | redirect_br_metadata_fwd_cast_i.site_jalr) : (attaboy_br_metadata_fwd_cast_i.site_jal | attaboy_br_metadata_fwd_cast_i.site_jalr);
  wire [btb_tag_width_p-1:0] btb_tag_li = redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.btb_tag : attaboy_br_metadata_fwd_cast_i.btb_tag;
  wire [btb_idx_width_p-1:0] btb_idx_li = redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.btb_idx : attaboy_br_metadata_fwd_cast_i.btb_idx;
  wire [vaddr_width_p-1:0]   btb_tgt_li = redirect_br_v_i ? redirect_pc_i : attaboy_pc_i;

  bp_fe_btb
   #(.bp_params_p(bp_params_p))
   btb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.r_addr_i(next_pc)
     ,.r_v_i(btb_r_v_li)
     ,.br_tgt_o(btb_br_tgt_lo)
     ,.br_tgt_v_o(btb_br_tgt_v_lo)
     ,.br_tgt_jmp_o(btb_br_tgt_jmp_lo)

     ,.w_v_i(btb_w_v_li)
     ,.w_clr_i(btb_clr_li)
     ,.w_jmp_i(btb_jmp_li)
     ,.w_tag_i(btb_tag_li)
     ,.w_idx_i(btb_idx_li)
     ,.br_tgt_i(btb_tgt_li)
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
  wire [bht_idx_width_p-1:0] bht_w_idx_li =
    redirect_br_v_i ? redirect_br_metadata_fwd_cast_i.bht_idx : attaboy_br_metadata_fwd_cast_i.bht_idx;
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
     ,.val_o(bht_row_lo)
     ,.pred_o(bht_pred_lo)

     ,.w_v_i(bht_w_v_li)
     ,.w_idx_i(bht_w_idx_li)
     ,.w_ghist_i(bht_w_ghist_li)
     ,.correct_i(attaboy_yumi_o)
     ,.val_i(bht_row_li)
     ,.w_yumi_o(bht_w_yumi_lo)

     ,.init_done_o(bht_init_done_lo)
     );

  assign attaboy_yumi_o = attaboy_v_i & ~(bht_w_v_li & ~bht_w_yumi_lo) & ~(btb_w_v_li & ~btb_w_yumi_lo);
  assign init_done_o = bht_init_done_lo & btb_init_done_lo;

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
  assign ovr_metadata = metadata_if1_r;

  // Set the site type as it arrives in IF2
  // We can OR because sites will only be set earlier during an override
  //   and if we have overridden then we will not have incoming I$ data
  //   that cycle
  bp_fe_branch_metadata_fwd_s metadata_if1;
  always_comb
    begin
      metadata_if1 = metadata_if1_r;
      metadata_if1.site_br     |= fetch_scan.branch;
      metadata_if1.site_jal    |= fetch_scan.jal;
      metadata_if1.site_jalr   |= fetch_scan.jalr;
      metadata_if1.site_call   |= fetch_scan.call;
      metadata_if1.site_return |= fetch_scan._return;
    end

  assign btb_taken = btb_br_tgt_v_lo & (bht_pred_lo | btb_br_tgt_jmp_lo);
  assign pc_plus4  = pc_if1_r + vaddr_width_p'(4);

  assign btb_tag = pc_if1_r[2+btb_idx_width_p+:btb_tag_width_p];
  assign btb_idx = pc_if1_r[2+:btb_idx_width_p];
  assign bht_idx = pc_if1_r[2+:bht_idx_width_p];

  /////////////////////////////////////////////////////////////////////////////////////
  // IF2
  /////////////////////////////////////////////////////////////////////////////////////
  logic [vaddr_width_p-1:0] pc_if2_r;
  logic pred_if2_r, taken_if2_r;
  bp_fe_branch_metadata_fwd_s metadata_if2_r;
  bsg_dff_reset_en
   #(.width_p(2+branch_metadata_fwd_width_p+vaddr_width_p))
   if2_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(if2_we_i)

     ,.data_i({pred_if1_r, taken_if1_r, metadata_if1, pc_if1_r})
     ,.data_o({pred_if2_r, taken_if2_r, metadata_if2_r, pc_if2_r})
     );

  ///////////////////////////
  // RAS Storage
  ///////////////////////////
  logic ras_valid_lo, ras_call_li, ras_return_li;
  logic [vaddr_width_p-1:0] ras_addr_li;
  bp_fe_ras
   #(.bp_params_p(bp_params_p))
   ras
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.call_i(ras_call_li)
     ,.addr_i(ras_addr_li)

     ,.tgt_o(ras_tgt_lo)
     ,.v_o(ras_valid_lo)
     ,.return_i(ras_return_li)
     );

  // Scan fetched instruction
  bp_fe_instr_scan_s fetch_scan;
  assign fetch_scan = fetch_scan_i;

  assign ras_call_li = fetch_scan.call;
  assign ras_return_li = fetch_scan._return;
  assign ras_addr_li = fetch_pc_i + vaddr_width_p'(4);

  // Override calculations
  wire btb_miss_ras = pc_if1_r != ras_tgt_lo;
  wire btb_miss_br  = pc_if1_r != br_tgt_lo;

  // TODO: ras_valid_lo can degrade performance in some edge cases. However,
  //   the fix for this (recovering the ras stack on misprediction) is the
  //   same amount of work as creating a multiple element ras. So, let's
  //   punt this for now
  wire taken_ret_if2 = fetch_scan._return & ras_valid_lo;
  wire taken_br_if2 = fetch_scan.branch & pred_if1_r;
  wire taken_jmp_if2 = fetch_scan.jal;

  assign ovr_ret    = ~fetch_linear_i & btb_miss_ras & taken_ret_if2;
  assign ovr_btaken = ~fetch_linear_i & btb_miss_br & taken_br_if2;
  assign ovr_jmp    = ~fetch_linear_i & btb_miss_br & taken_jmp_if2;
  assign ovr_ntaken =  fetch_linear_i & taken_if1_r;
  assign ovr_o      = ovr_btaken | ovr_jmp | ovr_ret | ovr_ntaken;

  assign br_tgt_lo     = fetch_pc_i + `BSG_SIGN_EXTEND(fetch_scan.imm20, vaddr_width_p);
  assign linear_tgt_lo = fetch_pc_i + vaddr_width_p'(4);

  assign if2_br_metadata_fwd_o = metadata_if2_r;
  assign if2_pc_o = pc_if2_r;
  assign if2_taken_branch_site_o = taken_if1_r || taken_ret_if2 || taken_br_if2 || taken_jmp_if2;

  ///////////////////////////
  // Global history
  ///////////////////////////
  assign ghistory_n = redirect_br_v_i
    ? redirect_br_metadata_fwd_cast_i.ghist
    : metadata_if2_r.site_br
      ? {ghistory_r[0+:ghist_width_p-1], taken_if2_r}
      : ghistory_r;
  bsg_dff_reset
   #(.width_p(ghist_width_p))
   ghist_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(ghistory_n)
     ,.data_o(ghistory_r)
     );

endmodule


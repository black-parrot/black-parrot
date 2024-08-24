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

   , localparam scan_width_lp = $bits(bp_fe_scan_s)
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
   , input                                           redirect_br_v_i
   , input [branch_metadata_fwd_width_p-1:0]         redirect_br_metadata_fwd_i
   , input                                           redirect_br_taken_i
   , input                                           redirect_br_ntaken_i
   , input                                           redirect_br_nonbr_i

   , output logic [vaddr_width_p-1:0]                next_pc_o
   , input                                           icache_yumi_i

   , output logic                                    ovr_o
   , input                                           icache_tv_we_i

   , input                                           icache_hit_v_i
   , input                                           icache_miss_v_i
   , output logic                                    icache_hit_yumi_o
   , input [icache_data_width_p-1:0]                 icache_data_i

   , output logic                                    if2_hit_v_o
   , output logic                                    if2_miss_v_o
   , output logic [vaddr_width_p-1:0]                if2_pc_o
   , output logic [icache_data_width_p-1:0]          if2_data_o
   , output logic [branch_metadata_fwd_width_p-1:0]  if2_br_metadata_fwd_o
   , input                                           if2_yumi_i

   , input                                           fetch_yumi_i
   , input [scan_width_lp-1:0]                       fetch_scan_i
   , input [vaddr_width_p-1:0]                       fetch_pc_i
   , input [fetch_ptr_p-1:0]                         fetch_count_i
   , input                                           fetch_startup_i
   , input                                           fetch_catchup_i
   , input                                           fetch_rebase_i
   , input                                           fetch_linear_i
   , output logic                                    fetch_taken_o
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
  logic ovr_ret, ovr_btaken, ovr_jmp, ovr_rebase, ovr_linear, btb_taken;
  logic [vaddr_width_p-1:0] pc_plus;
  logic [vaddr_width_p-1:0] ras_tgt_lo, taken_tgt_lo, ntaken_tgt_lo, linear_tgt_lo;
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
        next_pc    = ovr_ret ? ras_tgt_lo : (ovr_btaken | ovr_jmp) ? taken_tgt_lo : ovr_rebase ? ntaken_tgt_lo : linear_tgt_lo;

        next_metadata = ovr_metadata;
        next_metadata.src_ras = ovr_ret;
      end
    else
      begin
        next_pred  = bht_pred_lo;
        next_taken = btb_taken;
        next_pc    = btb_taken ? btb_br_tgt_lo : pc_plus;

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
  wire btb_r_v_li = icache_yumi_i;
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
  wire bht_r_v_li = icache_yumi_i;
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
  bp_fe_branch_metadata_fwd_s metadata_if1_r;
  logic pred_if1_r, taken_if1_r;
  logic [vaddr_width_p-1:0] pc_if1, pc_if1_r, pc_if1_aligned;
  bsg_dff_reset_en
   #(.width_p(2+branch_metadata_fwd_width_p+vaddr_width_p))
   if1_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(icache_yumi_i)

     ,.data_i({next_pred, next_taken, next_metadata, next_pc})
     ,.data_o({pred_if1_r, taken_if1_r, metadata_if1_r, pc_if1_r})
     );

  // Scan fetched instruction
  bp_fe_scan_s fetch_scan;
  assign fetch_scan = fetch_scan_i;

  // Set the site type as it arrives in IF2
  bp_fe_branch_metadata_fwd_s metadata_if1;
  always_comb
    begin
      metadata_if1 = metadata_if1_r;

      if (fetch_yumi_i)
        begin
          metadata_if1.site_br     = fetch_scan.br;
          metadata_if1.site_jal    = fetch_scan.jal;
          metadata_if1.site_jalr   = fetch_scan.jalr;
          metadata_if1.site_call   = fetch_scan.call;
          metadata_if1.site_return = fetch_scan._return;
        end
    end
  assign ovr_metadata = metadata_if1;

  localparam icache_bytes_lp = icache_data_width_p >> 3;
  assign pc_if1_aligned = `bp_addr_align(pc_if1_r, icache_bytes_lp);
  assign pc_if1 = fetch_catchup_i ? ntaken_tgt_lo : pc_if1_r;

  assign btb_taken = btb_br_tgt_v_lo & (bht_pred_lo | btb_br_tgt_jmp_lo);
  assign pc_plus = pc_if1_aligned + icache_bytes_lp;

  /////////////////////////////////////////////////////////////////////////////////////
  // IF2
  /////////////////////////////////////////////////////////////////////////////////////
  bp_fe_branch_metadata_fwd_s metadata_if2_n, metadata_if2_r, metadata_if2;
  logic pred_if2_r, taken_if2_r;
  logic [vaddr_width_p-1:0] pc_if2, pc_if2_r, pc_if2_aligned;

  assign metadata_if2_n = fetch_startup_i ? metadata_if2 : metadata_if1;
  bsg_dff_reset_en
   #(.width_p(2+vaddr_width_p+branch_metadata_fwd_width_p))
   if2_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(icache_tv_we_i | fetch_catchup_i)

     ,.data_i({pred_if1_r, taken_if1_r, pc_if1, metadata_if2_n})
     ,.data_o({pred_if2_r, taken_if2_r, pc_if2_r, metadata_if2_r})
     );

  always_comb
    begin
      metadata_if2 = metadata_if2_r;

      metadata_if2.ras_next = ras_next;
      metadata_if2.ras_tos  = ras_tos;
    end

  assign pc_if2 = pc_if2_r;
  assign pc_if2_aligned = `bp_addr_align(pc_if2, icache_bytes_lp);

  assign if2_hit_v_o = icache_hit_v_i;
  assign if2_miss_v_o = icache_miss_v_i;
  assign if2_pc_o = pc_if2_r;
  assign if2_data_o = icache_data_i;
  assign if2_br_metadata_fwd_o = metadata_if2;
  assign icache_hit_yumi_o = icache_hit_v_i & if2_yumi_i;

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

  assign linear_tgt_lo = fetch_pc_i + fetch_scan.linear_imm;
  assign ntaken_tgt_lo = fetch_pc_i + fetch_scan.ntaken_imm;
  assign taken_tgt_lo  = fetch_pc_i + fetch_scan.taken_imm;

  assign ras_call_li = fetch_yumi_i & fetch_scan.call;
  assign ras_return_li = fetch_yumi_i & fetch_scan._return;
  assign ras_addr_li = ntaken_tgt_lo;

  // Override calculations
  wire btb_miss_ras = pc_if1_r != ras_tgt_lo;
  wire btb_miss_br  = pc_if1_r != taken_tgt_lo;
  wire rebase_miss  = !taken_if1_r;
  wire linear_miss  =  taken_if1_r;

  assign ovr_ret     = btb_miss_ras & fetch_scan._return & ras_valid_lo;
  assign ovr_btaken  = btb_miss_br  & fetch_scan.br & pred_if1_r;
  assign ovr_jmp     = btb_miss_br  & fetch_scan.jal;
  assign ovr_linear  = linear_miss  & fetch_linear_i;
  assign ovr_rebase  = rebase_miss  & fetch_rebase_i;
  assign ovr_o       = ovr_btaken | ovr_jmp | ovr_ret | ovr_linear | ovr_rebase;

  assign fetch_taken_o = taken_if1_r | ovr_ret | ovr_btaken | ovr_jmp;

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
  wire ghistory_w_v = redirect_br_v_i | icache_tv_we_i;
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


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
   , input                                           redirect_resume_v_i
   , input [instr_half_width_gp-1:0]                 redirect_resume_instr_i

   , output logic [vaddr_width_p-1:0]                next_pc_o
   , input                                           if1_we_i

   , output logic                                    ovr_o
   , input                                           if2_we_i

   , input [instr_width_gp-1:0]                      fetch_i
   , input                                           fetch_v_i
   , output [instr_width_gp-1:0]                     fetch_instr_o
   , output                                          fetch_instr_v_o
   , input                                           fetch_instr_yumi_i
   , output logic [branch_metadata_fwd_width_p-1:0]  fetch_br_metadata_fwd_o
   , output logic [vaddr_width_p-1:0]                fetch_pc_o
   , output                                          fetch_is_second_half_o

   , input [vaddr_width_p-1:0]                       attaboy_pc_i
   , input [branch_metadata_fwd_width_p-1:0]         attaboy_br_metadata_fwd_i
   , input                                           attaboy_taken_i
   , input                                           attaboy_ntaken_i
   , input                                           attaboy_v_i
   , output logic                                    attaboy_yumi_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_width_p);

  bp_fe_branch_metadata_fwd_s redirect_br_metadata_fwd;
  assign redirect_br_metadata_fwd = redirect_br_metadata_fwd_i;
  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd;
  assign attaboy_br_metadata_fwd = attaboy_br_metadata_fwd_i;

  // Global signals
  logic fetch_instr_br_v_li, fetch_instr_jal_v_li, fetch_instr_jalr_v_li;
  logic fetch_instr_call_v_li, fetch_instr_return_v_li;

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
  logic [vaddr_width_p-1:0] pc_plus4_if2;
  logic [btb_tag_width_p-1:0] btb_tag_if1;
  logic [btb_idx_width_p-1:0] btb_idx_if1;
  logic [bht_idx_width_p-1:0] bht_idx_if1;


  // Note: "if" chain duplicated in in bp_fe_nonsynth_pc_gen_tracer.sv
  always_comb begin
    if (redirect_v_i)
      begin
        next_pred  = redirect_br_taken_i;
        next_taken = redirect_br_taken_i;
        next_pc    = redirect_pc_i;

        next_metadata = redirect_br_metadata_fwd;
      end
    else if (ovr_ntaken) begin
        next_pred  = '0;
        next_pc           = pc_plus4_if2;
        next_taken = '0;
    end else if (ovr_o)
      begin
        next_pred  = ovr_btaken;
        next_taken = ovr_ret | ovr_btaken | ovr_jmp;
        next_pc    = ovr_ret ? ras_tgt_lo : br_tgt_lo;

        next_metadata = ovr_metadata;
        next_metadata.site_br     = fetch_instr_br_v_li;
        next_metadata.site_jal    = fetch_instr_jal_v_li;
        next_metadata.site_jalr   = fetch_instr_jalr_v_li;
        next_metadata.site_call   = fetch_instr_call_v_li;
        next_metadata.site_return = fetch_instr_return_v_li;
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
        next_metadata.btb_tag = btb_tag_if1;
        next_metadata.btb_idx = btb_idx_if1;
        next_metadata.bht_idx = bht_idx_if1;
      end
  end
  assign next_pc_o = next_pc;

  ///////////////////////////
  // BTB
  ///////////////////////////
  logic btb_w_yumi_lo, btb_init_done_lo; 
  wire btb_r_v_li = if1_we_i;
  wire btb_w_v_li = (redirect_br_v_i & redirect_br_taken_i)
    | (redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd.src_btb)
    | (attaboy_v_i & attaboy_taken_i & (~attaboy_br_metadata_fwd.src_btb | attaboy_br_metadata_fwd.src_ras));
  wire btb_clr_li = redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd.src_btb;
  wire btb_jmp_li = redirect_br_v_i ? (redirect_br_metadata_fwd.site_jal | redirect_br_metadata_fwd.site_jalr) : (attaboy_br_metadata_fwd.site_jal | attaboy_br_metadata_fwd.site_jalr);
  wire [btb_tag_width_p-1:0] btb_tag_li = redirect_br_v_i ? redirect_br_metadata_fwd.btb_tag : attaboy_br_metadata_fwd.btb_tag;
  wire [btb_idx_width_p-1:0] btb_idx_li = redirect_br_v_i ? redirect_br_metadata_fwd.btb_idx : attaboy_br_metadata_fwd.btb_idx;
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
    (redirect_br_v_i & redirect_br_metadata_fwd.site_br) | (attaboy_v_i & attaboy_br_metadata_fwd.site_br);
  wire [bht_idx_width_p-1:0] bht_w_idx_li =
    redirect_br_v_i ? redirect_br_metadata_fwd.bht_idx : attaboy_br_metadata_fwd.bht_idx;
  wire [ghist_width_p-1:0] bht_w_ghist_li =
    redirect_br_v_i ? redirect_br_metadata_fwd.ghist : attaboy_br_metadata_fwd.ghist;
  wire [bht_row_width_p-1:0] bht_row_li =
    redirect_br_v_i ? redirect_br_metadata_fwd.bht_row : attaboy_br_metadata_fwd.bht_row;
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
      metadata_if1.site_br     |= fetch_instr_br_v_li;
      metadata_if1.site_jal    |= fetch_instr_jal_v_li;
      metadata_if1.site_jalr   |= fetch_instr_jalr_v_li;
      metadata_if1.site_call   |= fetch_instr_call_v_li;
      metadata_if1.site_return |= fetch_instr_return_v_li;
    end

  // TODO: mask all usages of BTB and BHT outputs if read was not performed last cycle
  assign btb_taken = btb_br_tgt_v_lo & (bht_pred_lo | btb_br_tgt_jmp_lo);
  assign pc_plus4  = pc_if1_r + vaddr_width_p'(4);

  assign btb_tag_if1 = pc_if1_r[btb_ignored_bits_p+btb_idx_width_p+:btb_tag_width_p];
  assign btb_idx_if1 = pc_if1_r[btb_ignored_bits_p+:btb_idx_width_p];
  assign bht_idx_if1 = pc_if1_r[bht_ignored_bits_p+:bht_idx_width_p];

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

  assign pc_plus4_if2 = pc_if2_r + vaddr_width_p'(4);

  // Scan fetched instruction
  bp_fe_instr_scan_s scan_instr;
  logic [vaddr_width_p-1:0] scan_imm;
  bp_fe_instr_scan
   #(.bp_params_p(bp_params_p))
   instr_scan
    (.instr_i(fetch_instr_o)
     ,.scan_o(scan_instr)
     ,.imm_o(scan_imm)
     );

  assign fetch_instr_br_v_li   = fetch_instr_yumi_i & scan_instr.branch;
  assign fetch_instr_jal_v_li  = fetch_instr_yumi_i & scan_instr.jal;
  assign fetch_instr_jalr_v_li = fetch_instr_yumi_i & scan_instr.jalr;
  assign fetch_instr_call_v_li = fetch_instr_yumi_i & scan_instr.call;
  assign fetch_instr_return_v_li = fetch_instr_yumi_i & scan_instr._return;

  ///////////////////////////
  // RAS
  ///////////////////////////
  logic ras_valid_lo;
  wire [vaddr_width_p-1:0] return_addr_if2 = fetch_pc_o + vaddr_width_p'(4);
  bp_fe_ras
   #(.bp_params_p(bp_params_p))
   ras
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.call_i(fetch_instr_call_v_li)
     ,.return_i(fetch_instr_return_v_li)

     ,.addr_i(return_addr_if2)
     ,.tgt_o(ras_tgt_lo)
     ,.v_o(ras_valid_lo)
     );

  // Override calculations
  // TODO: ras_valid_lo can degrade performance in some edge cases. However,
  //   the fix for this (recovering the ras stack on misprediction) is the
  //   same amount of work as creating a multiple element ras. So, let's
  //   punt this for now
  wire btb_miss_ras = pc_if1_r != ras_tgt_lo;
  wire btb_miss_br  = pc_if1_r != br_tgt_lo;

  wire taken_ret_if2 = fetch_instr_return_v_li & ras_valid_lo;
  wire taken_br_if2 = fetch_instr_br_v_li & pred_if1_r;

  wire taken_jump_site_if2 = taken_if1_r || taken_ret_if2 || taken_br_if2 || ovr_jmp;
  wire pc_if2_misaligned = !`bp_addr_is_aligned(pc_if2_r, rv64_instr_width_bytes_gp);

  assign ovr_ret    = btb_miss_ras & taken_ret_if2;
  assign ovr_btaken = btb_miss_br & taken_br_if2;
  assign ovr_jmp    = btb_miss_br & fetch_instr_jal_v_li;
  assign ovr_ntaken = compressed_support_p
                    & fetch_v_i
                    & taken_if1_r
                    & (  (!fetch_is_second_half_o && pc_if2_misaligned)
                      || ( fetch_is_second_half_o && !taken_jump_site_if2 )
                      || ( fetch_is_second_half_o && !fetch_instr_v_o ));
  wire fetch_half_v =    (!fetch_is_second_half_o && pc_if2_misaligned)
                      || ( fetch_is_second_half_o && !taken_jump_site_if2 );
  assign ovr_o      = ovr_btaken | ovr_jmp | ovr_ret | ovr_ntaken;
  assign br_tgt_lo  = fetch_pc_o + scan_imm;

  assign fetch_resume_pc_o = pc_if2_r;
  assign fetch_br_metadata_fwd_o = metadata_if2_r;

  if (compressed_support_p)
    begin : fetch_instr_generation
      bp_fe_realigner
        #(.bp_params_p(bp_params_p))
        realigner
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.fetch_v_i      (fetch_v_i)
        ,.fetch_store_v_i(fetch_half_v)
        ,.fetch_pc_i     (pc_if2_r)
        ,.fetch_data_i   (fetch_i)

        ,.redirect_v_i      (redirect_v_i)
        ,.redirect_resume_i (redirect_resume_v_i)
        ,.redirect_partial_i(redirect_resume_instr_i)
        ,.redirect_vaddr_i  (redirect_pc_i)

        ,.fetch_instr_pc_o      (fetch_pc_o)
        ,.fetch_instr_o         (fetch_instr_o)
        ,.fetch_instr_v_o       (fetch_instr_v_o)
        ,.fetch_is_second_half_o(fetch_is_second_half_o)
        ,.fetch_instr_yumi_i    (fetch_instr_yumi_i)
        );

      // Debug signals for pc_gen_tracer
      wire                           half_buffer_v_r  = realigner.half_buffer_v_r;
      wire [vaddr_width_p-1:0]       fetch_instr_pc_r = realigner.fetch_instr_pc_r;
      wire [instr_half_width_gp-1:0] half_buffer_r    = realigner.half_buffer_r;
    end
  else
    begin : fetch_instr_generation
      assign fetch_pc_o      = pc_if2_r;
      assign fetch_instr_o   = fetch_i;
      assign fetch_instr_v_o = fetch_v_i;
      assign fetch_is_second_half_o = 0;

      // Debug signals for pc_gen_tracer
      wire                           half_buffer_v_r  = '0;
      wire [vaddr_width_p-1:0]       fetch_instr_pc_r = '0;
      wire [instr_half_width_gp-1:0] half_buffer_r    = '0;
    end

  // Global history
  ///////////////////////////
  assign ghistory_n = redirect_br_v_i
    ? redirect_br_metadata_fwd.ghist
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

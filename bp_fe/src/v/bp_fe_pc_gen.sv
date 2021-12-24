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

   , output logic [vaddr_width_p-1:0]                next_fetch_o
   , input                                           next_pc_yumi_i

   , output logic                                    ovr_o

   , input [instr_width_gp-1:0]                      fetch_i
   , input                                           fetch_v_i
   , output logic [branch_metadata_fwd_width_p-1:0]  fetch_br_metadata_fwd_o
   , output logic [vaddr_width_p-1:0]                fetch_pc_o
   , output logic [instr_width_gp-1:0]               fetch_instr_o
   , output logic                                    fetch_instr_v_o
   , output logic                                    fetch_instr_progress_o
   , input                                           fetch_instr_ready_i

   , input [vaddr_width_p-1:0]                       attaboy_pc_i
   , input [branch_metadata_fwd_width_p-1:0]         attaboy_br_metadata_fwd_i
   , input                                           attaboy_taken_i
   , input                                           attaboy_ntaken_i
   , input                                           attaboy_v_i
   , output logic                                    attaboy_yumi_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_width_p);
  `declare_bp_fe_pred_s(vaddr_width_p, ghist_width_p, bht_row_width_p);

  bp_fe_branch_metadata_fwd_s redirect_br_metadata_fwd;
  assign redirect_br_metadata_fwd = redirect_br_metadata_fwd_i;
  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd;
  assign attaboy_br_metadata_fwd = attaboy_br_metadata_fwd_i;

  logic [ghist_width_p-1:0] ghistory_n, ghistory_r;

  logic [vaddr_width_p-1:0] pc_if1_n, pc_if1_r;
  logic [vaddr_width_p-1:0] pc_if2_n, pc_if2_r;

  // "logical" fetch address (next_logical_fetch_address) points to the start of the next instruction to be fetched.
  // It is the pre-alignment analogue to the aligned fetch address (next_fetch_o), which is the actual aligned
  // halfword to be fetched.
  logic [vaddr_width_p-1:0] next_logical_fetch_address;
  assign next_fetch_o = `bp_align_addr(next_logical_fetch_address, vaddr_width_p, rv64_instr_width_bytes_gp); 

  logic [vaddr_width_p-1:0] fetch_addr_if1_n, fetch_addr_if1_r;
  logic fetch_linear_if1_n, fetch_linear_if1_r;

  /////////////////
  // IF1
  /////////////////
  bp_fe_pred_s pred_if1_n, pred_if1_r;
  bp_fe_pred_s effective_pred_if1;
  logic next_fetch_linear;
  logic ovr_ret, ovr_taken, btb_taken;
  logic [vaddr_width_p-1:0] btb_br_tgt_lo;
  logic [vaddr_width_p-1:0] ras_tgt_lo;
  logic [vaddr_width_p-1:0] br_tgt_lo;
  wire [vaddr_width_p-1:0] last_fetch_plus4 = fetch_addr_if1_r + vaddr_width_p'(4);
  always_comb
    begin
      next_fetch_linear = 1'b0;
      if (redirect_v_i)
          next_logical_fetch_address = redirect_pc_i;
      else if (ovr_ret)
          next_logical_fetch_address = ras_tgt_lo;
      else if (ovr_taken)
          next_logical_fetch_address = br_tgt_lo;
      else if (btb_taken)
          next_logical_fetch_address = effective_pred_if1.btb_tgt;
      else
        begin
          next_fetch_linear = 1'b1;
          next_logical_fetch_address = last_fetch_plus4;
        end
    end

  logic [instr_width_gp-1:0] next_pc;
  wire last_fetch_misaligned = !`bp_addr_is_aligned(fetch_addr_if1_r, rv64_instr_width_bytes_gp);
  always_comb
    // "hold back" the PC for one cycle while executing misaligned instructions, since fetching a halfword resolves the
    // pc which started in the previous one.
    if (last_fetch_misaligned && next_fetch_linear)
      next_pc = fetch_addr_if1_r;
    else
      next_pc = next_logical_fetch_address;

  assign pc_if1_n             = next_pc;
  assign fetch_addr_if1_n     = next_logical_fetch_address;
  assign fetch_linear_if1_n   = next_fetch_linear;

  always_comb
    begin
      pred_if1_n = '0;
      pred_if1_n.ghist = ghistory_n;
      pred_if1_n.redir = redirect_br_v_i;
      pred_if1_n.taken = (redirect_br_v_i & redirect_br_taken_i) | ovr_ret | ovr_taken;
      pred_if1_n.ret   = ovr_ret & ~redirect_v_i;
    end

  bsg_dff
   #(.width_p($bits(bp_fe_pred_s)+vaddr_width_p*2+1))
   pred_if1_reg
    (.clk_i(clk_i)

     ,.data_i({pred_if1_n, pc_if1_n, fetch_addr_if1_n, fetch_linear_if1_n})
     ,.data_o({pred_if1_r, pc_if1_r, fetch_addr_if1_r, fetch_linear_if1_r})
     );

  wire pc_aligned_if1 = `bp_addr_is_aligned(pc_if1_r, rv64_instr_width_bytes_gp); // TODO: misaligend -> aligned

  `declare_bp_fe_instr_scan_s(vaddr_width_p)
  bp_fe_instr_scan_s fetch_instr_scan_lo;
  wire is_br   = fetch_instr_v_o & fetch_instr_scan_lo.branch;
  wire is_jal  = fetch_instr_v_o & fetch_instr_scan_lo.jal;
  wire is_jalr = fetch_instr_v_o & fetch_instr_scan_lo.jalr;
  wire is_call = fetch_instr_v_o & fetch_instr_scan_lo.call;
  wire is_ret  = fetch_instr_v_o & fetch_instr_scan_lo.ret;

  // BTB
  wire btb_r_v_li = next_pc_yumi_i & ~ovr_taken & ~ovr_ret;
  wire btb_w_v_li = (redirect_br_v_i & redirect_br_taken_i)
    | (redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd.src_btb)
    | (attaboy_v_i & attaboy_taken_i & ~attaboy_br_metadata_fwd.src_btb);
  wire btb_clr_li = redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd.src_btb;
  wire btb_jmp_li = redirect_br_v_i ? (redirect_br_metadata_fwd.is_jal | redirect_br_metadata_fwd.is_jalr) : (attaboy_br_metadata_fwd.is_jal | attaboy_br_metadata_fwd.is_jalr);
  wire [btb_tag_width_p-1:0] btb_tag_li = redirect_br_v_i ? redirect_br_metadata_fwd.btb_tag : attaboy_br_metadata_fwd.btb_tag;
  wire [btb_idx_width_p-1:0] btb_idx_li = redirect_br_v_i ? redirect_br_metadata_fwd.btb_idx : attaboy_br_metadata_fwd.btb_idx;
  wire [vaddr_width_p-1:0]   btb_tgt_li = redirect_br_v_i ? redirect_pc_i : attaboy_pc_i;

  logic btb_init_done_lo;
  logic btb_br_tgt_v_lo;
  logic btb_br_tgt_jmp_lo;
  logic btb_w_yumi_lo;
  bp_fe_btb
   #(.bp_params_p(bp_params_p))
   btb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.init_done_o(btb_init_done_lo)

     ,.r_addr_i(next_fetch_o)
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
     );

  // BHT
  wire bht_r_v_li = next_pc_yumi_i & ~ovr_taken & ~ovr_ret;
  wire [vaddr_width_p-1:0] bht_r_addr_li = next_fetch_o;
  wire [ghist_width_p-1:0] bht_r_ghist_li = pred_if1_n.ghist;
  wire bht_w_v_li =
    (redirect_br_v_i & redirect_br_metadata_fwd.is_br) | (attaboy_v_i & attaboy_br_metadata_fwd.is_br);
  wire [bht_idx_width_p-1:0] bht_w_idx_li =
    redirect_br_v_i ? redirect_br_metadata_fwd.bht_idx : attaboy_br_metadata_fwd.bht_idx;
  wire [ghist_width_p-1:0] bht_w_ghist_li =
    redirect_br_v_i ? redirect_br_metadata_fwd.ghist : attaboy_br_metadata_fwd.ghist;
  wire [bht_row_width_p-1:0] bht_row_li =
    redirect_br_v_i ? redirect_br_metadata_fwd.bht_row : attaboy_br_metadata_fwd.bht_row;
  logic [bht_row_width_p-1:0] bht_row_lo;
  logic bht_pred_lo, bht_w_yumi_lo, bht_init_done_lo;
  bp_fe_bht
   #(.bp_params_p(bp_params_p))
   bht
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.init_done_o(bht_init_done_lo)

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
     );

  // The realigner requires two consecutive fetches (i.e., the latter one is "linear") to
  // reconstruct a misaligned instruction. Don't issue prediction until we have both halves.
  wire if1_v       = pc_aligned_if1 | fetch_linear_if1_r;
  assign btb_taken = if1_v & effective_pred_if1.btb & (effective_pred_if1.pred | effective_pred_if1.btb_jmp);

  // RAS
  // Avoid writing when an exception or redirect is going to discard this state anyway
  wire ras_write_v = is_call && fetch_instr_v_o && fetch_instr_ready_i;
  logic [vaddr_width_p-1:0] return_addr_n, return_addr_r;
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p))
   ras
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ras_write_v)

     ,.data_i(return_addr_n)
     ,.data_o(return_addr_r)
     );
  assign ras_tgt_lo = return_addr_r;

  assign attaboy_yumi_o = attaboy_v_i & ~(bht_w_v_li & ~bht_w_yumi_lo) & ~(btb_w_v_li & ~btb_w_yumi_lo);

  /////////////////
  // IF2
  /////////////////
  bp_fe_pred_s pred_if2_n, pred_if2_r;
  always_comb
    if (~pred_if1_r.redir)
      begin
        pred_if2_n = pred_if1_r;
        pred_if2_n.pred    = bht_pred_lo;
        pred_if2_n.taken   = btb_taken;
        pred_if2_n.btb     = btb_br_tgt_v_lo;
        pred_if2_n.btb_jmp = btb_br_tgt_jmp_lo;
        pred_if2_n.btb_tgt = btb_br_tgt_lo;
        pred_if2_n.bht_row = bht_row_lo;
      end
    else
      begin
        pred_if2_n = pred_if1_r;
      end
  assign pc_if2_n          = pc_if1_r;

  logic fetch_linear_if2_r;
  bp_fe_pred_s effective_pred_if2;
  bsg_dff
   #(.width_p($bits(bp_fe_pred_s)+vaddr_width_p+1))
   pred_if2_reg
    (.clk_i(clk_i)

     ,.data_i({pred_if2_n, pc_if2_n, fetch_linear_if1_r})
     ,.data_o({pred_if2_r, pc_if2_r, fetch_linear_if2_r})
     );
  assign return_addr_n = pc_if2_r + vaddr_width_p'(4);
  wire pc_aligned_if2 = `bp_addr_is_aligned(pc_if2_r, rv64_instr_width_bytes_gp);

  wire if2_v        = pc_aligned_if2 | fetch_linear_if2_r;
  // TODO: implicitly accept+handle mispredicts which happen to fall within the already-in-flight fetch
  wire btb_miss_ras = pc_if1_r != ras_tgt_lo;
  wire btb_miss_br  = pc_if1_r != br_tgt_lo;
  assign ovr_ret    = if2_v && btb_miss_ras & is_ret;
  assign ovr_taken  = if2_v && btb_miss_br & ((is_br & effective_pred_if2.pred) | is_jal);
  assign ovr_o      = ovr_taken | ovr_ret;
  assign br_tgt_lo  = pc_if2_r + fetch_instr_scan_lo.imm;
  assign fetch_pc_o = pc_if2_r;

  bp_fe_branch_metadata_fwd_s br_metadata_site;
  assign fetch_br_metadata_fwd_o = br_metadata_site;
  always_ff @(posedge clk_i)
    if (fetch_instr_v_o && fetch_instr_ready_i)
      br_metadata_site <=
        '{src_btb  : effective_pred_if2.btb
          ,src_ret : effective_pred_if2.ret
          ,ghist   : effective_pred_if2.ghist
          ,bht_row : effective_pred_if2.bht_row
          ,btb_tag : pc_if2_r[2+btb_idx_width_p+:btb_tag_width_p]
          ,btb_idx : pc_if2_r[2+:btb_idx_width_p]
          ,bht_idx : pc_if2_r[2+:bht_idx_width_p]
          ,is_br   : is_br
          ,is_jal  : is_jal
          ,is_jalr : is_jalr
          ,is_call : is_call
          ,is_ret  : is_ret
          };

  // Reconstruct fetched instruction (when misaligned)
  bp_fe_realigner
   #(.bp_params_p(bp_params_p))
   realigner
     (.clk_i   (clk_i)
      ,.reset_i(reset_i)

      ,.fetch_addr_i      (fetch_pc_o)
      ,.fetch_linear_i    (fetch_linear_if2_r)
      ,.fetch_data_i      (fetch_i)
      ,.fetch_data_v_i    (fetch_v_i)

      ,.fetch_instr_o     (fetch_instr_o)
      ,.fetch_instr_v_o   (fetch_instr_v_o)
      ,.fetch_instr_progress_o(fetch_instr_progress_o)
     );

  // Scan fetched instruction
  bp_fe_instr_scan
   #(.bp_params_p(bp_params_p))
   instr_scan
    (.instr_i(fetch_instr_o)

     ,.scan_o(fetch_instr_scan_lo)
     );

  // Global history
  //
  wire ghistory_w_v_li = (is_br & fetch_instr_v_o) | redirect_br_v_i;
  assign ghistory_n = redirect_br_v_i
    ? redirect_br_metadata_fwd.ghist
    : {ghistory_r[0+:ghist_width_p-1], effective_pred_if2.taken};
  bsg_dff_reset_en
   #(.width_p(ghist_width_p))
   ghist_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ghistory_w_v_li)

     ,.data_i(ghistory_n)
     ,.data_o(ghistory_r)
     );

  assign init_done_o = bht_init_done_lo & btb_init_done_lo;

  // Pred data for "IF3", used only for misaligned instructions to look up their prediction in IF2
  // for their second half using data retrieved when fetching their first half
  bp_fe_pred_s pred_if3_r;
  bsg_dff
   #(.width_p($bits(bp_fe_pred_s)))
   pred_if3_reg
    (.clk_i(clk_i)

     ,.data_i(pred_if2_r)
     ,.data_o(pred_if3_r)
     );

  // Predictions are done on the address of the useful data currently being fetched. Sometimes, this
  // is the address of an instruction we are only fetching the first half of; the second half will
  // come next cycle. effective_pred_if1 is the prediction data for the pc in if1 normally,
  // but overridden to be that for if2 when the if1 fetch isn't going to resolve a whole instruction
  // until next cycle. Equivalently for IF2, using either the data in IF2 or IF3.

  assign effective_pred_if1 = (!pc_aligned_if1 && fetch_linear_if1_r) ? pred_if2_r : pred_if2_n;
  assign effective_pred_if2 = (!pc_aligned_if2 && fetch_linear_if2_r) ? pred_if3_r : pred_if2_r;

endmodule


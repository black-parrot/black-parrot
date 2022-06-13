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
   , input                                           next_fetch_yumi_i

   , output logic                                    ovr_o

   , input [instr_width_gp-1:0]                      fetch_i
   , input                                           fetch_v_i
   , output [instr_width_gp-1:0]                     fetch_instr_o
   , output                                          fetch_instr_v_o
   , input                                           fetch_exception_v_i
   , output logic [branch_metadata_fwd_width_p-1:0]  fetch_br_metadata_fwd_o
   , output logic [vaddr_width_p-1:0]                fetch_pc_o

   , input [vaddr_width_p-1:0]                       attaboy_pc_i
   , input [branch_metadata_fwd_width_p-1:0]         attaboy_br_metadata_fwd_i
   , input                                           attaboy_taken_i
   , input                                           attaboy_ntaken_i
   , input                                           attaboy_v_i
   , output logic                                    attaboy_yumi_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_width_p);
  `declare_bp_fe_pc_gen_stage_s(vaddr_width_p, ghist_width_p, bht_row_width_p);

  bp_fe_branch_metadata_fwd_s redirect_br_metadata_fwd;
  assign redirect_br_metadata_fwd = redirect_br_metadata_fwd_i;
  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd;
  assign attaboy_br_metadata_fwd = attaboy_br_metadata_fwd_i;

  logic [ghist_width_p-1:0] ghistory_n, ghistory_r;

  logic [vaddr_width_p-1:0] pc_if1_n, pc_if1_r;
  logic fetch_linear_if1_n, fetch_linear_if1_r;
  logic [vaddr_width_p-1:0] pc_if2_n, pc_if2_r;
  logic fetch_linear_if2_n, fetch_linear_if2_r;

  /////////////////
  // IF1
  /////////////////
  logic incomplete_fetch_if1_r, incomplete_fetch_if1_n;
  bp_fe_pred_s pred_if1_n, pred_if1_r;
  logic [vaddr_width_p-1:0] next_pc;
  logic next_pc_linear;
  logic ovr_ret, ovr_taken, btb_taken;
  logic [vaddr_width_p-1:0] btb_br_tgt_lo;
  logic [vaddr_width_p-1:0] ras_tgt_lo;
  logic [vaddr_width_p-1:0] br_tgt_lo;
  wire [vaddr_width_p-1:0] pc_plus4  = pc_if1_r + vaddr_width_p'(4);
  always_comb begin
    next_pc_linear = 1'b0;
    if (redirect_v_i)
        next_pc = redirect_pc_i;
    else if (ovr_ret)
        next_pc = ras_tgt_lo;
    else if (ovr_taken)
        next_pc = br_tgt_lo;
    else if (incomplete_fetch_if1_r)
        // TODO: verify nonlinear works
        next_pc = pc_if1_r;
    else if (btb_taken)
        next_pc = btb_br_tgt_lo;
    else
      begin
        next_pc = pc_plus4;
        next_pc_linear = 1'b1;
      end
  end
  assign pc_if1_n = next_pc;
  assign fetch_linear_if1_n = next_pc_linear;

  // wire [vaddr_width_p-1:0] next_pc_plus4 = next_pc + vaddr_width_p'(4);
  // wire next_pc_rounded_up = `bp_align_addr(next_pc_plus4, rv64_instr_width_gp);
  // wire next_pc_rounded_down = `bp_align_addr(next_pc, rv64_instr_width_gp);

  wire next_pc_misaligned = !`bp_addr_is_aligned(next_pc, rv64_instr_width_bytes_gp);
  assign next_fetch_o = (next_pc_misaligned & next_pc_linear)
    ? `bp_align_addr_up(next_pc, rv64_instr_width_bytes_gp)
    : `bp_align_addr_down(next_pc, rv64_instr_width_bytes_gp);
  assign incomplete_fetch_if1_n = !next_pc_linear & next_pc_misaligned;

  always_comb
    begin
      pred_if1_n = '0;
      // TODO: verify pred data
      pred_if1_n.ghist = ghistory_n;
      pred_if1_n.redir = redirect_br_v_i;
      pred_if1_n.taken = (redirect_br_v_i & redirect_br_taken_i) | ovr_ret | ovr_taken;
      pred_if1_n.ret   = ovr_ret & ~redirect_v_i;
    end

  bsg_dff
   #(.width_p($bits(bp_fe_pred_s)+vaddr_width_p+2))
   pred_if1_reg
    (.clk_i(clk_i)

     ,.data_i({pred_if1_n, pc_if1_n, incomplete_fetch_if1_n, fetch_linear_if1_n})
     ,.data_o({pred_if1_r, pc_if1_r, incomplete_fetch_if1_r, fetch_linear_if1_r})
     );

  `declare_bp_fe_instr_scan_s(vaddr_width_p)
  bp_fe_instr_scan_s scan_instr;
  // TODO: does validity of scan_instr matter?
  wire is_br   = fetch_instr_v_o & scan_instr.branch;
  wire is_jal  = fetch_instr_v_o & scan_instr.jal;
  wire is_jalr = fetch_instr_v_o & scan_instr.jalr;
  wire is_call = fetch_instr_v_o & scan_instr.call;
  wire is_ret  = fetch_instr_v_o & scan_instr.ret;

  // BTB
  wire btb_r_v_li = next_fetch_yumi_i;
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
     ,.r_v_i(btb_r_v_li) // TODO: technically could disable read for incomplete first half
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
  wire bht_r_v_li = next_fetch_yumi_i;
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
  assign btb_taken = btb_br_tgt_v_lo & (bht_pred_lo | btb_br_tgt_jmp_lo);

  // RAS
  logic [vaddr_width_p-1:0] return_addr_n, return_addr_r;
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p))
   ras
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(is_call)

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
        pred_if2_n.bht_row = bht_row_lo;
      end
    else
      begin
        pred_if2_n = pred_if1_r;
      end
  assign pc_if2_n = pc_if1_r;
  assign fetch_linear_if2_n = fetch_linear_if1_r;

  bsg_dff
   #(.width_p($bits(bp_fe_pred_s)+vaddr_width_p+1))
   pred_if2_reg
    (.clk_i(clk_i)

     ,.data_i({pred_if2_n, pc_if2_n, fetch_linear_if2_n})
     ,.data_o({pred_if2_r, pc_if2_r, fetch_linear_if2_r})
     );
  assign return_addr_n = pc_if2_r + vaddr_width_p'(4);

  wire btb_miss_ras = pc_if1_r != ras_tgt_lo;
  wire btb_miss_br  = pc_if1_r != br_tgt_lo;
  assign ovr_ret    = btb_miss_ras & is_ret;
  assign ovr_taken  = btb_miss_br & ((is_br & pred_if2_r.pred) | is_jal);
  assign ovr_o      = ovr_taken | ovr_ret;
  assign br_tgt_lo  = pc_if2_r + scan_instr.imm;
  assign fetch_pc_o = pc_if2_r;

  // wire pc_if2_misaligned =  !`bp_addr_is_aligned(pc_if2_r, rv64_instr_width_bytes_gp);
  // logic [vaddr_width_p-1:0] branch_prediction_source_addr_if2 = pc_if2_misaligned ? `bp_align_addr_up(pc_if2_r, rv64_instr_width_bytes_gp) : pc_if2_r;

  logic [vaddr_width_p-1:0] branch_prediction_source_addr_if2 = `bp_align_addr_up(pc_if2_r, rv64_instr_width_bytes_gp);

  bp_fe_branch_metadata_fwd_s br_metadata_site;
  assign fetch_br_metadata_fwd_o = br_metadata_site;
  always_ff @(posedge clk_i)
    if (fetch_instr_v_o) // note: needs to include whether we've finished a complete double-fetch
      br_metadata_site <=
        '{src_btb  : pred_if2_r.btb
          ,src_ret : pred_if2_r.ret
          ,ghist   : pred_if2_r.ghist
          ,bht_row : pred_if2_r.bht_row
          ,btb_tag : branch_prediction_source_addr_if2[2+btb_idx_width_p+:btb_tag_width_p]
          ,btb_idx : branch_prediction_source_addr_if2[2+:btb_idx_width_p]
          ,bht_idx : branch_prediction_source_addr_if2[2+:bht_idx_width_p]
          ,is_br   : is_br
          ,is_jal  : is_jal
          ,is_jalr : is_jalr
          ,is_call : is_call
          ,is_ret  : is_ret
          };

  // Scan fetched instruction
  bp_fe_instr_scan
   #(.bp_params_p(bp_params_p))
   instr_scan
    (.instr_i(fetch_instr_o)

     ,.scan_o(scan_instr)
     );

  bp_fe_realigner
    #(.bp_params_p(bp_params_p))
    realigner
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.fetch_pc_i     (pc_if2_r)
    ,.fetch_linear_i (fetch_linear_if2_r)
    ,.fetch_data_i   (fetch_i)
    ,.fetch_data_v_i (fetch_v_i)

    ,.fetch_instr_o  (fetch_instr_o)
    ,.fetch_instr_v_o(fetch_instr_v_o)
    );

  // Global history
  //
  wire ghistory_w_v_li = is_br | redirect_br_v_i;
  assign ghistory_n = redirect_br_v_i
    ? redirect_br_metadata_fwd.ghist
    : {ghistory_r[0+:ghist_width_p-1], pred_if2_r.taken};
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

endmodule


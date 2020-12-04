/*
 * bp_fe_pc_gen.v
 *
 * pc_gen provides the pc for the itlb and icache.
 * pc_gen also provides the BTB, BHT and RAS indexes for the backend (the queue
 * between the frontend and the backend, i.e. the frontend queue).
*/

module bp_fe_pc_gen
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_fe_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   )
  (input                                             clk_i
   , input                                           reset_i

   , input                                           redirect_v_i
   , input [vaddr_width_p-1:0]                       redirect_pc_i
   , input                                           redirect_br_v_i
   , input [branch_metadata_fwd_width_p-1:0]         redirect_br_metadata_fwd_i
   , input                                           redirect_br_taken_i
   , input                                           redirect_br_ntaken_i
   , input                                           redirect_br_nonbr_i

   , output logic [vaddr_width_p-1:0]                next_pc_o
   , input                                           next_pc_yumi_i

   , output logic                                    ovr_o

   , input [instr_width_p-1:0]                       fetch_i
   , input                                           fetch_instr_v_i
   , input                                           fetch_exception_v_i
   , output logic [branch_metadata_fwd_width_p-1:0]  fetch_br_metadata_fwd_o

   , input [vaddr_width_p-1:0]                       attaboy_pc_i
   , input [branch_metadata_fwd_width_p-1:0]         attaboy_br_metadata_fwd_i
   , input                                           attaboy_taken_i
   , input                                           attaboy_ntaken_i
   , input                                           attaboy_v_i
   , output logic                                    attaboy_yumi_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p);
  `declare_bp_fe_pc_gen_stage_s(vaddr_width_p, ghist_width_p);

  // branch prediction wires
  logic [vaddr_width_p-1:0]       br_target;
  logic                           ovr_ret, ovr_taken;
  // btb io
  logic [vaddr_width_p-1:0]       btb_br_tgt_lo;
  logic                           btb_br_tgt_v_lo;
  logic                           btb_br_tgt_jmp_lo;

  bp_fe_branch_metadata_fwd_s redirect_br_metadata_fwd;
  assign redirect_br_metadata_fwd = redirect_br_metadata_fwd_i;
  bp_fe_branch_metadata_fwd_s attaboy_br_metadata_fwd;
  assign attaboy_br_metadata_fwd = attaboy_br_metadata_fwd_i;
  bp_fe_pc_gen_stage_s [1:0] pc_gen_stage_n, pc_gen_stage_r;

  logic is_br, is_jal, is_jalr, is_call, is_ret;
  logic is_br_site, is_jal_site, is_jalr_site, is_call_site, is_ret_site;

  assign attaboy_yumi_o = attaboy_v_i & ~redirect_br_v_i;

  // Global history
  //
  logic [ghist_width_p-1:0] ghistory_n, ghistory_r;
  wire ghistory_w_v_li = is_br | redirect_br_v_i;
  assign ghistory_n = redirect_br_v_i
                      ? redirect_br_metadata_fwd.ghist
                      : {ghistory_r[0+:ghist_width_p-1], pc_gen_stage_r[1].taken};
  bsg_dff_reset_en
   #(.width_p(ghist_width_p))
   ghist_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(ghistory_w_v_li)

     ,.data_i(ghistory_n)
     ,.data_o(ghistory_r)
     );

  logic [1:0] bht_val_lo;
  logic [vaddr_width_p-1:0] return_addr_n, return_addr_r;
  wire btb_taken = btb_br_tgt_v_lo & (bht_val_lo[1] | btb_br_tgt_jmp_lo);
  always_comb
    begin
      pc_gen_stage_n[0]       = '0;
      pc_gen_stage_n[0].ghist = ghistory_n;

      // Next PC calculation
      // if we need to redirect
      if (redirect_v_i)
          pc_gen_stage_n[0].pc = redirect_pc_i;
      else if (ovr_ret)
          pc_gen_stage_n[0].pc = return_addr_r;
      else if (ovr_taken)
          pc_gen_stage_n[0].pc = br_target;
      else if (btb_taken)
          pc_gen_stage_n[0].pc = btb_br_tgt_lo;
      else
        begin
          pc_gen_stage_n[0].pc = pc_gen_stage_r[0].pc + 4;
        end

      if (redirect_br_v_i)
        begin
          pc_gen_stage_n[0].redir = 1'b1;
          pc_gen_stage_n[0].taken = redirect_br_taken_i;
        end
      else if (ovr_ret | ovr_taken)
        begin
          pc_gen_stage_n[0].taken = 1'b1;
          pc_gen_stage_n[0].ret = ovr_ret;
          pc_gen_stage_n[0].ovr = 1'b1;
        end
      else

      pc_gen_stage_n[1] = pc_gen_stage_r[0];
      if (~pc_gen_stage_r[0].redir)
        begin
          pc_gen_stage_n[1].taken = btb_taken;
          pc_gen_stage_n[1].btb   = btb_br_tgt_v_lo;
          pc_gen_stage_n[1].bht   = bht_val_lo;
        end
    end

  bsg_dff_reset
   #(.width_p($bits(bp_fe_pc_gen_stage_s)*2))
   pc_gen_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(pc_gen_stage_n)
     ,.data_o(pc_gen_stage_r)
     );

  bp_fe_branch_metadata_fwd_s br_metadata_site;
  assign fetch_br_metadata_fwd_o = br_metadata_site;
  always_ff @(posedge clk_i)
    if (fetch_instr_v_i)
      br_metadata_site <=
        '{src_btb  : pc_gen_stage_r[1].btb
          ,src_ret : pc_gen_stage_r[1].ret
          ,src_ovr : pc_gen_stage_r[1].ovr
          ,ghist   : pc_gen_stage_r[1].ghist
          ,bht_val : pc_gen_stage_r[1].bht
          ,is_br   : is_br
          ,is_jal  : is_jal
          ,is_jalr : is_jalr
          ,is_call : is_call
          ,is_ret  : is_ret
          ,btb_tag : pc_gen_stage_r[1].pc[2+btb_idx_width_p+:btb_tag_width_p]
          ,btb_idx : pc_gen_stage_r[1].pc[2+:btb_idx_width_p]
          ,bht_idx : pc_gen_stage_r[1].pc[2+:bht_idx_width_p]
          };

  // BTB
  wire btb_r_v_li = next_pc_yumi_i & ~ovr_taken & ~ovr_ret;
  wire btb_w_v_li = (redirect_br_v_i & redirect_br_taken_i)
                    | (redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd.src_btb)
                    | (attaboy_yumi_o & attaboy_taken_i & ~attaboy_br_metadata_fwd.src_btb);
  wire btb_clr_li = redirect_br_v_i & redirect_br_nonbr_i & redirect_br_metadata_fwd.src_btb;
  wire btb_jmp_li = redirect_br_v_i ? (redirect_br_metadata_fwd.is_jal | redirect_br_metadata_fwd.is_jalr) : (attaboy_br_metadata_fwd.is_jal | attaboy_br_metadata_fwd.is_jalr);
  wire [btb_tag_width_p-1:0] btb_tag_li = redirect_br_v_i ? redirect_br_metadata_fwd.btb_tag : attaboy_br_metadata_fwd.btb_tag;
  wire [btb_idx_width_p-1:0] btb_idx_li = redirect_br_v_i ? redirect_br_metadata_fwd.btb_idx : attaboy_br_metadata_fwd.btb_idx;
  wire [vaddr_width_p-1:0]   btb_tgt_li = redirect_br_v_i ? redirect_pc_i : attaboy_pc_i;
  bp_fe_btb
   #(.vaddr_width_p(vaddr_width_p)
     ,.btb_tag_width_p(btb_tag_width_p)
     ,.btb_idx_width_p(btb_idx_width_p)
     )
   btb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.r_addr_i(next_pc_o)
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
     );

  // BHT
  // Gselect predictor
  wire bht_r_v_li = next_pc_yumi_i & ~ovr_taken & ~ovr_ret;
  wire [bht_idx_width_p+ghist_width_p-1:0] bht_idx_r_li =
    {next_pc_o[2+:bht_idx_width_p], pc_gen_stage_n[0].ghist};
  wire bht_w_v_li =
    (redirect_br_v_i & redirect_br_metadata_fwd.is_br) | (attaboy_yumi_o & attaboy_br_metadata_fwd.is_br);
  wire [bht_idx_width_p+ghist_width_p-1:0] bht_idx_w_li = redirect_br_v_i
    ? {redirect_br_metadata_fwd.bht_idx, redirect_br_metadata_fwd.ghist}
    : {attaboy_br_metadata_fwd.bht_idx, attaboy_br_metadata_fwd.ghist};
  wire [1:0] bht_val_li = redirect_br_v_i ? redirect_br_metadata_fwd.bht_val : attaboy_br_metadata_fwd.bht_val;
  bp_fe_bht
   #(.vaddr_width_p(vaddr_width_p)
     ,.bht_idx_width_p(bht_idx_width_p+ghist_width_p)
     )
   bp_fe_bht
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.r_v_i(bht_r_v_li)
     ,.idx_r_i(bht_idx_r_li)
     ,.val_o(bht_val_lo)

     ,.w_v_i(bht_w_v_li)
     ,.idx_w_i(bht_idx_w_li)
     ,.correct_i(attaboy_yumi_o)
     ,.val_i(bht_val_li)
     );

  `declare_bp_fe_instr_scan_s(vaddr_width_p)
  bp_fe_instr_scan_s scan_instr;
  bp_fe_instr_scan
   #(.bp_params_p(bp_params_p))
   instr_scan
    (.instr_i(fetch_i)

     ,.scan_o(scan_instr)
     );

  assign is_br        = fetch_instr_v_i & scan_instr.branch;
  assign is_jal       = fetch_instr_v_i & scan_instr.jal;
  assign is_jalr      = fetch_instr_v_i & scan_instr.jalr;
  assign is_call      = fetch_instr_v_i & scan_instr.call;
  assign is_ret       = fetch_instr_v_i & scan_instr.ret;
  wire btb_miss_ras   = ~pc_gen_stage_r[0].btb | (pc_gen_stage_r[0].pc != return_addr_r);
  wire btb_miss_br    = ~pc_gen_stage_r[0].btb | (pc_gen_stage_r[0].pc != br_target);
  assign ovr_ret      = btb_miss_ras & is_ret;
  assign ovr_taken    = btb_miss_br & ((is_br & pc_gen_stage_r[0].bht[1]) | is_jal);
  assign br_target    = pc_gen_stage_r[1].pc + scan_instr.imm;

  assign return_addr_n = pc_gen_stage_r[1].pc + vaddr_width_p'(4);
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p))
   ras
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(is_call)

     ,.data_i(return_addr_n)
     ,.data_o(return_addr_r)
     );

  assign next_pc_o = pc_gen_stage_n[0].pc;

  assign ovr_o = ovr_taken | ovr_ret;

endmodule


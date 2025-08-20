
ERROR_CURRENTLY_UNSUPPORTED

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_be_nonsynth_branch_profiler
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

    , parameter branch_trace_file_p = "branch"
    )
   (input                         clk_i
    , input                       reset_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    , input [fe_cmd_width_lp-1:0] fe_cmd_o
    , input                       fe_cmd_yumi_i

    , input                       commit_v_i
    );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(ras_idx_width_p, btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_els_p);
  bp_fe_cmd_s fe_cmd;
  bp_fe_branch_metadata_fwd_s branch_metadata;
  assign fe_cmd = fe_cmd_o;

  wire pc_redirect_v    = fe_cmd_yumi_i
                          & (fe_cmd.opcode == e_op_pc_redirection)
                          & (fe_cmd.operands.pc_redirect_operands.subopcode == e_subop_branch_mispredict);
  wire attaboy_v        = fe_cmd_yumi_i & (fe_cmd.opcode == e_op_attaboy);

  assign branch_metadata = pc_redirect_v
                           ? fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd
                           : fe_cmd.operands.attaboy.branch_metadata_fwd;

  int branch_histo [longint];
  int miss_histo   [longint];

  int instr_cnt;
  int attaboy_cnt;
  int redirect_cnt;
  int br_cnt;
  int jal_cnt;
  int jalr_cnt;
  int call_cnt;
  int ret_cnt;
  int btb_hit_cnt;
  int ras_hit_cnt;
  int bht_hit_cnt;

  int file;
  string file_name;
  always_ff @(negedge reset_i)
    begin
      file_name = $sformatf("%s_%x.stats", branch_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
    end

  always_ff @(negedge clk_i)
    if (reset_i)
      begin
        instr_cnt    <= 0;
        attaboy_cnt  <= 0;
        redirect_cnt <= 0;
        br_cnt       <= 0;
        jal_cnt      <= 0;
        jalr_cnt     <= 0;
        call_cnt     <= 0;
        ret_cnt      <= 0;
        btb_hit_cnt  <= 0;
        ras_hit_cnt  <= 0;
        bht_hit_cnt  <= 0;
      end
    else
      begin
        instr_cnt <= instr_cnt + commit_v_i;
        attaboy_cnt <= attaboy_cnt + attaboy_v;
        redirect_cnt <= redirect_cnt + pc_redirect_v;
        if (attaboy_v)
          begin
            br_cnt      <= br_cnt + branch_metadata.site_br;
            jal_cnt     <= jal_cnt + branch_metadata.site_jal;
            jalr_cnt    <= jalr_cnt + branch_metadata.site_jalr;
            call_cnt    <= call_cnt + branch_metadata.site_call;
            ret_cnt     <= ret_cnt + branch_metadata.site_return;

            btb_hit_cnt <= btb_hit_cnt + branch_metadata.src_btb;
            bht_hit_cnt <= bht_hit_cnt + branch_metadata.site_br;
            ras_hit_cnt <= ras_hit_cnt + branch_metadata.src_ras;

            if (branch_histo.exists(fe_cmd.npc))
              begin
                branch_histo[fe_cmd.npc] <= branch_histo[fe_cmd.npc] + 1;
                miss_histo[fe_cmd.npc] <= miss_histo[fe_cmd.npc] + 0;
              end
            else
              begin
                branch_histo[fe_cmd.npc] <= 1;
                miss_histo[fe_cmd.npc] <= 0;
              end
          end
        else if (pc_redirect_v)
          begin
            br_cnt   <= br_cnt + branch_metadata.site_br;
            jal_cnt  <= jal_cnt + branch_metadata.site_jal;
            jalr_cnt <= jalr_cnt + branch_metadata.site_jalr;
            call_cnt <= call_cnt + branch_metadata.site_call;
            ret_cnt  <= ret_cnt + branch_metadata.site_return;

            if (branch_histo.exists(fe_cmd.npc))
              begin
                branch_histo[fe_cmd.npc] <= branch_histo[fe_cmd.npc] + 1;
                miss_histo[fe_cmd.npc]   <= miss_histo[fe_cmd.npc] + 1;
              end
            else
              begin
                branch_histo[fe_cmd.npc] <= 1;
                miss_histo[fe_cmd.npc]   <= 1;
              end
          end
      end

  final
    begin
      $fwrite(file, "Branch statistics\n");
      $fwrite(file, "MPKI: %d\n", redirect_cnt / (instr_cnt / 1000));
      $fwrite(file, "BTB hit%%: %d (%d/%d)\n", (btb_hit_cnt * 100) / (br_cnt+jal_cnt+jalr_cnt), btb_hit_cnt, br_cnt+jal_cnt+jalr_cnt);
      $fwrite(file, "BHT hit%%: %d (%d/%d)\n", (bht_hit_cnt * 100) / (br_cnt), bht_hit_cnt, br_cnt);
      $fwrite(file, "RAS hit%%: %d (%d/%d)\n", (ras_hit_cnt * 100) / (ret_cnt), ras_hit_cnt, ret_cnt);
      $fwrite(file, "==================================== Branches ======================================\n");
      $fwrite(file, "[target\t]\t\toccurances\t\tmisses\t\tmiss%%]\n");
      foreach (branch_histo[key])
        $fwrite(file, "[%x] %d %d %d\n", key, branch_histo[key], miss_histo[key], (miss_histo[key]*100)/branch_histo[key]);
    end

endmodule


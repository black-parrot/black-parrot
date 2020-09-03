
module bp_nonsynth_branch_profiler
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

    , parameter branch_trace_file_p = "branch"
    )
   (input                         clk_i
    , input                       reset_i
    , input                       freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    , input [fe_cmd_width_lp-1:0] fe_cmd_o
    , input                       fe_cmd_v_o
    , input                       fe_cmd_ready_i

    , input                       commit_v_i

    , input [num_core_p-1:0] program_finish_i
    );

  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p);
  bp_fe_cmd_s fe_cmd;
  bp_fe_branch_metadata_fwd_s branch_metadata;
  assign fe_cmd = fe_cmd_o;

  wire pc_redirect_v    = fe_cmd_v_o & (fe_cmd.opcode == e_op_pc_redirection);
  wire attaboy_v        = fe_cmd_v_o & (fe_cmd.opcode == e_op_attaboy);

  assign branch_metadata = pc_redirect_v 
                           ? fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd
                           : fe_cmd.operands.attaboy.branch_metadata_fwd;

  integer branch_histo [longint];
  integer miss_histo   [longint];

  integer instr_cnt;
  integer attaboy_cnt;
  integer redirect_cnt;
  integer br_cnt;
  integer jal_cnt;
  integer jalr_cnt;
  integer btb_hit_cnt;
  integer ras_hit_cnt;
  integer bht_hit_cnt;

  integer file;
  string file_name;
  wire reset_li = reset_i | freeze_i;
  always_ff @(negedge reset_li)
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
            br_cnt      <= br_cnt + branch_metadata.is_br;
            jal_cnt     <= jal_cnt + branch_metadata.is_jal;
            jalr_cnt    <= jalr_cnt + branch_metadata.is_jalr;

            btb_hit_cnt <= btb_hit_cnt + branch_metadata.src_btb;
            ras_hit_cnt <= ras_hit_cnt + branch_metadata.src_ret;
            bht_hit_cnt <= bht_hit_cnt + branch_metadata.is_br;

            if (branch_histo.exists(fe_cmd.vaddr))
              begin
                branch_histo[fe_cmd.vaddr] <= branch_histo[fe_cmd.vaddr] + 1;
                miss_histo[fe_cmd.vaddr] <= miss_histo[fe_cmd.vaddr] + 0;
              end
            else
              begin
                branch_histo[fe_cmd.vaddr] <= 1;
                miss_histo[fe_cmd.vaddr] <= 0;
              end
          end
        else if (pc_redirect_v)
          begin
            br_cnt   <= br_cnt + branch_metadata.is_br;
            jal_cnt  <= jal_cnt + branch_metadata.is_jal;
            jalr_cnt <= jalr_cnt + branch_metadata.is_jalr;

            if (branch_histo.exists(fe_cmd.vaddr))
              begin
                branch_histo[fe_cmd.vaddr] <= branch_histo[fe_cmd.vaddr] + 1;
                miss_histo[fe_cmd.vaddr]   <= miss_histo[fe_cmd.vaddr] + 1;
              end
            else
              begin
                branch_histo[fe_cmd.vaddr] <= 1;
                miss_histo[fe_cmd.vaddr]   <= 1;
              end
          end
      end

  logic [num_core_p-1:0] program_finish_r;
  bsg_dff_reset
   #(.width_p(num_core_p))
   program_finish_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(program_finish_i)
     ,.data_o(program_finish_r)
     );

  // TODO: This doesn't account for exceptions
  always_ff @(negedge clk_i)
   if (program_finish_i[mhartid_i] & ~program_finish_r[mhartid_i])
     begin
       $fwrite(file, "Branch statistics\n");
       $fwrite(file, "MPKI: %d\n", redirect_cnt / (instr_cnt / 1000));
       $fwrite(file, "BTB hit%%: %d\n", (btb_hit_cnt * 100) / (attaboy_cnt + redirect_cnt));
       $fwrite(file, "BHT hit%%: %d\n", (bht_hit_cnt * 100) / (br_cnt));
       $fwrite(file, "==================================== Branches ======================================\n");
       $fwrite(file, "[target\t]\t\toccurances\t\tmisses\t\tmiss%%]\n");
       foreach (branch_histo[key])
         $fwrite(file, "[%x] %d %d %d\n", key, branch_histo[key], miss_histo[key], (miss_histo[key]*100)/branch_histo[key]);
     end

endmodule


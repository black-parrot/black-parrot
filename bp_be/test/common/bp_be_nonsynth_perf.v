module bp_be_nonsynth_perf
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input   clk_i
   , input reset_i
   , input freeze_i

   , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

   , input [31:0] warmup_instr_i

   , input commit_v_i

   , input [num_core_p-1:0] program_finish_i
   );

logic [29:0] warmup_cnt;
logic warm;
bsg_counter_clear_up
 #(.max_val_p(2**30-1), .init_val_p(0))
 warmup_counter
  (.clk_i(clk_i)
   ,.reset_i(reset_i | freeze_i)

   ,.clear_i(1'b0)
   ,.up_i(commit_v_i & ~warm)
   ,.count_o(warmup_cnt)
   );
assign warm = (warmup_cnt == warmup_instr_i);

logic [63:0] clk_cnt_r;
logic [63:0] instr_cnt_r;

logic [num_core_p-1:0] program_finish_r;
always_ff @(posedge clk_i)
  begin
    if (reset_i | freeze_i | ~warm)
      begin
        clk_cnt_r <= '0;
        instr_cnt_r <= '0;

        program_finish_r <= '0;
      end
    else
      begin
        clk_cnt_r <= clk_cnt_r + 64'b1;
        instr_cnt_r <= instr_cnt_r + commit_v_i;

        program_finish_r <= program_finish_i;
      end
  end

always_ff @(negedge clk_i)
  begin
    if (program_finish_i[mhartid_i] & ~program_finish_r[mhartid_i])
      begin
        $display("[CORE%0x STATS]", mhartid_i);
        $display("\tclk   : %d", clk_cnt_r);
        $display("\tinstr : %d", instr_cnt_r);
        $display("\tmIPC  : %d", instr_cnt_r * 1000 / clk_cnt_r);
      end
  end

endmodule : bp_be_nonsynth_perf


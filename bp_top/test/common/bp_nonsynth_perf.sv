`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_perf
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam max_instr_lp = 2**30-1
   , localparam max_clock_lp = 2**30-1
   )
  (input   clk_i
   , input reset_i
   , input freeze_i

   , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

   , input [31:0] warmup_instr_i

   , input commit_v_i
   , input is_debug_mode_i
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
    if (reset_i | freeze_i | ~warm | is_debug_mode_i)
      begin
        clk_cnt_r <= '0;
        instr_cnt_r <= '0;
      end
    else
      begin
        clk_cnt_r <= clk_cnt_r + 64'b1;
        instr_cnt_r <= instr_cnt_r + commit_v_i;
      end
  end

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i | is_debug_mode_i)

     ,.clear_i(1'b0)
     ,.up_i(commit_v_i)
     ,.count_o(instr_cnt)
     );

  logic [`BSG_SAFE_CLOG2(max_clock_lp+1)-1:0] clk_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_clock_lp), .init_val_p(0))
   clk_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i | is_debug_mode_i)

     ,.clear_i(1'b0)
     ,.up_i(commit_v_i)
     ,.count_o(clk_cnt)
     );

  final
    begin
      $display("[CORE%0x STATS]", mhartid_i);
      $display("\tclk   : %d", clk_cnt_r);
      $display("\tinstr : %d", instr_cnt_r);
      $display("\tmIPC  : %d", instr_cnt_r * 1000 / clk_cnt_r);
    end

endmodule


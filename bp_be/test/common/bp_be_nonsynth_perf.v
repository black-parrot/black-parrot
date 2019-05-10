module bp_be_nonsynth_perf
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   )
  (input   clk_i
   , input reset_i

   , input fe_nop_i
   , input be_nop_i
   , input me_nop_i
   , input poison_i
   , input roll_i

   , input instr_cmt_i

   , input program_pass_i
   , input program_fail_i
   );

logic booted;
logic [63:0] clk_cnt_r;
logic [63:0] instr_cnt_r;
logic [63:0] fe_exc_cnt_r;
logic [63:0] fe_nop_cnt_r;
logic [63:0] be_nop_cnt_r;
logic [63:0] me_nop_cnt_r;
logic [63:0] poison_cnt_r;
logic [63:0] roll_cnt_r;

// We consider ourselves booted when we have a non-nop in the pipe
always_ff @(posedge clk_i)
  begin
    if (reset_i)
      booted <= '0;
    else
      booted <= booted | ~|(fe_nop_i | be_nop_i | me_nop_i);
  end

// Priorities for bubbles is:
//   me_nop > be_nop > fe_nop
// Priorities for squashes is:
//   roll > poison
// Overall:
//   roll > poison > me_nop > be_nop > fe_nop

wire blame_fe     = fe_nop_i & ~be_nop_i & ~me_nop_i & ~poison_i & ~roll_i;
wire blame_be     = be_nop_i & ~me_nop_i & ~poison_i & ~roll_i;
wire blame_me     = me_nop_i & ~poison_i & ~roll_i;
wire blame_poison = poison_i & ~roll_i;
wire blame_roll   = roll_i;

always_ff @(posedge clk_i)
  begin
    if (~booted) 
      begin
        clk_cnt_r <= '0;
        instr_cnt_r <= '0;
        fe_nop_cnt_r <= '0;
        be_nop_cnt_r <= '0;
        me_nop_cnt_r <= '0;
        poison_cnt_r <= '0;
        roll_cnt_r <= '0;
      end
    else 
      begin
        clk_cnt_r <= clk_cnt_r + 64'b1;
        instr_cnt_r <= instr_cnt_r + instr_cmt_i & ~poison_i;
        fe_nop_cnt_r <= fe_nop_cnt_r + blame_fe;
        be_nop_cnt_r <= be_nop_cnt_r + blame_be;
        me_nop_cnt_r <= me_nop_cnt_r + blame_me;
        poison_cnt_r <= poison_cnt_r + blame_poison;
        roll_cnt_r <= roll_cnt_r + blame_roll;
      end

    if (program_pass_i) 
      begin
        $display("PASS");
        $display("clk   : %d", clk_cnt_r);
        $display("instr : %d", instr_cnt_r);
        $display("fe_nop: %d", fe_nop_cnt_r);
        $display("be_nop: %d", be_nop_cnt_r);
        $display("me_nop: %d", me_nop_cnt_r);
        $display("poison: %d", poison_cnt_r);
        $display("roll  : %d", roll_cnt_r);
        $display("mIPC  : %d", instr_cnt_r * 1000 / clk_cnt_r);
        $fflush();
        $finish();
      end
    else if (program_fail_i)
      begin
        $display("FAIL");
        $fflush();
        $finish();
      end
  end

endmodule : bp_be_nonsynth_perf


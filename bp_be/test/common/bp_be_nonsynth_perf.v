module bp_be_nonsynth_perf
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   )
  (input   clk_i
   , input reset_i

   , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

   , input fe_nop_i
   , input be_nop_i
   , input me_nop_i
   , input poison_i
   , input roll_i

   , input instr_cmt_i

   , input [num_core_p-1:0] program_finish_i
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

logic [num_core_p-1:0] program_finish_r;
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

        program_finish_r <= '0;
      end
    else 
      begin
        clk_cnt_r <= clk_cnt_r + 64'b1;
        instr_cnt_r <= instr_cnt_r + instr_cmt_i & ~poison_i;
        fe_nop_cnt_r <= blame_fe ? fe_nop_cnt_r + 1'b1 : fe_nop_cnt_r; 
        be_nop_cnt_r <= blame_be ? be_nop_cnt_r + 1'b1 : be_nop_cnt_r;
        me_nop_cnt_r <= blame_me ? me_nop_cnt_r + 1'b1 : me_nop_cnt_r;
        poison_cnt_r <= blame_poison ? poison_cnt_r + 1'b1 : poison_cnt_r;
        roll_cnt_r <= blame_roll ? roll_cnt_r + 1'b1 : roll_cnt_r;

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
        $display("\tfe_nop: %d", fe_nop_cnt_r);
        $display("\tbe_nop: %d", be_nop_cnt_r);
        $display("\tme_nop: %d", me_nop_cnt_r);
        $display("\tpoison: %d", poison_cnt_r);
        $display("\troll  : %d", roll_cnt_r);
        $display("\tmIPC  : %d", instr_cnt_r * 1000 / clk_cnt_r);
      end
  end

endmodule : bp_be_nonsynth_perf


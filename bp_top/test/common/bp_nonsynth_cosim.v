
module bp_nonsynth_cosim
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam max_instr_lp = 2**30
    , localparam decode_width_lp = `bp_be_decode_width
    )
   (input                                     clk_i
    , input                                   reset_i
    , input                                   freeze_i
    , input                                   en_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i
    , input [63:0]                            config_file_i
    , input [31:0]                            cosim_instr_i

    , input [decode_width_lp-1:0]             decode_i

    , input                                   commit_v_i
    , input [vaddr_width_p-1:0]               commit_pc_i
    , input [instr_width_p-1:0]               commit_instr_i

    , input                                   rd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      rd_addr_i
    , input [dword_width_p-1:0]               rd_data_i

    , input                                   interrupt_v_i
    , input [dword_width_p-1:0]               cause_i
    );

import "DPI-C" context function void init_dromajo(string cfg_f_name);
import "DPI-C" context function bit  dromajo_step(int      hart_id,
                                                  longint pc,
                                                  int insn,
                                                  longint wdata);
import "DPI-C" context function void dromajo_trap(int hart_id, longint cause);

logic finish;

always_ff @(negedge reset_i)
  if (en_i)
    begin
      $display("Running with Dromajo cosimulation");
      init_dromajo(config_file_i);
    end

  bp_be_decode_s decode_r;
  bsg_dff_chain
   #(.width_p($bits(bp_be_decode_s))
     ,.num_stages_p(3)
     )
   reservation_pipe
    (.clk_i(clk_i)
     ,.data_i(decode_i)
     ,.data_o(decode_r)
     );

  logic                     commit_v_r;
  logic [vaddr_width_p-1:0] commit_pc_r;
  logic [instr_width_p-1:0] commit_instr_r;
  logic                     commit_rd_w_v_r;
  logic                     interrupt_v_r;
  logic [dword_width_p-1:0] cause_r;
  logic commit_fifo_v_lo, commit_fifo_yumi_li;
  wire commit_rd_w_v_li = decode_r.irf_w_v | decode_r.pipe_long_v;
  bsg_fifo_1r1w_small
   #(.width_p(1+vaddr_width_p+instr_width_p+2+dword_width_p), .els_p(8))
   commit_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({commit_v_i, commit_pc_i, commit_instr_i, commit_rd_w_v_li, interrupt_v_i, cause_i})
     ,.v_i(commit_v_i | interrupt_v_i)
     ,.ready_o()

     ,.data_o({commit_v_r, commit_pc_r, commit_instr_r, commit_rd_w_v_r, interrupt_v_r, cause_r})
     ,.v_o(commit_fifo_v_lo)
     ,.yumi_i(commit_fifo_yumi_li)
     );
  assign commit_fifo_yumi_li = commit_fifo_v_lo & (interrupt_v_r | ~commit_rd_w_v_r | (commit_rd_w_v_r & rd_w_v_i));

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.clear_i(1'b0)
     ,.up_i(commit_v_i)
     ,.count_o(instr_cnt)
     );

  always_ff @(negedge clk_i) begin
    if(en_i) begin
      if(commit_fifo_yumi_li & interrupt_v_r) begin
        dromajo_trap(mhartid_i, cause_r);
      end else if (commit_fifo_yumi_li & commit_v_r & commit_pc_r != '0) begin
        if (dromajo_step(mhartid_i, 64'($signed(commit_pc_r)), commit_instr_r, rd_data_i)) begin
          $display("COSIM_FAIL");
          $finish();
        end
      end else if ((cosim_instr_i != '0) && (instr_cnt >= cosim_instr_i)) begin
        $display("COSIM_PASS");
        $finish();
      end
    end
  end

endmodule


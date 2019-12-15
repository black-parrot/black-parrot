
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

    , input                                   int_rd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      int_rd_addr_i
    , input [dword_width_p-1:0]               int_rd_data_i

    , input                                   fp_rd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      fp_rd_addr_i
    , input [dword_width_p-1:0]               fp_rd_data_i

    , input                                   interrupt_v_i
    , input [dword_width_p-1:0]               cause_i

    , output logic [num_core_p-1:0]           finish_o
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
     // Commit stage is 3 cycles in
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
  logic                     commit_int_rd_w_v_r, commit_fp_rd_w_v_r;
  logic                     interrupt_v_r;
  logic [dword_width_p-1:0] cause_r;
  logic commit_fifo_v_lo, commit_fifo_yumi_li;
  wire commit_int_rd_w_v_li = decode_r.irf_w_v | decode_r.pipe_long_v;
  wire commit_fp_rd_w_v_li = decode_r.frf_w_v;
  bsg_fifo_1r1w_small
   #(.width_p(2+vaddr_width_p+instr_width_p+2+dword_width_p), .els_p(8))
   commit_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({commit_v_i, commit_pc_i, commit_instr_i, commit_int_rd_w_v_li, commit_fp_rd_w_v_li, interrupt_v_i, cause_i})
     ,.v_i(commit_v_i | interrupt_v_i)
     ,.ready_o()

     ,.data_o({commit_v_r, commit_pc_r, commit_instr_r, commit_int_rd_w_v_r, commit_fp_rd_w_v_r, interrupt_v_r, cause_r})
     ,.v_o(commit_fifo_v_lo)
     ,.yumi_i(commit_fifo_yumi_li)
     );

  logic [reg_addr_width_p-1:0] iwb_addr_r;
  logic [dword_width_p-1:0] iwb_data_r;
  logic iwb_fifo_v_lo, iwb_fifo_yumi_li;
  bsg_two_fifo
   #(.width_p(reg_addr_width_p+dword_width_p))
   iwb_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({int_rd_addr_i, int_rd_data_i})
     ,.v_i(int_rd_w_v_i)
     ,.ready_o()

     ,.data_o({iwb_addr_r, iwb_data_r})
     ,.v_o(iwb_fifo_v_lo)
     ,.yumi_i(iwb_fifo_yumi_li)
     );

  logic [reg_addr_width_p-1:0] fwb_addr_r;
  logic [dword_width_p-1:0] fwb_data_r;
  logic fwb_fifo_v_lo, fwb_fifo_yumi_li;
  bsg_two_fifo
   #(.width_p(reg_addr_width_p+dword_width_p))
   fwb_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({fp_rd_addr_i, fp_rd_data_i})
     ,.v_i(fp_rd_w_v_i)
     ,.ready_o()

     ,.data_o({fwb_addr_r, fwb_data_r})
     ,.v_o(fwb_fifo_v_lo)
     ,.yumi_i(fwb_fifo_yumi_li)
     );

  assign iwb_fifo_yumi_li = iwb_fifo_v_lo & commit_int_rd_w_v_r;
  assign fwb_fifo_yumi_li = fwb_fifo_v_lo & commit_fp_rd_w_v_r;
  assign commit_fifo_yumi_li = commit_fifo_v_lo & ((~commit_int_rd_w_v_r & ~commit_fp_rd_w_v_r)
                                                   | (commit_int_rd_w_v_r & iwb_fifo_v_lo)
                                                   | (commit_fp_rd_w_v_r & fwb_fifo_v_lo)
                                                   );
  

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

  logic finish_n, finish_r, finish_rr;
  assign finish_n = finish_r | (cosim_instr_i != 0 && instr_cnt == cosim_instr_i);
  bsg_dff_reset
   #(.width_p(2))
   finish_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({finish_r, finish_n})
     ,.data_o({finish_rr, finish_r})
     );
  assign finish_o = finish_r;

  always_ff @(negedge clk_i) begin
    if(en_i) begin
      if(commit_fifo_yumi_li & interrupt_v_r) begin
        dromajo_trap(mhartid_i, cause_r);
      end else if (commit_fifo_yumi_li & commit_v_r & commit_pc_r != '0) begin
        if (dromajo_step(mhartid_i, 64'($signed(commit_pc_r)), commit_instr_r, fwb_fifo_yumi_li ? fwb_data_r : iwb_data_r)) begin
          $display("COSIM_FAIL");
          $finish();
        end
      end

      if (finish_rr) begin
        $display("COSIM_PASS");
        $finish();
      end
    end
  end

endmodule


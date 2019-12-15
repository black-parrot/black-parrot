
module bp_nonsynth_commit_tracer
  import bp_be_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter commit_trace_file_p = "commit"
    , localparam decode_width_lp = `bp_be_decode_width
    )
   (input                                     clk_i
    , input                                   reset_i
    , input                                   freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

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
    );

integer file;
string file_name;

wire delay_li = reset_i | freeze_i;
always_ff @(negedge delay_li)
  begin
    file_name = $sformatf("%s_%x.trace", commit_trace_file_p, mhartid_i);
    file      = $fopen(file_name, "w");
  end

  logic [29:0] itag_cnt;
  bsg_counter_clear_up
   #(.max_val_p(2**30-1)
     ,.init_val_p(0)
     )
   itag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(commit_v_i)

     ,.count_o(itag_cnt)
     );

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
  logic commit_fifo_v_lo, commit_fifo_yumi_li;
  wire commit_rd_w_v_li = decode_r.irf_w_v | decode_r.frf_w_v | decode_r.pipe_long_v;
  bsg_fifo_1r1w_small
   #(.width_p(1+vaddr_width_p+instr_width_p+1), .els_p(8))
   commit_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({commit_v_i, commit_pc_i, commit_instr_i, commit_rd_w_v_li})
     ,.v_i(commit_v_i)
     ,.ready_o()

     ,.data_o({commit_v_r, commit_pc_r, commit_instr_r, commit_rd_w_v_r})
     ,.v_o(commit_fifo_v_lo)
     ,.yumi_i(commit_fifo_yumi_li)
     );
  assign commit_fifo_yumi_li = commit_fifo_v_lo & (~commit_rd_w_v_r | (commit_rd_w_v_r & (int_rd_w_v_i | fp_rd_w_v_i)));

  always_ff @(negedge clk_i)
    // TODO: For some reason, we're getting 0 PC/instr pairs. Either to do with nops or exceptions
    if (commit_fifo_yumi_li & commit_v_r & commit_pc_r != '0)
      begin
        $fwrite(file, "%x %x %x %x ", mhartid_i, commit_pc_r, commit_instr_r, itag_cnt);
        if (int_rd_w_v_i)
          $fwrite(file, "%x %x", int_rd_addr_i, int_rd_data_i);
        if (fp_rd_w_v_i)
          $fwrite(file, "%x %x", fp_rd_addr_i, fp_rd_data_i);
        $fwrite(file, "\n");
      end

endmodule


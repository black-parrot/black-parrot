
module bp_nonsynth_commit_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter trace_file_p = "prog"
    )
   (input                                     clk_i
    , input                                   reset_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    , input                                   commit_v_i
    , input [vaddr_width_p-1:0]               commit_pc_i
    , input [instr_width_p-1:0]               commit_instr_i
    , input                                   rd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      rd_addr_i
    , input [dword_width_p-1:0]               rd_data_i
    );

  string file_name;
  integer file;

  always_ff @(negedge reset_i) 
    begin
      file_name = $sformatf("%s.trace", trace_file_p);
      file = $fopen(file_name, "w");
    end

  logic [30:0] itag_cnt;
  bsg_counter_clear_up
   #(.max_val_p(2**31-1)
     ,.init_val_p(0)
     )
   itag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(commit_v_i)

     ,.count_o(itag_cnt)
     );

  logic                     commit_v_r;
  logic [vaddr_width_p-1:0] commit_pc_r;
  logic [instr_width_p-1:0] commit_instr_r;
  bsg_dff
   #(.width_p(1+vaddr_width_p+instr_width_p))
   commit__reg
    (.clk_i(clk_i)
     ,.data_i({commit_v_i, commit_pc_i, commit_instr_i})
     ,.data_o({commit_v_r, commit_pc_r, commit_instr_r})
     );

  always_ff @(negedge clk_i)
    // TODO: For some reason, we're getting 0 PC/instr pairs. Either to do with nops or exceptions
    if (commit_v_r & commit_pc_r != '0)
      begin
        $fwrite(file, "%x %x %x %x ", mhartid_i, commit_pc_r, commit_instr_r, itag_cnt);
        if (rd_w_v_i)
          $fwrite(file, "%x %x", rd_addr_i, rd_data_i);
        $fwrite(file, "\n");
      end

endmodule


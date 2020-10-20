
module bp_nonsynth_cosim
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  import bp_be_hardfloat_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter commit_trace_file_p = "commit"

    , localparam max_instr_lp = 2**30
    , localparam decode_width_lp = `bp_be_decode_width
    )
   (input                                     clk_i
    , input                                   reset_i
    , input                                   freeze_i
    , input                                   cosim_en_i
    , input                                   trace_en_i

    , input                                   checkpoint_i
    , input [31:0]                            num_core_i
    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i
    , input [63:0]                            config_file_i
    , input [31:0]                            instr_cap_i
    , input [31:0]                            memsize_i

    , input [decode_width_lp-1:0]             decode_i

    , input                                   commit_v_i
    , input [vaddr_width_p-1:0]               commit_pc_i
    , input [instr_width_p-1:0]               commit_instr_i

    , input                                   ird_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      ird_addr_i
    , input [dpath_width_p-1:0]               ird_data_i

    , input                                   frd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      frd_addr_i
    , input [dpath_width_p-1:0]               frd_data_i

    , input                                   trap_v_i
    , input [dword_width_p-1:0]               cause_i
    , input                                   is_debug_mode_i
    );

  import "DPI-C" context function void dromajo_init(string cfg_f_name, int hartid, int ncpus, int memory_size, bit checkpoint);
  import "DPI-C" context function bit  dromajo_step(int hartid,
                                                    longint pc,
                                                    int insn,
                                                    longint wdata);
  import "DPI-C" context function void dromajo_trap(int hartid, longint cause);
  
  import "DPI-C" context function void set_finish(int hartid);
  import "DPI-C" context function bit check_terminate();

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
  logic                     commit_ird_w_v_r;
  logic                     commit_frd_w_v_r;
  logic                     trap_v_r;
  logic [dword_width_p-1:0] cause_r;
  logic                     is_debug_mode_r;
  logic commit_fifo_v_lo, commit_fifo_yumi_li;
  wire commit_ird_w_v_li = commit_v_i & (decode_r.irf_w_v | decode_r.late_iwb_v);
  wire commit_frd_w_v_li = commit_v_i & (decode_r.frf_w_v | decode_r.late_fwb_v);
  bsg_fifo_1r1w_small
   #(.width_p(2+vaddr_width_p+instr_width_p+2+dword_width_p+1), .els_p(16))
   commit_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({commit_v_i, commit_pc_i, commit_instr_i, commit_ird_w_v_li, commit_frd_w_v_li, trap_v_i, cause_i, is_debug_mode_i})
     ,.v_i(commit_v_i | trap_v_i)
     ,.ready_o()

     ,.data_o({commit_v_r, commit_pc_r, commit_instr_r, commit_ird_w_v_r, commit_frd_w_v_r, trap_v_r, cause_r, is_debug_mode_r})
     ,.v_o(commit_fifo_v_lo)
     ,.yumi_i(commit_fifo_yumi_li)
     );

  logic [reg_addr_width_p-1:0] iwb_addr_r;
  logic [dword_width_p-1:0] iwb_data_r;
  logic ird_fifo_v_lo, ird_fifo_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p(reg_addr_width_p+dword_width_p), .els_p(8))
   ird_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({ird_addr_i, ird_data_i[0+:dword_width_p]})
     ,.v_i(ird_w_v_i)
     ,.ready_o()

     ,.data_o({iwb_addr_r, iwb_data_r})
     ,.v_o(ird_fifo_v_lo)
     ,.yumi_i(ird_fifo_yumi_li)
     );

  logic [reg_addr_width_p-1:0] frd_addr_r;
  bp_be_fp_reg_s frd_data_r;
  logic frd_fifo_v_lo, frd_fifo_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p(reg_addr_width_p+dpath_width_p), .els_p(8))
   frd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({frd_addr_i, frd_data_i})
     ,.v_i(frd_w_v_i)
     ,.ready_o()

     ,.data_o({frd_addr_r, frd_data_r})
     ,.v_o(frd_fifo_v_lo)
     ,.yumi_i(frd_fifo_yumi_li)
     );

  // The control bits control tininess, which is fixed in RISC-V
  wire [`floatControlWidth-1:0] control_li = `flControl_default;

  logic [dword_width_p-1:0] frd_raw_li;
  bp_be_rec_to_fp
   #(.bp_params_p(bp_params_p))
   debug_fp
    (.rec_i(frd_data_r.rec)

     ,.raw_sp_not_dp_i(frd_data_r.sp_not_dp)
     ,.raw_o(frd_raw_li)
     );

  assign ird_fifo_yumi_li = ird_fifo_v_lo & commit_ird_w_v_r;
  assign frd_fifo_yumi_li = frd_fifo_v_lo & commit_frd_w_v_r;
  assign commit_fifo_yumi_li = commit_fifo_v_lo & ((~commit_ird_w_v_r & ~commit_frd_w_v_r)
                                                   | (commit_ird_w_v_r & ird_fifo_v_lo)
                                                   | (commit_frd_w_v_r & frd_fifo_v_lo)
                                                   );

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i | is_debug_mode_r)

     ,.clear_i(1'b0)
     ,.up_i(commit_v_i)
     ,.count_o(instr_cnt)
     );

  logic finish_r, terminate;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   finish_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i((instr_cap_i != 0 && instr_cnt == instr_cap_i))
     ,.clear_i('0)
     ,.data_o(finish_r)
     );

  always_ff @(negedge reset_i)
    if (cosim_en_i)
      dromajo_init(config_file_i, mhartid_i, num_core_i, memsize_i, checkpoint_i);

  always_ff @(negedge clk_i)
    if (cosim_en_i & commit_fifo_yumi_li & trap_v_r)
      begin
        dromajo_trap(mhartid_i, cause_r);
      end
    else if (cosim_en_i & commit_fifo_yumi_li & commit_v_r & ~is_debug_mode_r & commit_pc_r != '0)
      if (dromajo_step(mhartid_i, 64'($signed(commit_pc_r)), commit_instr_r, frd_fifo_yumi_li ? frd_raw_li : iwb_data_r))
        begin
          $display("COSIM_FAIL");
          $finish();
        end
    else if (terminate)
        begin
          $display("COSIM_PASS");
          $finish();
        end
    else if (finish_r)
      begin
        set_finish(mhartid_i);
      end
    else
      begin
        terminate <= check_terminate();
      end

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

  always_ff @(negedge clk_i)
    if (trace_en_i & commit_fifo_yumi_li & commit_v_r & commit_pc_r != '0)
      begin
        $fwrite(file, "%x %x %x %x ", mhartid_i, commit_pc_r, commit_instr_r, itag_cnt);
        if (ird_w_v_i)
          $fwrite(file, "%x %x", ird_addr_i, ird_data_i);
        if (frd_w_v_i)
          $fwrite(file, "%x %x", frd_addr_i, frd_data_i);
        $fwrite(file, "\n");
      end

endmodule


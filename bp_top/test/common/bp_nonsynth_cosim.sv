
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_cosim
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter commit_trace_file_p = "commit"

    , localparam max_instr_lp = 2**30
    , localparam decode_width_lp = $bits(bp_be_decode_s)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
    )
   (input                                     clk_i
    , input                                   reset_i
    , input                                   freeze_i
    , input                                   cosim_en_i
    , input                                   trace_en_i
    , input                                   amo_en_i

    , input                                   checkpoint_i
    , input [31:0]                            num_core_i
    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i
    , input [63:0]                            config_file_i
    , input [31:0]                            instr_cap_i
    , input [31:0]                            memsize_i

    , input [decode_width_lp-1:0]             decode_i

    , input                                   is_debug_mode_i
    , input [commit_pkt_width_lp-1:0]         commit_pkt_i

    , input [1:0]                             priv_mode_i
    , input [dword_width_gp-1:0]              mstatus_i
    , input [dword_width_gp-1:0]              mcause_i
    , input [dword_width_gp-1:0]              scause_i

    , input                                   ird_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      ird_addr_i
    , input [dpath_width_gp-1:0]              ird_data_i

    , input                                   frd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      frd_addr_i
    , input [dpath_width_gp-1:0]              frd_data_i
    );

  import "DPI-C" context function void dromajo_init(string cfg_f_name, int hartid, int ncpus, int memory_size, bit checkpoint, bit amo_en);
  import "DPI-C" context function bit  dromajo_step(int hartid,
                                                    longint pc,
                                                    int insn,
                                                    longint wdata,
                                                    longint mstatus);
  import "DPI-C" context function void dromajo_trap(int hartid, longint cause);

  import "DPI-C" context function void set_finish(int hartid);
  import "DPI-C" context function bit check_terminate();

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_commit_pkt_s commit_pkt;
  assign commit_pkt = commit_pkt_i;

  bp_be_decode_s decode_r;
  bsg_dff_chain
   #(.width_p($bits(bp_be_decode_s))
     ,.num_stages_p(4)
     )
   reservation_pipe
    (.clk_i(clk_i)
     ,.data_i(decode_i)
     ,.data_o(decode_r)
     );

  bp_be_commit_pkt_s commit_pkt_r;
  logic is_debug_mode_r;
  bsg_dff_reset
   #(.width_p(1+$bits(commit_pkt)))
   commit_pkt_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({is_debug_mode_i, commit_pkt})
     ,.data_o({is_debug_mode_r, commit_pkt_r})
     );

  logic                     commit_debug_r;
  logic                     instret_v_r;
  logic                     trap_v_r;
  logic [vaddr_width_p-1:0] commit_pc_r;
  rv64_instr_fmatype_s      commit_instr, commit_instr_r;
  logic                     commit_ird_w_v_r;
  logic                     commit_frd_w_v_r;
  logic [dword_width_gp-1:0] cause_r, mstatus_r;
  logic commit_fifo_v_lo, commit_fifo_yumi_li;
  wire instret_v_li = commit_pkt_r.instret;
  wire [vaddr_width_p-1:0] commit_pc_li = commit_pkt_r.pc;
  wire [instr_width_gp-1:0] commit_instr_li = commit_pkt_r.instr;
  wire commit_ird_w_v_li = instret_v_li & (decode_r.irf_w_v | decode_r.late_iwb_v);
  wire commit_frd_w_v_li = instret_v_li & (decode_r.frf_w_v | decode_r.late_fwb_v);
  wire trap_v_li = commit_pkt_r.exception | commit_pkt_r._interrupt;
  wire [dword_width_gp-1:0] cause_li = (priv_mode_i == `PRIV_MODE_M) ? mcause_i : scause_i;
  wire [dword_width_gp-1:0] mstatus_li = mstatus_i;
  bsg_fifo_1r1w_small
   #(.width_p(3+vaddr_width_p+instr_width_gp+2+2*dword_width_gp), .els_p(128))
   commit_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({is_debug_mode_r, instret_v_li, trap_v_li, commit_pc_li, commit_instr_li, commit_ird_w_v_li, commit_frd_w_v_li, cause_li, mstatus_li})
     ,.v_i(instret_v_li | trap_v_li)
     ,.ready_o()

     ,.data_o({commit_debug_r, instret_v_r, trap_v_r, commit_pc_r, commit_instr_r, commit_ird_w_v_r, commit_frd_w_v_r, cause_r, mstatus_r})
     ,.v_o(commit_fifo_v_lo)
     ,.yumi_i(commit_fifo_yumi_li)
     );

  localparam rf_els_lp = 2**reg_addr_width_gp;
  logic [rf_els_lp-1:0][dword_width_gp-1:0] ird_data_r;
  bp_be_fp_reg_s [rf_els_lp-1:0] frd_data_r;
  logic [rf_els_lp-1:0] ird_fifo_v_lo, frd_fifo_v_lo;
  logic [rf_els_lp-1:0][dword_width_gp-1:0] frd_raw_li;

  for (genvar i = 0; i < rf_els_lp; i++)
    begin : iwb
      wire fill       = ird_w_v_i & (ird_addr_i == i);
      wire deallocate = commit_ird_w_v_r & (commit_instr_r.rd_addr == i) & commit_fifo_yumi_li;
      bsg_fifo_1r1w_small
        #(.width_p(dword_width_gp), .els_p(128))
        ird_fifo
         (.clk_i(clk_i)
          ,.reset_i(reset_i)

          ,.data_i(ird_data_i[0+:dword_width_gp])
          ,.v_i(fill)
          ,.ready_o()

          ,.data_o(ird_data_r[i])
          ,.v_o(ird_fifo_v_lo[i])
          ,.yumi_i(deallocate)
          );
    end

  for (genvar i = 0; i < rf_els_lp; i++)
    begin : fwb
      wire fill       = frd_w_v_i & (frd_addr_i == i);
      wire deallocate = commit_frd_w_v_r & (commit_instr_r.rd_addr == i) & commit_fifo_yumi_li;
      bsg_fifo_1r1w_small
        #(.width_p(dpath_width_gp), .els_p(128))
        ird_fifo
         (.clk_i(clk_i)
          ,.reset_i(reset_i)

          ,.data_i(frd_data_i)
          ,.v_i(fill)
          ,.ready_o()

          ,.data_o(frd_data_r[i])
          ,.v_o(frd_fifo_v_lo[i])
          ,.yumi_i(deallocate)
          );

      // The control bits control tininess, which is fixed in RISC-V
      wire [`floatControlWidth-1:0] control_li = `flControl_default;

      bp_be_rec_to_fp
       #(.bp_params_p(bp_params_p))
       debug_fp
        (.rec_i(frd_data_r[i].rec)

         ,.raw_sp_not_dp_i(frd_data_r[i].sp_not_dp)
         ,.raw_o(frd_raw_li[i])
         );
    end

  assign commit_fifo_yumi_li = commit_fifo_v_lo & ((~commit_ird_w_v_r & ~commit_frd_w_v_r)
                                                   | (commit_ird_w_v_r & ird_fifo_v_lo[commit_instr_r.rd_addr])
                                                   | (commit_frd_w_v_r & frd_fifo_v_lo[commit_instr_r.rd_addr])
                                                   );
  wire commit_ird_li = commit_fifo_v_lo & (commit_ird_w_v_r & ird_fifo_v_lo[commit_instr_r.rd_addr]);
  wire commit_frd_li = commit_fifo_v_lo & (commit_frd_w_v_r & frd_fifo_v_lo[commit_instr_r.rd_addr]);

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.clear_i(1'b0)
     ,.up_i(instret_v_r & commit_fifo_yumi_li & ~commit_debug_r)
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
      dromajo_init(config_file_i, mhartid_i, num_core_i, memsize_i, checkpoint_i, amo_en_i);

  always_ff @(negedge clk_i)
    if (cosim_en_i & commit_fifo_yumi_li & trap_v_r)
      begin
        dromajo_trap(mhartid_i, cause_r);
      end
    else if (~commit_debug_r & cosim_en_i & commit_fifo_yumi_li & instret_v_r & commit_pc_r != '0)
      if (dromajo_step(mhartid_i, 64'($signed(commit_pc_r)), commit_instr_r, commit_frd_li ? frd_raw_li[commit_instr_r.rd_addr] : ird_data_r[commit_instr_r.rd_addr], mstatus_r))
        begin
          $display("COSIM_FAIL");
          $finish();
        end
    else if (terminate)
        begin
          $display("COSIM_PASS");
          $finish();
        end

  always_ff @(negedge clk_i)
    if (finish_r)
      begin
        set_finish(mhartid_i);
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

  always_ff @(negedge clk_i)
    if (trace_en_i & commit_fifo_yumi_li & instret_v_r & commit_pc_r != '0)
      begin
        $fwrite(file, "%x %x %x %x ", mhartid_i, commit_pc_r, commit_instr_r, instr_cnt);
        if (commit_fifo_yumi_li & commit_ird_w_v_r)
          $fwrite(file, "%x %x", commit_instr_r.rd_addr, ird_data_r[commit_instr_r.rd_addr]);
        if (commit_fifo_yumi_li & commit_frd_w_v_r)
          $fwrite(file, "%x %x", commit_instr_r.rd_addr, frd_raw_li[commit_instr_r.rd_addr]);
        $fwrite(file, "\n");
      end

endmodule


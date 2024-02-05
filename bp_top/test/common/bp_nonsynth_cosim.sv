
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

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
    , input                                   finish_i

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

    , input                                   cache_req_yumi_i
    , input                                   cache_req_nonblocking_i
    , input                                   cache_req_complete_i

    , input                                   cosim_clk_i
    , input                                   cosim_reset_i
    );

  import "DPI-C" context function void cosim_init(int hartid, int ncpus, int memory_size, bit checkpoint);
  import "DPI-C" context function int cosim_step(int hartid,
                                                   longint pc,
                                                   int insn,
                                                   longint wdata,
                                                   longint mstatus);
  import "DPI-C" context function void cosim_trap(int hartid, longint cause);
  import "DPI-C" context function void cosim_finish();

`ifndef XCELIUM

  wire posedge_clk =  clk_i;
  wire negedge_clk = ~clk_i;

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_commit_pkt_s commit_pkt;
  assign commit_pkt = commit_pkt_i;

  bp_be_decode_s decode_r;
  bsg_dff_chain
   #(.width_p($bits(bp_be_decode_s)), .num_stages_p(4))
   reservation_pipe
    (.clk_i(posedge_clk)
     ,.data_i(decode_i)
     ,.data_o(decode_r)
     );

  bp_be_commit_pkt_s commit_pkt_r;
  logic is_debug_mode_r;
  bsg_dff_chain
   #(.width_p(1+$bits(commit_pkt)), .num_stages_p(1))
   commit_pkt_reg
    (.clk_i(posedge_clk)

     ,.data_i({is_debug_mode_i, commit_pkt})
     ,.data_o({is_debug_mode_r, commit_pkt_r})
     );

  logic cache_req_complete_r, cache_req_v_r;
  // We filter out for ready so that the request only tracks once
  wire cache_req_v_li = cache_req_yumi_i & ~cache_req_nonblocking_i;
  bsg_dff_chain
   #(.width_p(2), .num_stages_p(2))
   cache_req_reg
    (.clk_i(negedge_clk)

     ,.data_i({cache_req_complete_i, cache_req_v_li})
     ,.data_o({cache_req_complete_r, cache_req_v_r})
     );

  logic                     commit_fifo_full_lo;
  logic                     commit_debug_r;
  logic                     instret_v_r;
  logic                     trap_v_r;
  logic [vaddr_width_p-1:0] commit_pc_r;
  rv64_instr_fmatype_s      commit_instr, commit_instr_r;
  logic                     commit_ird_w_v_r;
  logic                     commit_frd_w_v_r;
  logic                     commit_req_v_r;
  logic [dword_width_gp-1:0] cause_r, mstatus_r;
  logic commit_fifo_v_lo, commit_fifo_yumi_li;
  wire instret_v_li = commit_pkt_r.instret;
  wire [vaddr_width_p-1:0] commit_pc_li = commit_pkt_r.pc;
  wire [instr_width_gp-1:0] commit_instr_li = commit_pkt_r.instr;
  wire commit_ird_w_v_li = instret_v_li & decode_r.irf_w_v;
  wire commit_frd_w_v_li = instret_v_li & decode_r.frf_w_v;
  wire commit_req_v_li   = instret_v_li & cache_req_v_r;
  wire trap_v_li = commit_pkt_r.exception | commit_pkt_r._interrupt;
  wire [dword_width_gp-1:0] cause_li = (priv_mode_i == `PRIV_MODE_M) ? mcause_i : scause_i;
  wire [dword_width_gp-1:0] mstatus_li = mstatus_i;
  wire commit_fifo_v_li = instret_v_li | trap_v_li;
  bsg_async_fifo
   #(.width_p(4+vaddr_width_p+instr_width_gp+3+2*dword_width_gp), .lg_size_p(10))
   commit_fifo
    (.w_clk_i(posedge_clk)
     ,.w_reset_i(reset_i)
     ,.w_enq_i(commit_fifo_v_li & ~commit_fifo_full_lo)
     ,.w_data_i({freeze_i, is_debug_mode_r, instret_v_li, trap_v_li, commit_pc_li, commit_instr_li, commit_ird_w_v_li, commit_frd_w_v_li, commit_req_v_li, cause_li, mstatus_li})
     ,.w_full_o(commit_fifo_full_lo)

     ,.r_clk_i(cosim_clk_i)
     ,.r_reset_i(cosim_reset_i)
     ,.r_deq_i(commit_fifo_v_lo & commit_fifo_yumi_li)
     ,.r_data_o({commit_freeze_r, commit_debug_r, instret_v_r, trap_v_r, commit_pc_r, commit_instr_r, commit_ird_w_v_r, commit_frd_w_v_r, commit_req_v_r, cause_r, mstatus_r})
     ,.r_valid_o(commit_fifo_v_lo)
     );

  localparam rf_els_lp = 2**reg_addr_width_gp;
  bp_be_fp_reg_s [rf_els_lp-1:0] frd_data_r;
  bp_be_int_reg_s [rf_els_lp-1:0] ird_data_r;
  logic [rf_els_lp-1:0] ird_fifo_v_lo, frd_fifo_v_lo;
  logic [rf_els_lp-1:0][dword_width_gp-1:0] ird_raw_li;
  logic [rf_els_lp-1:0][dp_rec_width_gp-1:0] frd_raw_li;

  for (genvar i = 0; i < rf_els_lp; i++)
    begin : iwb
      wire fill       = ird_w_v_i & (ird_addr_i == i);
      wire deallocate = commit_ird_w_v_r & (commit_instr_r.rd_addr == i) & commit_fifo_yumi_li;
      bsg_async_fifo
       #(.width_p(dpath_width_gp), .lg_size_p(10))
       ird_fifo
        (.w_clk_i(posedge_clk)
         ,.w_reset_i(reset_i)
         ,.w_enq_i(fill)
         ,.w_data_i(ird_data_i)
         ,.w_full_o()

         ,.r_clk_i(cosim_clk_i)
         ,.r_reset_i(cosim_reset_i)
         ,.r_deq_i(deallocate)
         ,.r_data_o(ird_data_r[i])
         ,.r_valid_o(ird_fifo_v_lo[i])
         );

      logic [dpath_width_gp-1:0] ird_data_lo;
      bp_be_int_unbox
       #(.bp_params_p(bp_params_p))
       int_unbox
        (.reg_i(ird_data_r[i])
         ,.tag_i(ird_data_r[i].tag)
         ,.unsigned_i(1'b0)
         ,.val_o(ird_raw_li[i])
         );
    end

  for (genvar i = 0; i < rf_els_lp; i++)
    begin : fwb
      wire fill       = frd_w_v_i & (frd_addr_i == i);
      wire deallocate = commit_frd_w_v_r & (commit_instr_r.rd_addr == i) & commit_fifo_yumi_li;
      bsg_async_fifo
       #(.width_p(dpath_width_gp), .lg_size_p(10))
       frd_fifo
        (.w_clk_i(posedge_clk)
         ,.w_reset_i(reset_i)
         ,.w_enq_i(fill)
         ,.w_data_i(frd_data_i)
         ,.w_full_o()

         ,.r_clk_i(cosim_clk_i)
         ,.r_reset_i(cosim_reset_i)
         ,.r_deq_i(deallocate)
         ,.r_data_o(frd_data_r[i])
         ,.r_valid_o(frd_fifo_v_lo[i])
         );

      bp_be_fp_unbox
       #(.bp_params_p(bp_params_p))
       fp_unbox
        (.reg_i(frd_data_r[i])
         ,.tag_i(frd_data_r[i].tag)
         ,.raw_i(1'b1)
         ,.val_o(frd_raw_li[i])
         );
    end

  wire commit_ird_v_lo = ird_fifo_v_lo[commit_instr_r.rd_addr];
  wire commit_frd_v_lo = frd_fifo_v_lo[commit_instr_r.rd_addr];

  // We don't need to cross domains explicitly here, because using the slower clock is conservative
  logic [`BSG_WIDTH(128)-1:0] req_cnt_lo;
  bsg_counter_up_down
   #(.max_val_p(128), .init_val_p(0), .max_step_p(1))
   req_counter
    (.clk_i(negedge_clk)
     ,.reset_i(reset_i | freeze_i)

     ,.up_i(cache_req_v_r)
     ,.down_i(cache_req_complete_r)

     ,.count_o(req_cnt_lo)
     );
  wire req_v_lo = ~cache_req_v_r & (req_cnt_lo == '0);

  assign commit_fifo_yumi_li = commit_fifo_v_lo & ((~commit_ird_w_v_r | commit_ird_v_lo)
                                                   & (~commit_frd_w_v_r | commit_frd_v_lo)
                                                   & (~commit_req_v_r | req_v_lo)
                                                   );
  wire commit_iwb_li = commit_fifo_v_lo & (commit_ird_w_v_r & ird_fifo_v_lo[commit_instr_r.rd_addr]);
  wire commit_fwb_li = commit_fifo_v_lo & (commit_frd_w_v_r & frd_fifo_v_lo[commit_instr_r.rd_addr]);

  logic [`BSG_SAFE_CLOG2(max_instr_lp+1)-1:0] instr_cnt;
  bsg_counter_clear_up
   #(.max_val_p(max_instr_lp), .init_val_p(0))
   instr_counter
    (.clk_i(cosim_clk_i)
     ,.reset_i(cosim_reset_i | freeze_i)

     ,.clear_i(1'b0)
     ,.up_i(instret_v_r & commit_fifo_yumi_li & ~commit_debug_r)
     ,.count_o(instr_cnt)
     );

  logic finish_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   finish_reg
    (.clk_i(cosim_clk_i)
     ,.reset_i(cosim_reset_i)

     ,.set_i((instr_cap_i != 0 && instr_cnt == instr_cap_i) | finish_i)
     ,.clear_i('0)
     ,.data_o(finish_r)
     );

  always_ff @(negedge reset_i)
    if (cosim_en_i)
      cosim_init(mhartid_i, num_core_i, memsize_i, checkpoint_i);

  wire [dword_width_gp-1:0] cosim_pc_li     = `BSG_SIGN_EXTEND(commit_pc_r, dword_width_gp);
  wire [instr_width_gp-1:0] cosim_instr_li  = commit_instr_r;
  wire [dword_width_gp-1:0] cosim_cause_li  = cause_r;
  wire [dpath_width_gp-1:0] cosim_ireg_li   = ird_data_r[commit_instr_r.rd_addr];
  wire [dword_width_gp-1:0] cosim_ird_li    = ird_raw_li[commit_instr_r.rd_addr];
  wire [dpath_width_gp-1:0] cosim_freg_li   = frd_data_r[commit_instr_r.rd_addr];
  wire [dword_width_gp-1:0] cosim_frd_li    = frd_raw_li[commit_instr_r.rd_addr];
  wire [dword_width_gp-1:0] cosim_rd_li     = commit_fwb_li ? cosim_frd_li : cosim_ird_li;
  wire [dword_width_gp-1:0] cosim_status_li = mstatus_r;
  integer ret_code;
  always_ff @(posedge cosim_clk_i)
    if (cosim_reset_i)
      ret_code <= 0;
    else if (~commit_debug_r & ~commit_freeze_r & cosim_en_i & commit_fifo_yumi_li & !finish_r & trap_v_r)
      cosim_trap(mhartid_i, cosim_cause_li);
    else if (~commit_debug_r & ~commit_freeze_r & cosim_en_i & commit_fifo_yumi_li & instret_v_r & commit_pc_r != '0)
      ret_code <= cosim_step(mhartid_i, cosim_pc_li, cosim_instr_li, cosim_rd_li, cosim_status_li);

   // ret_code: {exit_code, terminate}
   logic terminate;
   always_ff @(negedge cosim_clk_i)
     if (ret_code >> 1)
       begin
         // Successful termination
         $display("COSIM_FAIL: exit code: %d", (ret_code >> 1));
         $finish();
       end
     else if (ret_code)
       begin
          $display("COSIM_PASS: %d", ret_code);
          $finish();
       end
     else if (finish_r)
       begin
         cosim_finish();
       end

  integer file;
  string file_name;
  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
    begin
      file_name = $sformatf("%s_%x.trace", commit_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
    end

  always_ff @(posedge cosim_clk_i)
    if (trace_en_i & commit_fifo_yumi_li & commit_pc_r != '0)
      begin
        $fwrite(file, "%x %x %x %x ", mhartid_i, cosim_pc_li, cosim_instr_li, instr_cnt);
        if (instret_v_r & commit_ird_w_v_r)
          $fwrite(file, "%x %x", commit_instr_r.rd_addr, cosim_ird_li);
        if (instret_v_r & commit_frd_w_v_r)
          $fwrite(file, "%x %x", commit_instr_r.rd_addr, cosim_frd_li);
        if (trap_v_r)
          $fwrite(file, "   %x %x <- trap", cause_r, mstatus_r);
        $fwrite(file, "\n");
      end

  always_ff @(posedge cosim_clk_i)
    if (commit_fifo_v_li & commit_fifo_full_lo)
      begin
        $display("COSIM_FAIL: commit fifo overrun, core %x", mhartid_i);
        $finish();
      end

`endif

endmodule


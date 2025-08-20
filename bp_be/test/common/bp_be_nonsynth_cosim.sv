
`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_nonsynth_cosim
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter string trace_str_p = ""
    )
   (input                                  clk_i
    , input                                reset_i
    , input                                en_i

    , input [31:0]                         trace_en_pi
    , input [31:0]                         check_en_pi

    , input                                cosim_clk_i
    , input                                cosim_reset_i
    );

  import "DPI-C" context function chandle cosim_init(input int ncpus, input int memsize);
  import "DPI-C" context function chandle cosim_finish(input chandle cosim_handle);
  import "DPI-C" context function int cosim_step(input chandle cosim_handle,
                                                   input int hartid,
                                                   input longint pc,
                                                   input int insn,
                                                   input longint wdata,
                                                   input longint status
                                                   );
  import "DPI-C" context function int cosim_trap(input chandle cosim_handle,
                                                   input int hartid,
                                                   input longint cause
                                                   );

  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);

  wire trace_en_li = en_i & trace_en_pi;
  wire check_en_li = en_i & check_en_pi;

  localparam lg_queue_size_lp = 10;

  // snoop
  wire [core_id_width_p-1:0] mhartid = calculator.pipe_sys.csr.mhartid_lo;
  wire bp_be_commit_pkt_s commit_pkt = calculator.commit_pkt_o;
  wire bp_be_trans_info_s trans_info = calculator.trans_info_o;
  wire bp_be_decode_info_s decode_info = calculator.decode_info_o;
  wire bp_be_wb_pkt_s comp_pkt = calculator.comp_stage_r[2];
  wire bp_be_wb_pkt_s iwb_pkt = calculator.iwb_pkt_o;
  wire bp_be_wb_pkt_s fwb_pkt = calculator.fwb_pkt_o;
  wire [dword_width_gp-1:0] priv = calculator.pipe_sys.csr.priv_mode_r;
  wire [dword_width_gp-1:0] mstatus = calculator.pipe_sys.csr.mstatus_li;
  wire [dword_width_gp-1:0] mcause = calculator.pipe_sys.csr.mcause_li;
  wire [dword_width_gp-1:0] scause = calculator.pipe_sys.csr.scause_li;
  wire [dword_width_gp-1:0] cause = (priv == `PRIV_MODE_M) ? mcause : scause;
  wire [dword_width_gp-1:0] status = mstatus;

  // process
  logic commit_full_lo, commit_v_lo, commit_enq, commit_deq;
  bp_be_wb_pkt_s comp_pkt_lo;
  bp_be_commit_pkt_s commit_pkt_lo;
  bp_be_trans_info_s trans_info_lo;
  bp_be_decode_info_s decode_info_lo;
  logic [dword_width_gp-1:0] cause_lo, status_lo; // This is unnecessary overhead, but it's simulation
  bsg_async_fifo
   #(.width_p(2*dword_width_gp+$bits(bp_be_decode_info_s)+$bits(bp_be_trans_info_s)+$bits(bp_be_wb_pkt_s)+$bits(bp_be_commit_pkt_s)), .lg_size_p(lg_queue_size_lp))
   commit_fifo
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_enq_i(commit_enq)
     ,.w_data_i({cause, status, decode_info, trans_info, comp_pkt, commit_pkt})
     ,.w_full_o(commit_full_lo)

     ,.r_clk_i(cosim_clk_i)
     ,.r_reset_i(cosim_reset_i)
     ,.r_deq_i(commit_deq)
      ,.r_data_o({cause_lo, status_lo, decode_info_lo, trans_info_lo, comp_pkt_lo, commit_pkt_lo})
     ,.r_valid_o(commit_v_lo)
     );
  assign commit_enq = check_en_li & ~decode_info.debug_mode & (commit_pkt.instret | commit_pkt.exception | commit_pkt._interrupt);

  wire commit_ird_pending = commit_v_lo & commit_pkt_lo.instret & (comp_pkt_lo.ird_w_v | commit_pkt_lo.iscore_v);
  wire commit_frd_pending = commit_v_lo & commit_pkt_lo.instret & (comp_pkt_lo.frd_w_v | commit_pkt_lo.fscore_v);
  wire trap_v_lo = commit_deq & (commit_pkt_lo.exception | commit_pkt_lo._interrupt);
  wire instret_v_lo = commit_deq & (commit_pkt_lo.instret);

  bp_be_wb_pkt_s [rv64_rf_els_gp-1:0] iwb_pkt_lo;
  logic [rv64_rf_els_gp-1:0] iwb_full_lo, iwb_v_lo, iwb_enq, iwb_deq;
  bp_be_wb_pkt_s [rv64_rf_els_gp-1:0] fwb_pkt_lo;
  logic [rv64_rf_els_gp-1:0] fwb_full_lo, fwb_v_lo, fwb_enq, fwb_deq;
  for (genvar i = 0; i < rv64_rf_els_gp; i++)
    begin : wb
      assign iwb_enq[i] = check_en_li & iwb_pkt.ird_w_v & (iwb_pkt.rd_addr == i);
      assign iwb_deq[i] = commit_deq & commit_ird_pending & (comp_pkt_lo.rd_addr == i);
      bsg_async_fifo
       #(.width_p($bits(bp_be_wb_pkt_s)), .lg_size_p(lg_queue_size_lp))
       ird_fifo
        (.w_clk_i(clk_i)
         ,.w_reset_i(reset_i)
         ,.w_enq_i(iwb_enq[i])
         ,.w_data_i(iwb_pkt)
         ,.w_full_o(iwb_full_lo[i])

         ,.r_clk_i(cosim_clk_i)
         ,.r_reset_i(cosim_reset_i)
         ,.r_deq_i(iwb_deq[i])
         ,.r_data_o(iwb_pkt_lo[i])
         ,.r_valid_o(iwb_v_lo[i])
         );

      assign fwb_enq[i] = check_en_li & fwb_pkt.frd_w_v & (fwb_pkt.rd_addr == i);
      assign fwb_deq[i] = commit_deq & commit_frd_pending & (comp_pkt_lo.rd_addr == i);
      bsg_async_fifo
       #(.width_p($bits(bp_be_wb_pkt_s)), .lg_size_p(lg_queue_size_lp))
       frd_fifo
        (.w_clk_i(clk_i)
         ,.w_reset_i(reset_i)
         ,.w_enq_i(fwb_enq[i])
         ,.w_data_i(fwb_pkt)
         ,.w_full_o(fwb_full_lo[i])

         ,.r_clk_i(cosim_clk_i)
         ,.r_reset_i(cosim_reset_i)
         ,.r_deq_i(fwb_deq[i])
         ,.r_data_o(fwb_pkt_lo[i])
         ,.r_valid_o(fwb_v_lo[i])
         );
    end

  wire ird_v_lo = iwb_v_lo[comp_pkt_lo.rd_addr];
  wire frd_v_lo = fwb_v_lo[comp_pkt_lo.rd_addr];

  wire bp_be_int_reg_s ird_reg_lo = iwb_pkt_lo[comp_pkt_lo.rd_addr].rd_data;
  logic [int_rec_width_gp-1:0] ird_raw_lo;
  bp_be_int_unbox
   #(.bp_params_p(bp_params_p))
   int_unbox
    (.reg_i(ird_reg_lo)
     ,.tag_i(e_int_dword)
     ,.unsigned_i(1'b0)
     ,.val_o(ird_raw_lo)
     );

  wire bp_be_fp_reg_s frd_reg_lo = fwb_pkt_lo[comp_pkt_lo.rd_addr].rd_data;
  logic [dp_rec_width_gp-1:0] frd_raw_lo;
  bp_be_fp_unbox
   #(.bp_params_p(bp_params_p))
   fp_unbox
    (.reg_i(frd_reg_lo)
     ,.tag_i(e_fp_dp)
     ,.raw_i(1'b1)
     ,.val_o(frd_raw_lo)
     );

  assign commit_deq = commit_v_lo & ((~commit_ird_pending | ird_v_lo)
                                     & (~commit_frd_pending | frd_v_lo)
                                     );

  wire [dword_width_gp-1:0] step_pc = $signed(commit_pkt_lo.pc);
  wire [instr_width_gp-1:0] step_insn = commit_pkt_lo.instr;
  wire [reg_addr_width_gp-1:0] step_rd_addr = comp_pkt_lo.rd_addr;
  wire [dword_width_gp-1:0] step_wdata = commit_ird_pending ? ird_raw_lo : frd_raw_lo;
  wire [1:0] step_priv_mode = trans_info_lo.priv_mode;
  wire [vaddr_width_p-1:0] step_npc = commit_pkt_lo.npc;
  wire step_debug = commit_v_lo & decode_info_lo.debug_mode;
  wire [dword_width_gp-1:0] step_status = status_lo;
  wire [dword_width_gp-1:0] step_cause = cause_lo;

  chandle cosim_handle;
  initial cosim_handle = cosim_init(num_core_p, 256);
  final cosim_handle = cosim_finish(cosim_handle);

  int ret_code;
  always_ff @(posedge cosim_clk_i)
    if (instret_v_lo)
      ret_code <= cosim_step(cosim_handle, mhartid, step_pc, step_insn, step_wdata, step_status);
    else if (trap_v_lo)
      ret_code <= cosim_trap(cosim_handle, mhartid, step_cause);

   // ret_code: {exit_code, terminate}
   always_ff @(posedge cosim_clk_i)
     if (ret_code[0] && (ret_code>>1))
       begin
         $display("[BSG-FAIL] co-simulation failure: exit code: %d", (ret_code>>1));
         $finish;
       end
     else if (ret_code[0] && !(ret_code>>1))
       begin
         $display("[BSG-FINISH] co-simulation finish: exit code: %d", (ret_code>>1));
       end

  // record
  `declare_bp_tracer_control(cosim_clk_i, cosim_reset_i, trace_en_li, trace_str_p, mhartid);
  always_ff @(posedge cosim_clk_i)
    if (is_go)
      begin
        if (instret_v_lo | trap_v_lo)
          begin
            $fwrite(file, "%x %x %x (0x%x) ", mhartid, step_priv_mode, step_pc, step_insn);
            if (instret_v_lo & commit_ird_pending)
              $fwrite(file, "x%x %x", step_rd_addr, step_wdata);
            if (instret_v_lo & commit_frd_pending)
              $fwrite(file, "f%x %x", step_rd_addr, step_wdata);
            if (trap_v_lo)
              $fwrite(file, "exception (%x) -> 0x%x", step_cause, step_npc);
            $fwrite(file, "\n");
        end
      end

endmodule


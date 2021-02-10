/**
 *
 * Name:
 *   bp_be_calculator_top.v
 *
 * Description:
 *
 * Notes:
 *   Should subdivide this module into a few helper modules to reduce complexity. Perhaps
 *     issuer, exe_pipe, completion_pipe, status_gen?
 *   Exception aggregation could be simplified with constants and more thought. Should fix
 *     once code is more stable, fixing in cleanup could cause regressions
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_calculator_top
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache)

   // Generated parameters
   , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dispatch_pkt_width_lp   = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam branch_pkt_width_lp     = `bp_be_branch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp     = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam wb_pkt_width_lp         = `bp_be_wb_pkt_width(vaddr_width_p)
   , localparam ptw_miss_pkt_width_lp   = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp   = `bp_be_ptw_fill_pkt_width(vaddr_width_p)

   // From BP BE specifications
   , localparam pipe_stage_els_lp = 6
   )
 (input                                             clk_i
  , input                                           reset_i

  , input [cfg_bus_width_lp-1:0]                    cfg_bus_i

  // Calculator - Checker interface
  , input [dispatch_pkt_width_lp-1:0]               dispatch_pkt_i

  , input                                           flush_i

  , output                                          fpu_en_o
  , output                                          long_ready_o
  , output                                          mem_ready_o
  , output                                          sys_ready_o
  , output                                          ptw_busy_o

  , output [ptw_fill_pkt_width_lp-1:0]              ptw_fill_pkt_o
  , output [commit_pkt_width_lp-1:0]                commit_pkt_o
  , output [branch_pkt_width_lp-1:0]                br_pkt_o
  , output [wb_pkt_width_lp-1:0]                    iwb_pkt_o
  , output [wb_pkt_width_lp-1:0]                    fwb_pkt_o

  , input                                           timer_irq_i
  , input                                           software_irq_i
  , input                                           external_irq_i

  , output logic [dcache_req_width_lp-1:0]          cache_req_o
  , output logic                                    cache_req_v_o
  , input                                           cache_req_yumi_i
  , input                                           cache_req_busy_i
  , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
  , output logic                                    cache_req_metadata_v_o
  , input                                           cache_req_critical_i
  , input                                           cache_req_complete_i
  , input                                           cache_req_credits_full_i
  , input                                           cache_req_credits_empty_i

  , input                                           data_mem_pkt_v_i
  , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
  , output logic                                    data_mem_pkt_yumi_o
  , output logic [dcache_block_width_p-1:0]         data_mem_o

  , input                                           tag_mem_pkt_v_i
  , input [dcache_tag_mem_pkt_width_lp-1:0]         tag_mem_pkt_i
  , output logic                                    tag_mem_pkt_yumi_o
  , output logic [dcache_tag_info_width_lp-1:0]     tag_mem_o

  , input                                           stat_mem_pkt_v_i
  , input [dcache_stat_mem_pkt_width_lp-1:0]        stat_mem_pkt_i
  , output logic                                    stat_mem_pkt_yumi_o
  , output logic [dcache_stat_info_width_lp-1:0]    stat_mem_o
  );

  // Declare parameterizable structs
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Cast input and output ports
  bp_be_dispatch_pkt_s   dispatch_pkt;
  bp_be_wb_pkt_s         long_iwb_pkt, long_fwb_pkt;
  bp_be_commit_pkt_s     commit_pkt;

  assign dispatch_pkt = dispatch_pkt_i;
  assign commit_pkt_o = commit_pkt;

  // Pipeline stage registers
  bp_be_exc_stage_s      [pipe_stage_els_lp  :0] exc_stage_n;
  bp_be_exc_stage_s      [pipe_stage_els_lp-1:0] exc_stage_r;

  bp_be_wb_pkt_s [pipe_stage_els_lp  :0] comp_stage_n;
  bp_be_wb_pkt_s [pipe_stage_els_lp-1:0] comp_stage_r;

  bp_be_ptw_miss_pkt_s ptw_miss_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_trans_info_s   trans_info_lo;
  rv64_frm_e           frm_dyn_lo;
  assign ptw_fill_pkt_o = ptw_fill_pkt;

  logic pipe_mem_dtlb_store_miss_lo;
  logic pipe_mem_dtlb_load_miss_lo;
  logic pipe_mem_dcache_miss_lo;
  logic pipe_mem_fencei_lo;
  logic pipe_mem_load_misaligned_lo;
  logic pipe_mem_load_access_fault_lo;
  logic pipe_mem_load_page_fault_lo;
  logic pipe_mem_store_misaligned_lo;
  logic pipe_mem_store_access_fault_lo;
  logic pipe_mem_store_page_fault_lo;

  logic pipe_ctl_data_lo_v, pipe_int_data_lo_v, pipe_aux_data_lo_v, pipe_mem_early_data_lo_v, pipe_mem_final_data_lo_v, pipe_sys_data_lo_v, pipe_mul_data_lo_v, pipe_fma_data_lo_v;
  logic pipe_long_idata_lo_v, pipe_long_idata_lo_yumi, pipe_long_fdata_lo_v, pipe_long_fdata_lo_yumi;
  logic [dpath_width_gp-1:0] pipe_ctl_data_lo, pipe_int_data_lo, pipe_aux_data_lo, pipe_mem_early_data_lo, pipe_mem_final_data_lo, pipe_sys_data_lo, pipe_mul_data_lo, pipe_fma_data_lo;
  rv64_fflags_s pipe_aux_fflags_lo, pipe_fma_fflags_lo;

  logic pipe_sys_exc_v_lo, pipe_sys_miss_v_lo;

  // Generating match vector for bypass
  logic [2:0][pipe_stage_els_lp-1:0] match_rs;
  logic [pipe_stage_els_lp-1:0][dpath_width_gp-1:0] forward_data;
  for (genvar i = 0; i < pipe_stage_els_lp; i++)
    begin : forward_match
      assign match_rs[0][i] = (~dispatch_pkt.rs1_fp_v & comp_stage_r[i].ird_w_v & (dispatch_pkt.instr.t.fmatype.rs1_addr == comp_stage_r[i].rd_addr))
                              || (dispatch_pkt.rs1_fp_v & comp_stage_r[i].frd_w_v & (dispatch_pkt.instr.t.fmatype.rs1_addr == comp_stage_r[i].rd_addr));
      assign match_rs[1][i] = (~dispatch_pkt.rs2_fp_v & comp_stage_r[i].ird_w_v & (dispatch_pkt.instr.t.fmatype.rs2_addr == comp_stage_r[i].rd_addr))
                              || (dispatch_pkt.rs2_fp_v & comp_stage_r[i].frd_w_v & (dispatch_pkt.instr.t.fmatype.rs2_addr == comp_stage_r[i].rd_addr));
      assign match_rs[2][i] = (dispatch_pkt.rs3_fp_v & comp_stage_r[i].frd_w_v & (dispatch_pkt.instr.t.fmatype.rs3_addr == comp_stage_r[i].rd_addr));
  
      assign forward_data[i] = comp_stage_n[i+1].rd_data;
    end

  logic [2:0][dpath_width_gp-1:0] bypass_rs;
  wire [2:0][dpath_width_gp-1:0] dispatch_data = {dispatch_pkt.imm, dispatch_pkt.rs2, dispatch_pkt.rs1};
  for (genvar i = 0; i < 3; i++)
    begin : pencode
      logic [pipe_stage_els_lp:0] match_rs_onehot;
      bsg_priority_encode_one_hot_out
       #(.width_p(pipe_stage_els_lp+1), .lo_to_hi_p(1))
       pencode_oh
        (.i({1'b1, match_rs[i]})
         ,.o(match_rs_onehot)
         ,.v_o()
         );

      bsg_mux_one_hot
       #(.width_p(dpath_width_gp), .els_p(pipe_stage_els_lp+1))
       fwd_mux_oh
        (.data_i({dispatch_data[i], forward_data})
         ,.sel_one_hot_i(match_rs_onehot)
         ,.data_o(bypass_rs[i])
         );
    end

  // Override operands with bypass data
  bp_be_dispatch_pkt_s reservation_n, reservation_r;
  always_comb
    begin
      reservation_n        = dispatch_pkt_i;
      reservation_n.rs1    = bypass_rs[0];
      reservation_n.rs2    = bypass_rs[1];
      reservation_n.imm    = bypass_rs[2];
    end

  bsg_dff
   #(.width_p(dispatch_pkt_width_lp))
   reservation_reg
    (.clk_i(clk_i)
     ,.data_i(reservation_n)
     ,.data_o(reservation_r)
     );

  bp_be_pipe_ctl
   #(.bp_params_p(bp_params_p))
   pipe_ctl
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.flush_i(flush_i)

     ,.data_o(pipe_ctl_data_lo)
     ,.br_pkt_o(br_pkt_o)
     ,.v_o(pipe_ctl_data_lo_v)
     );

  // Computation pipelines
  // Integer pipe: 1 cycle latency
  bp_be_pipe_int
   #(.bp_params_p(bp_params_p))
   pipe_int
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)

     ,.data_o(pipe_int_data_lo)
     ,.v_o(pipe_int_data_lo_v)
     );

  // Aux pipe: 2 cycle latency
  bp_be_pipe_aux
   #(.bp_params_p(bp_params_p), .latency_p(2))
   pipe_aux
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.frm_dyn_i(frm_dyn_lo)

     ,.data_o(pipe_aux_data_lo)
     ,.fflags_o(pipe_aux_fflags_lo)
     ,.v_o(pipe_aux_data_lo_v)
     );

  logic pipe_mem_ready_lo;
  // Memory pipe: 2/3 cycle latency
  bp_be_pipe_mem
   #(.bp_params_p(bp_params_p))
   pipe_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.flush_i(flush_i)
     ,.sfence_i(commit_pkt.sfence)

     ,.reservation_i(reservation_r)
     ,.ready_o(pipe_mem_ready_lo)

     ,.ptw_miss_pkt_i(ptw_miss_pkt)
     ,.ptw_fill_pkt_o(ptw_fill_pkt)
     ,.ptw_busy_o(ptw_busy_o)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_busy_i(cache_req_busy_i)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_complete_i(cache_req_complete_i)
     ,.cache_req_credits_full_i(cache_req_credits_full_i)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_i)

     ,.data_mem_pkt_i(data_mem_pkt_i)
     ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)
     ,.data_mem_o(data_mem_o)

     ,.tag_mem_pkt_i(tag_mem_pkt_i)
     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)
     ,.tag_mem_o(tag_mem_o)

     ,.stat_mem_pkt_i(stat_mem_pkt_i)
     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
     ,.stat_mem_o(stat_mem_o)

     ,.tlb_store_miss_v_o(pipe_mem_dtlb_store_miss_lo)
     ,.tlb_load_miss_v_o(pipe_mem_dtlb_load_miss_lo)
     ,.cache_miss_v_o(pipe_mem_dcache_miss_lo)
     ,.fencei_v_o(pipe_mem_fencei_lo)
     ,.load_misaligned_v_o(pipe_mem_load_misaligned_lo)
     ,.load_access_fault_v_o(pipe_mem_load_access_fault_lo)
     ,.load_page_fault_v_o(pipe_mem_load_page_fault_lo)
     ,.store_misaligned_v_o(pipe_mem_store_misaligned_lo)
     ,.store_access_fault_v_o(pipe_mem_store_access_fault_lo)
     ,.store_page_fault_v_o(pipe_mem_store_page_fault_lo)
     ,.early_data_o(pipe_mem_early_data_lo)
     ,.final_data_o(pipe_mem_final_data_lo)
     ,.early_v_o(pipe_mem_early_data_lo_v)
     ,.final_v_o(pipe_mem_final_data_lo_v)

     ,.trans_info_i(trans_info_lo)
     );

  logic pipe_long_ready_lo, pipe_sys_ready_lo;
  bp_be_pipe_sys
   #(.bp_params_p(bp_params_p))
   pipe_sys
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_i)

     ,.ready_o(pipe_sys_ready_lo)
     ,.ptw_busy_i(ptw_busy_o)

     ,.reservation_i(reservation_r)
     ,.flush_i(flush_i)

     ,.ptw_miss_pkt_o(ptw_miss_pkt)
     ,.ptw_fill_pkt_i(ptw_fill_pkt)

     ,.commit_v_i(~exc_stage_r[2].nop_v & ~exc_stage_r[2].poison_v)
     ,.commit_queue_v_i(~exc_stage_r[2].nop_v & ~exc_stage_r[2].roll_v)
     ,.exception_i(exc_stage_r[2].exc)
     ,.commit_pkt_o(commit_pkt)
     ,.iwb_pkt_i(iwb_pkt_o)
     ,.fwb_pkt_i(fwb_pkt_o)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)

     ,.exc_v_o(pipe_sys_exc_v_lo)
     ,.miss_v_o(pipe_sys_miss_v_lo)
     ,.data_o(pipe_sys_data_lo)
     ,.v_o(pipe_sys_data_lo_v)

     ,.trans_info_o(trans_info_lo)
     ,.frm_dyn_o(frm_dyn_lo)
     ,.fpu_en_o(fpu_en_o)
     );

  // Floating point pipe: 4/5 cycle latency
  bp_be_pipe_fma
   #(.bp_params_p(bp_params_p), .imul_latency_p(4), .fma_latency_p(5))
   pipe_fma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.frm_dyn_i(frm_dyn_lo)

     ,.imul_data_o(pipe_mul_data_lo)
     ,.imul_v_o(pipe_mul_data_lo_v)
     ,.fma_data_o(pipe_fma_data_lo)
     ,.fma_fflags_o(pipe_fma_fflags_lo)
     ,.fma_v_o(pipe_fma_data_lo_v)
     );

  // Variable length pipeline, used for long (potentially scoreboarded operations)
  bp_be_pipe_long
   #(.bp_params_p(bp_params_p))
   pipe_long
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.flush_i(flush_i)
     ,.ready_o(pipe_long_ready_lo)
     ,.frm_dyn_i(frm_dyn_lo)

     ,.iwb_pkt_o(long_iwb_pkt)
     ,.iwb_v_o(pipe_long_idata_lo_v)
     ,.iwb_yumi_i(pipe_long_idata_lo_yumi)

     ,.fwb_pkt_o(long_fwb_pkt)
     ,.fwb_v_o(pipe_long_fdata_lo_v)
     ,.fwb_yumi_i(pipe_long_fdata_lo_yumi)
     );

  // If a pipeline has completed an instruction (pipe_xxx_v), then mux in the calculated result.
  // Else, mux in the previous stage of the completion pipe. Since we are single issue and have
  //   static latencies, we cannot have two pipelines complete at the same time.
  always_comb
    begin
      for (integer i = 0; i <= pipe_stage_els_lp; i++)
        begin : comp_stage
          // Normally, shift down in the pipe
          comp_stage_n[i] = (i == 0)
            ? '{ird_w_v    : reservation_n.decode.irf_w_v
                ,frd_w_v   : reservation_n.decode.frf_w_v
                ,fflags_w_v: reservation_n.decode.fflags_w_v
                ,rd_addr   : reservation_n.instr.t.rtype.rd_addr
                ,default: '0
                }
            : comp_stage_r[i-1];
        end
      comp_stage_n[1].rd_data    |= pipe_int_data_lo_v       ? pipe_int_data_lo       : pipe_ctl_data_lo_v ? pipe_ctl_data_lo : '0;
      comp_stage_n[2].rd_data    |= pipe_mem_early_data_lo_v ? pipe_mem_early_data_lo : pipe_aux_data_lo_v ? pipe_aux_data_lo : '0;
      comp_stage_n[3].rd_data    |= pipe_mem_final_data_lo_v ? pipe_mem_final_data_lo : pipe_sys_data_lo_v ? pipe_sys_data_lo : '0;
      comp_stage_n[4].rd_data    |= pipe_mul_data_lo_v       ? pipe_mul_data_lo       : '0;
      comp_stage_n[5].rd_data    |= pipe_fma_data_lo_v       ? pipe_fma_data_lo       : '0;

      comp_stage_n[2].fflags     |= pipe_aux_data_lo_v       ? pipe_aux_fflags_lo     : '0;
      comp_stage_n[5].fflags     |= pipe_fma_data_lo_v       ? pipe_fma_fflags_lo     : '0;

      comp_stage_n[0].ird_w_v    &= ~exc_stage_n[0].poison_v;
      comp_stage_n[1].ird_w_v    &= ~exc_stage_n[1].poison_v;
      comp_stage_n[2].ird_w_v    &= ~exc_stage_n[2].poison_v;
      comp_stage_n[3].ird_w_v    &= ~exc_stage_n[3].poison_v;

      comp_stage_n[0].frd_w_v    &= ~exc_stage_n[0].poison_v;
      comp_stage_n[1].frd_w_v    &= ~exc_stage_n[1].poison_v;
      comp_stage_n[2].frd_w_v    &= ~exc_stage_n[2].poison_v;
      comp_stage_n[3].frd_w_v    &= ~exc_stage_n[3].poison_v;

      comp_stage_n[0].fflags_w_v &= ~exc_stage_n[0].poison_v;
      comp_stage_n[1].fflags_w_v &= ~exc_stage_n[1].poison_v;
      comp_stage_n[2].fflags_w_v &= ~exc_stage_n[2].poison_v;
      comp_stage_n[3].fflags_w_v &= ~exc_stage_n[3].poison_v;
    end

  bsg_dff
   #(.width_p($bits(bp_be_wb_pkt_s)*pipe_stage_els_lp))
   comp_stage_reg
    (.clk_i(clk_i)
     ,.data_i(comp_stage_n[0+:pipe_stage_els_lp])
     ,.data_o(comp_stage_r)
     );

  always_comb
    begin
      // Exception aggregation
      for (integer i = 0; i <= pipe_stage_els_lp; i++)
        begin : exc_stage
          // Normally, shift down in the pipe
          exc_stage_n[i] = (i == 0) ? '0 : exc_stage_r[i-1];
        end
          exc_stage_n[0].nop_v                  |= ~reservation_n.v;

          exc_stage_n[0].roll_v                 |= pipe_sys_miss_v_lo;
          exc_stage_n[1].roll_v                 |= pipe_sys_miss_v_lo;
          exc_stage_n[2].roll_v                 |= pipe_sys_miss_v_lo;
          exc_stage_n[3].roll_v                 |= pipe_sys_miss_v_lo;

          exc_stage_n[0].poison_v               |= reservation_n.poison;
          exc_stage_n[1].poison_v               |= flush_i;
          exc_stage_n[2].poison_v               |= flush_i;
          // We only poison on exception or cache miss, because we also flush
          // on, for instance, fence.i
          exc_stage_n[3].poison_v               |= pipe_sys_miss_v_lo | pipe_sys_exc_v_lo;

          exc_stage_n[0].exc.itlb_miss          |= reservation_n.decode.itlb_miss;
          exc_stage_n[0].exc.icache_miss        |= reservation_n.decode.icache_miss;
          exc_stage_n[0].exc.instr_access_fault |= reservation_n.decode.instr_access_fault;
          exc_stage_n[0].exc.instr_page_fault   |= reservation_n.decode.instr_page_fault;
          exc_stage_n[0].exc.illegal_instr      |= reservation_n.decode.illegal_instr;
          exc_stage_n[0].exc.ebreak             |= reservation_n.decode.ebreak;
          exc_stage_n[0].exc.ecall              |= reservation_n.decode.ecall;

          exc_stage_n[1].exc.dtlb_store_miss    |= pipe_mem_dtlb_store_miss_lo;
          exc_stage_n[1].exc.dtlb_load_miss     |= pipe_mem_dtlb_load_miss_lo;
          exc_stage_n[1].exc.load_misaligned    |= pipe_mem_load_misaligned_lo;
          exc_stage_n[1].exc.load_access_fault  |= pipe_mem_load_access_fault_lo;
          exc_stage_n[1].exc.load_page_fault    |= pipe_mem_load_page_fault_lo;
          exc_stage_n[1].exc.store_misaligned   |= pipe_mem_store_misaligned_lo;
          exc_stage_n[1].exc.store_access_fault |= pipe_mem_store_access_fault_lo;
          exc_stage_n[1].exc.store_page_fault   |= pipe_mem_store_page_fault_lo;

          exc_stage_n[2].exc.dcache_miss        |= pipe_mem_dcache_miss_lo;
          exc_stage_n[2].exc.fencei_v           |= pipe_mem_fencei_lo;
    end

  // Exception pipeline
  bsg_dff
   #(.width_p($bits(bp_be_exc_stage_s)*pipe_stage_els_lp))
   exc_stage_reg
    (.clk_i(clk_i)
     ,.data_i(exc_stage_n[0+:pipe_stage_els_lp])
     ,.data_o(exc_stage_r)
     );

  assign pipe_long_idata_lo_yumi = pipe_long_idata_lo_v & ~comp_stage_r[4].ird_w_v;
  assign pipe_long_fdata_lo_yumi = pipe_long_fdata_lo_v & ~comp_stage_r[5].frd_w_v & ~comp_stage_r[5].fflags_w_v;

  assign iwb_pkt_o = pipe_long_idata_lo_yumi ? long_iwb_pkt : comp_stage_r[4];
  assign fwb_pkt_o = pipe_long_fdata_lo_yumi ? long_fwb_pkt : comp_stage_r[5];

  assign mem_ready_o  = pipe_mem_ready_lo;
  assign long_ready_o = pipe_long_ready_lo;
  assign sys_ready_o  = pipe_sys_ready_lo;

endmodule


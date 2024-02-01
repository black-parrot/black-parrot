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
    `declare_bp_be_dcache_engine_if_widths(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p)

   // Generated parameters
   , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   , localparam dispatch_pkt_width_lp   = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam branch_pkt_width_lp     = `bp_be_branch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp     = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam wb_pkt_width_lp         = `bp_be_wb_pkt_width(vaddr_width_p)
   , localparam decode_info_width_lp    = `bp_be_decode_info_width
   , localparam trans_info_width_lp     = `bp_be_trans_info_width(ptag_width_p)
   )
  (input                                             clk_i
   , input                                           reset_i

   , input [cfg_bus_width_lp-1:0]                    cfg_bus_i

   // Calculator - Checker interface
   , input [dispatch_pkt_width_lp-1:0]               dispatch_pkt_i

   , output logic                                    idiv_busy_o
   , output logic                                    fdiv_busy_o
   , output logic                                    mem_busy_o
   , output logic                                    mem_ordered_o
   , output logic [decode_info_width_lp-1:0]         decode_info_o
   , output logic [trans_info_width_lp-1:0]          trans_info_o
   , input                                           cmd_full_n_i

   , output logic [commit_pkt_width_lp-1:0]          commit_pkt_o
   , output logic [branch_pkt_width_lp-1:0]          br_pkt_o
   , output logic [wb_pkt_width_lp-1:0]              iwb_pkt_o
   , output logic [wb_pkt_width_lp-1:0]              fwb_pkt_o

   , output logic [wb_pkt_width_lp-1:0]              late_wb_pkt_o
   , output logic                                    late_wb_v_o
   , output logic                                    late_wb_force_o
   , input                                           late_wb_yumi_i

   , input                                           debug_irq_i
   , input                                           timer_irq_i
   , input                                           software_irq_i
   , input                                           m_external_irq_i
   , input                                           s_external_irq_i
   , output logic                                    irq_waiting_o
   , output logic                                    irq_pending_o

   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_lock_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input [dcache_req_id_width_p-1:0]               cache_req_id_i
   , input                                           cache_req_critical_i
   , input                                           cache_req_last_i
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
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `bp_cast_i(bp_be_dispatch_pkt_s, dispatch_pkt);
  `bp_cast_o(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_o(bp_be_branch_pkt_s, br_pkt);
  `bp_cast_o(bp_be_wb_pkt_s, iwb_pkt);
  `bp_cast_o(bp_be_wb_pkt_s, fwb_pkt);
  `bp_cast_o(bp_be_wb_pkt_s, late_wb_pkt);

  // Pipeline stage registers
  localparam pipe_stage_els_lp = 5;
  bp_be_exc_stage_s [pipe_stage_els_lp  :0] exc_stage_n;
  bp_be_exc_stage_s [pipe_stage_els_lp-1:0] exc_stage_r;

  bp_be_wb_pkt_s [pipe_stage_els_lp  :0] comp_stage_n;
  bp_be_wb_pkt_s [pipe_stage_els_lp-1:0] comp_stage_r;

  rv64_frm_e frm_dyn_lo;

  bp_be_wb_pkt_s pipe_long_iwb_pkt, pipe_long_fwb_pkt;

  logic pipe_int_early_instr_misaligned_lo;
  logic pipe_int_catchup_instr_misaligned_lo, pipe_int_catchup_mispredict_lo;

  logic pipe_mem_dtlb_load_miss_lo, pipe_mem_dtlb_store_miss_lo;
  logic pipe_mem_dcache_load_miss_lo, pipe_mem_dcache_miss_lo, pipe_mem_dcache_replay_lo;
  logic pipe_mem_load_misaligned_lo, pipe_mem_load_access_fault_lo, pipe_mem_load_page_fault_lo;
  logic pipe_mem_store_misaligned_lo, pipe_mem_store_access_fault_lo, pipe_mem_store_page_fault_lo;

  logic pipe_sys_illegal_instr_lo;

  logic pipe_int_early_data_v_lo, pipe_int_catchup_data_v_lo, pipe_aux_data_v_lo, pipe_mem_early_data_v_lo, pipe_mem_final_data_v_lo, pipe_sys_data_v_lo, pipe_mul_data_v_lo, pipe_fma_data_v_lo;
  logic pipe_long_idata_v_lo, pipe_long_idata_yumi_lo, pipe_long_fdata_v_lo, pipe_long_fdata_yumi_lo;
  logic [dpath_width_gp-1:0] pipe_int_early_data_lo, pipe_int_catchup_data_lo, pipe_aux_data_lo, pipe_mem_early_data_lo, pipe_mem_final_data_lo, pipe_sys_data_lo, pipe_mul_data_lo, pipe_fma_data_lo;
  rv64_fflags_s pipe_aux_fflags_lo, pipe_fma_fflags_lo;

  logic [vaddr_width_p-1:0] pipe_int_early_npc_lo;
  logic pipe_int_early_branch_lo, pipe_int_early_btaken_lo;

  logic [vaddr_width_p-1:0] pipe_int_catchup_npc_lo;
  logic pipe_int_catchup_branch_lo, pipe_int_catchup_btaken_lo;

  bp_be_wb_pkt_s pipe_mem_late_wb_pkt;
  logic pipe_mem_late_wb_v, pipe_mem_late_wb_yumi;

  // Generating match vector for bypass
  logic [2:0][pipe_stage_els_lp-1:0] match_rs;
  logic [pipe_stage_els_lp-1:0][dpath_width_gp-1:0] forward_data;
  for (genvar i = 0; i < pipe_stage_els_lp; i++)
    begin : forward_match
      assign match_rs[0][i] = ((i < 4) & dispatch_pkt_cast_i.decode.irs1_r_v & comp_stage_r[i].ird_w_v & (dispatch_pkt_cast_i.instr.t.fmatype.rs1_addr == comp_stage_r[i].rd_addr))
                              || (dispatch_pkt_cast_i.decode.frs1_r_v & comp_stage_r[i].frd_w_v & (dispatch_pkt_cast_i.instr.t.fmatype.rs1_addr == comp_stage_r[i].rd_addr));
      assign match_rs[1][i] = ((i < 4) & dispatch_pkt_cast_i.decode.irs2_r_v & comp_stage_r[i].ird_w_v & (dispatch_pkt_cast_i.instr.t.fmatype.rs2_addr == comp_stage_r[i].rd_addr))
                              || (dispatch_pkt_cast_i.decode.frs2_r_v & comp_stage_r[i].frd_w_v & (dispatch_pkt_cast_i.instr.t.fmatype.rs2_addr == comp_stage_r[i].rd_addr));
      assign match_rs[2][i] = (dispatch_pkt_cast_i.decode.frs3_r_v & comp_stage_r[i].frd_w_v & (dispatch_pkt_cast_i.instr.t.fmatype.rs3_addr == comp_stage_r[i].rd_addr));

      assign forward_data[i] = comp_stage_n[i+1].rd_data;
    end

  logic [2:0][dpath_width_gp-1:0] bypass_rs;
  wire [2:0][dpath_width_gp-1:0] dispatch_data = {dispatch_pkt_cast_i.imm, dispatch_pkt_cast_i.rs2, dispatch_pkt_cast_i.rs1};
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

  bp_be_reservation_s reservation_r;
  bp_be_reservation
   #(.bp_params_p(bp_params_p))
   reservation_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dispatch_pkt_i(dispatch_pkt_cast_i)
     ,.bypass_rs_i(bypass_rs)
     ,.reservation_o(reservation_r)
     );

  // Computation pipelines
  // System pipe: 1 cycle latency
  bp_be_pipe_sys
   #(.bp_params_p(bp_params_p))
   pipe_sys
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_i)

     ,.reservation_i(reservation_r)
     ,.flush_i(commit_pkt_cast_o.npc_w_v)

     ,.retire_v_i(exc_stage_r[2].v)
     ,.retire_queue_v_i(exc_stage_r[2].queue_v)
     ,.retire_partial_v_i(exc_stage_r[2].partial_v)
     ,.retire_data_i(comp_stage_r[2].rd_data)
     ,.retire_exception_i(exc_stage_r[2].exc)
     ,.retire_special_i(exc_stage_r[2].spec)
     ,.commit_pkt_o(commit_pkt_cast_o)
     ,.iwb_pkt_i(iwb_pkt_o)
     ,.fwb_pkt_i(fwb_pkt_o)

     ,.debug_irq_i(debug_irq_i)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     ,.irq_pending_o(irq_pending_o)
     ,.irq_waiting_o(irq_waiting_o)

     ,.illegal_instr_o(pipe_sys_illegal_instr_lo)
     ,.data_o(pipe_sys_data_lo)
     ,.v_o(pipe_sys_data_v_lo)

     ,.decode_info_o(decode_info_o)
     ,.trans_info_o(trans_info_o)
     ,.frm_dyn_o(frm_dyn_lo)
     );

  // Integer pipe: 1 cycle latency
  bp_be_pipe_int
   #(.bp_params_p(bp_params_p))
   pipe_int_early
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(~exc_stage_r[0].ispec_v)
     ,.reservation_i(reservation_r)
     ,.flush_i(commit_pkt_cast_o.npc_w_v)

     ,.data_o(pipe_int_early_data_lo)
     ,.v_o(pipe_int_early_data_v_lo)
     ,.npc_o(pipe_int_early_npc_lo)
     ,.branch_o(pipe_int_early_branch_lo)
     ,.btaken_o(pipe_int_early_btaken_lo)
     ,.instr_misaligned_v_o(pipe_int_early_instr_misaligned_lo)
     );

  assign br_pkt_cast_o.v      = exc_stage_r[0].v & exc_stage_r[0].queue_v & ~commit_pkt_cast_o.npc_w_v;
  assign br_pkt_cast_o.branch = br_pkt_cast_o.v & pipe_int_early_branch_lo;
  assign br_pkt_cast_o.btaken = br_pkt_cast_o.v & pipe_int_early_btaken_lo;
  assign br_pkt_cast_o.bspec  = br_pkt_cast_o.v & exc_stage_r[0].ispec_v;
  assign br_pkt_cast_o.npc    = pipe_int_early_npc_lo;

  logic [dword_width_gp-1:0] rs2_val_r;
  if (integer_support_p[e_catchup])
    begin : catchup
      logic [dword_width_gp-1:0] catchup_bypass_src1;
      bp_be_int_unbox
       #(.bp_params_p(bp_params_p))
       irs1_unbox
        (.reg_i(comp_stage_n[2].rd_data)
         ,.tag_i(reservation_r.decode.int_tag)
         ,.unsigned_i(reservation_r.decode.rs1_unsigned)
         ,.val_o(catchup_bypass_src1)
         );

      logic [dword_width_gp-1:0] catchup_bypass_src2;
      bp_be_int_unbox
       #(.bp_params_p(bp_params_p))
       irs2_unbox
        (.reg_i(comp_stage_n[2].rd_data)
         ,.tag_i(reservation_r.decode.int_tag)
         ,.unsigned_i(reservation_r.decode.rs2_unsigned)
         ,.val_o(catchup_bypass_src2)
         );

      bp_be_reservation_s catchup_reservation_n, catchup_reservation_r;
      always_comb
        begin
          catchup_reservation_n = reservation_r;
          if (reservation_r.decode.irs1_r_v && comp_stage_r[1].ird_w_v && (comp_stage_r[1].rd_addr == reservation_r.instr.t.rtype.rs1_addr))
            catchup_reservation_n.isrc1 = catchup_bypass_src1;
          if (reservation_r.decode.irs2_r_v && comp_stage_r[1].ird_w_v && (comp_stage_r[1].rd_addr == reservation_r.instr.t.rtype.rs2_addr))
            catchup_reservation_n.isrc2 = catchup_bypass_src2;
        end

      bsg_dff
       #(.width_p($bits(bp_be_reservation_s)))
       catchup_reservation_reg
        (.clk_i(clk_i)
         ,.data_i(catchup_reservation_n)
         ,.data_o(catchup_reservation_r)
         );

      // Catchup integer pipe: 1 cycle latency, starts at EX2
      bp_be_pipe_int
       #(.bp_params_p(bp_params_p))
       pipe_int_catchup
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.en_i(exc_stage_r[1].ispec_v)
         ,.reservation_i(catchup_reservation_r)
         ,.flush_i(commit_pkt_cast_o.npc_w_v)

         ,.data_o(pipe_int_catchup_data_lo)
         ,.v_o(pipe_int_catchup_data_v_lo)
         ,.npc_o(pipe_int_catchup_npc_lo)
         ,.branch_o(pipe_int_catchup_branch_lo)
         ,.btaken_o(pipe_int_catchup_btaken_lo)
         ,.instr_misaligned_v_o(pipe_int_catchup_instr_misaligned_lo)
         );
      assign pipe_int_catchup_mispredict_lo = exc_stage_r[1].ispec_v & (pipe_int_catchup_npc_lo != reservation_r.pc);

      assign rs2_val_r =
        catchup_reservation_r.decode.irs2_r_v ? catchup_reservation_r.isrc2 : catchup_reservation_r.fsrc2;;
    end
  else
    begin : no_catchup
      assign pipe_int_catchup_data_lo = '0;
      assign pipe_int_catchup_data_v_lo = '0;
      assign pipe_int_catchup_mispredict_lo = '0;
      assign pipe_int_catchup_instr_misaligned_lo = '0;

      wire [dword_width_gp-1:0] rs2_val_n =
        reservation_r.decode.irs2_r_v ? reservation_r.isrc2 : reservation_r.fsrc2;
      bsg_dff
       #(.width_p(dword_width_gp))
       rs2_reg
        (.clk_i(clk_i)
         ,.data_i(rs2_val_n)
         ,.data_o(rs2_val_r)
         );
    end

  // Aux pipe: 2 cycle latency
  bp_be_pipe_aux
   #(.bp_params_p(bp_params_p))
   pipe_aux
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.flush_i(commit_pkt_cast_o.npc_w_v)
     ,.frm_dyn_i(frm_dyn_lo)

     ,.data_o(pipe_aux_data_lo)
     ,.fflags_o(pipe_aux_fflags_lo)
     ,.v_o(pipe_aux_data_v_lo)
     );

  // Memory pipe: 2/3 cycle latency
  bp_be_pipe_mem
   #(.bp_params_p(bp_params_p))
   pipe_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.flush_i(commit_pkt_cast_o.npc_w_v)
     ,.sfence_i(commit_pkt_cast_o.sfence)

     ,.busy_o(mem_busy_o)
     ,.ordered_o(mem_ordered_o)

     ,.reservation_i(reservation_r)
     ,.rs2_val_i(rs2_val_r)

     ,.commit_pkt_i(commit_pkt_cast_o)

     ,.cache_req_o(cache_req_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_lock_i(cache_req_lock_i)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_id_i(cache_req_id_i)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_last_i(cache_req_last_i)
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
     ,.cache_replay_v_o(pipe_mem_dcache_replay_lo)
     ,.cache_miss_v_o(pipe_mem_dcache_miss_lo)
     ,.load_misaligned_v_o(pipe_mem_load_misaligned_lo)
     ,.load_access_fault_v_o(pipe_mem_load_access_fault_lo)
     ,.load_page_fault_v_o(pipe_mem_load_page_fault_lo)
     ,.store_misaligned_v_o(pipe_mem_store_misaligned_lo)
     ,.store_access_fault_v_o(pipe_mem_store_access_fault_lo)
     ,.store_page_fault_v_o(pipe_mem_store_page_fault_lo)

     ,.early_data_o(pipe_mem_early_data_lo)
     ,.early_v_o(pipe_mem_early_data_v_lo)

     ,.final_data_o(pipe_mem_final_data_lo)
     ,.final_v_o(pipe_mem_final_data_v_lo)

     ,.late_wb_pkt_o(pipe_mem_late_wb_pkt)
     ,.late_wb_v_o(pipe_mem_late_wb_v)

     ,.trans_info_i(trans_info_o)
     );

  // Floating point pipe: 3/4 cycle latency
  bp_be_pipe_fma
   #(.bp_params_p(bp_params_p))
   pipe_fma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.flush_i(commit_pkt_cast_o.npc_w_v)
     ,.frm_dyn_i(frm_dyn_lo)

     ,.imul_data_o(pipe_mul_data_lo)
     ,.imul_v_o(pipe_mul_data_v_lo)
     ,.fma_data_o(pipe_fma_data_lo)
     ,.fma_fflags_o(pipe_fma_fflags_lo)
     ,.fma_v_o(pipe_fma_data_v_lo)
     );

  // Variable length pipeline, used for long (potentially scoreboarded operations)
  bp_be_pipe_long
   #(.bp_params_p(bp_params_p))
   pipe_long
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reservation_i(reservation_r)
     ,.flush_i(commit_pkt_cast_o.npc_w_v)
     ,.ibusy_o(idiv_busy_o)
     ,.fbusy_o(fdiv_busy_o)
     ,.frm_dyn_i(frm_dyn_lo)

     ,.iwb_pkt_o(pipe_long_iwb_pkt)
     ,.iwb_v_o(pipe_long_idata_v_lo)
     ,.iwb_yumi_i(pipe_long_idata_yumi_lo)

     ,.fwb_pkt_o(pipe_long_fwb_pkt)
     ,.fwb_v_o(pipe_long_fdata_v_lo)
     ,.fwb_yumi_i(pipe_long_fdata_yumi_lo)
     );

  localparam num_late_wb_lp = 3;
  logic [num_late_wb_lp-1:0] late_wb_reqs_li, late_wb_grants_lo;
  assign {pipe_long_fdata_yumi_lo, pipe_long_idata_yumi_lo, pipe_mem_late_wb_yumi} =
    late_wb_grants_lo & {num_late_wb_lp{late_wb_yumi_i}};
  assign late_wb_reqs_li = {pipe_long_fdata_v_lo, pipe_long_idata_v_lo, pipe_mem_late_wb_v};
  bsg_arb_fixed
   #(.inputs_p(num_late_wb_lp), .lo_to_hi_p(1))
   late_wb_arb
    (.ready_then_i(1'b1)
     ,.reqs_i(late_wb_reqs_li)
     ,.grants_o(late_wb_grants_lo)
     );

  bp_be_wb_pkt_s late_wb_pkt_sel;
  wire [num_late_wb_lp-1:0][$bits(bp_be_wb_pkt_s)-1:0] late_wb_pkts_li =
    {pipe_long_fwb_pkt, pipe_long_iwb_pkt, pipe_mem_late_wb_pkt};
  bsg_mux_one_hot
   #(.width_p($bits(bp_be_wb_pkt_s)), .els_p(num_late_wb_lp))
   late_wb_mux_oh
    (.data_i(late_wb_pkts_li)
     ,.sel_one_hot_i(late_wb_grants_lo)
     ,.data_o(late_wb_pkt_sel)
     );

  assign late_wb_pkt_cast_o = late_wb_pkt_sel;
  assign late_wb_v_o = |late_wb_grants_lo;
  assign late_wb_force_o = pipe_mem_late_wb_v;

  // If a pipeline has completed an instruction (pipe_xxx_v), then mux in the calculated result.
  // Else, mux in the previous stage of the completion pipe. Since we are single issue and have
  //   static latencies, we cannot have two pipelines complete at the same time.
  wire injection = dispatch_pkt_cast_i.v & ~dispatch_pkt_cast_i.queue_v;
  always_comb
    begin
      for (integer i = 0; i <= pipe_stage_els_lp; i++)
        begin : comp_stage
          // Normally, shift down in the pipe
          comp_stage_n[i] = (i == 0)
            ? '{ird_w_v    : dispatch_pkt_cast_i.decode.irf_w_v
                ,frd_w_v   : dispatch_pkt_cast_i.decode.frf_w_v
                ,rd_addr   : dispatch_pkt_cast_i.instr.t.rtype.rd_addr
                ,default: '0
                }
            : comp_stage_r[i-1];
        end
      // Injected instructions can carry a payload in rs2
      comp_stage_n[0].rd_data    |= injection                  ? dispatch_pkt_cast_i.rs2  : '0;
      comp_stage_n[1].rd_data    |= pipe_int_early_data_v_lo   ? pipe_int_early_data_lo   : '0;
      comp_stage_n[1].rd_data    |= pipe_sys_data_v_lo         ? pipe_sys_data_lo         : '0;
      comp_stage_n[2].rd_data    |= pipe_mem_early_data_v_lo   ? pipe_mem_early_data_lo   : '0;
      comp_stage_n[2].rd_data    |= pipe_aux_data_v_lo         ? pipe_aux_data_lo         : '0;
      comp_stage_n[2].rd_data    |= pipe_int_catchup_data_v_lo ? pipe_int_catchup_data_lo : '0;
      comp_stage_n[3].rd_data    |= pipe_mem_final_data_v_lo   ? pipe_mem_final_data_lo   : '0;
      comp_stage_n[3].rd_data    |= pipe_mul_data_v_lo         ? pipe_mul_data_lo         : '0;
      comp_stage_n[4].rd_data    |= pipe_fma_data_v_lo         ? pipe_fma_data_lo         : '0;

      // Injected instructions can carry a payload in imm
      comp_stage_n[0].fflags     |= injection                  ? dispatch_pkt_cast_i.imm  : '0;
      comp_stage_n[2].fflags     |= pipe_aux_data_v_lo         ? pipe_aux_fflags_lo       : '0;
      comp_stage_n[4].fflags     |= pipe_fma_data_v_lo         ? pipe_fma_fflags_lo       : '0;

      comp_stage_n[0].ird_w_v    &= exc_stage_n[0].v;
      comp_stage_n[1].ird_w_v    &= exc_stage_n[1].v;
      comp_stage_n[2].ird_w_v    &= exc_stage_n[2].v;
      comp_stage_n[3].ird_w_v    &= exc_stage_n[3].v;
      comp_stage_n[4].ird_w_v    &= exc_stage_n[4].v;

      comp_stage_n[0].frd_w_v    &= exc_stage_n[0].v;
      comp_stage_n[1].frd_w_v    &= exc_stage_n[1].v;
      comp_stage_n[2].frd_w_v    &= exc_stage_n[2].v;
      comp_stage_n[3].frd_w_v    &= exc_stage_n[3].v;
      comp_stage_n[4].frd_w_v    &= exc_stage_n[4].v;

      comp_stage_n[0].fflags     &= {5{exc_stage_n[0].v}};
      comp_stage_n[1].fflags     &= {5{exc_stage_n[1].v}};
      comp_stage_n[2].fflags     &= {5{exc_stage_n[2].v}};
      comp_stage_n[3].fflags     &= {5{exc_stage_n[3].v}};
      comp_stage_n[4].fflags     &= {5{exc_stage_n[4].v}};

      comp_stage_n[3].ird_w_v    &= ~commit_pkt_cast_o.iscore_v;
      comp_stage_n[3].frd_w_v    &= ~commit_pkt_cast_o.fscore_v;
    end

  bsg_dff
   #(.width_p($bits(bp_be_wb_pkt_s)*pipe_stage_els_lp))
   comp_stage_reg
    (.clk_i(clk_i)
     ,.data_i(comp_stage_n[0+:pipe_stage_els_lp])
     ,.data_o(comp_stage_r)
     );
  assign iwb_pkt_cast_o = comp_stage_r[3];
  assign fwb_pkt_cast_o = comp_stage_r[4];

  always_comb
    begin
      // Exception aggregation
      for (integer i = 0; i <= pipe_stage_els_lp; i++)
        begin : exc_stage
          // Normally, shift down in the pipe
          exc_stage_n[i] = (i == 0) ? '0 : exc_stage_r[i-1];
        end
          exc_stage_n[0].v                        |= dispatch_pkt_cast_i.v;
          exc_stage_n[0].queue_v                  |= dispatch_pkt_cast_i.queue_v;
          exc_stage_n[0].ispec_v                  |= dispatch_pkt_cast_i.ispec_v;
          exc_stage_n[0].nspec_v                  |= dispatch_pkt_cast_i.nspec_v;
          exc_stage_n[0].partial_v                |= dispatch_pkt_cast_i.partial;
          exc_stage_n[0].spec                     |= dispatch_pkt_cast_i.special;
          exc_stage_n[0].exc                      |= dispatch_pkt_cast_i.exception;

          exc_stage_n[0].v                        &= ~commit_pkt_cast_o.npc_w_v | dispatch_pkt_cast_i.nspec_v;
          exc_stage_n[1].v                        &= ~commit_pkt_cast_o.npc_w_v | exc_stage_r[0].nspec_v;
          exc_stage_n[2].v                        &= ~commit_pkt_cast_o.npc_w_v | exc_stage_r[1].nspec_v;
          exc_stage_n[3].v                        &=  commit_pkt_cast_o.instret | exc_stage_r[2].nspec_v;

          exc_stage_n[0].queue_v                  &= ~commit_pkt_cast_o.npc_w_v;
          exc_stage_n[1].queue_v                  &= ~commit_pkt_cast_o.npc_w_v;
          exc_stage_n[2].queue_v                  &= ~commit_pkt_cast_o.npc_w_v;

          exc_stage_n[1].exc.illegal_instr        |= pipe_sys_illegal_instr_lo;

          exc_stage_n[1].exc.instr_misaligned     |= pipe_int_early_instr_misaligned_lo;

          exc_stage_n[1].exc.dtlb_store_miss      |= pipe_mem_dtlb_store_miss_lo;
          exc_stage_n[1].exc.dtlb_load_miss       |= pipe_mem_dtlb_load_miss_lo;
          exc_stage_n[1].exc.load_misaligned      |= pipe_mem_load_misaligned_lo;
          exc_stage_n[1].exc.load_access_fault    |= pipe_mem_load_access_fault_lo;
          exc_stage_n[1].exc.load_page_fault      |= pipe_mem_load_page_fault_lo;
          exc_stage_n[1].exc.store_misaligned     |= pipe_mem_store_misaligned_lo;
          exc_stage_n[1].exc.store_access_fault   |= pipe_mem_store_access_fault_lo;
          exc_stage_n[1].exc.store_page_fault     |= pipe_mem_store_page_fault_lo;

          exc_stage_n[2].exc.instr_misaligned     |= pipe_int_catchup_instr_misaligned_lo;
          exc_stage_n[2].exc.mispredict           |= pipe_int_catchup_mispredict_lo;

          exc_stage_n[2].exc.dcache_replay        |= pipe_mem_dcache_replay_lo;
          exc_stage_n[2].spec.dcache_miss         |= pipe_mem_dcache_miss_lo;
          exc_stage_n[2].exc.cmd_full             |= |{exc_stage_r[2].exc, exc_stage_r[2].spec} & cmd_full_n_i;
    end

  // Exception pipeline
  bsg_dff
   #(.width_p($bits(bp_be_exc_stage_s)*pipe_stage_els_lp))
   exc_stage_reg
    (.clk_i(clk_i)
     ,.data_i(exc_stage_n[0+:pipe_stage_els_lp])
     ,.data_o(exc_stage_r)
     );

endmodule


/**
 *
 * Name:
 *   bp_be_scheduler.v
 *
 * Description:
 *   Schedules instruction issue from the FE queue to the Calculator.
 *
 * Notes:
 *   It might make sense to use an enum for RISC-V opcodes rather than `defines.
 *   Floating point instruction decoding is not implemented, so we do not predecode.
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_scheduler
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam decode_info_width_lp = `bp_be_decode_info_width
   , localparam wb_pkt_width_lp     = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                      clk_i
   , input                                    reset_i

   , output logic [issue_pkt_width_lp-1:0]    issue_pkt_o
   , input [vaddr_width_p-1:0]                expected_npc_i
   , input                                    poison_isd_i
   , input                                    clear_iss_i
   , input                                    suppress_iss_i
   , input                                    unfreeze_i
   , input [decode_info_width_lp-1:0]         decode_info_i
   , input                                    dispatch_v_i
   , input                                    interrupt_v_i
   , input                                    ispec_v_i

   // Fetch interface
   , input [fe_queue_width_lp-1:0]            fe_queue_i
   , input                                    fe_queue_v_i
   , output logic                             fe_queue_ready_and_o

   // Dispatch interface
   , output logic [dispatch_pkt_width_lp-1:0] dispatch_pkt_o

   , input [commit_pkt_width_lp-1:0]          commit_pkt_i
   , input [wb_pkt_width_lp-1:0]              iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]              fwb_pkt_i
   , input [ptw_fill_pkt_width_lp-1:0]        ptw_fill_pkt_i
   );

  // Declare parameterizable structures
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `bp_cast_o(bp_be_issue_pkt_s, issue_pkt);
  `bp_cast_o(bp_be_dispatch_pkt_s, dispatch_pkt);
  `bp_cast_i(bp_be_ptw_fill_pkt_s, ptw_fill_pkt);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_i(bp_be_wb_pkt_s, iwb_pkt);
  `bp_cast_i(bp_be_wb_pkt_s, fwb_pkt);

  wire fe_queue_suppress_li  = suppress_iss_i;
  wire fe_queue_clr_li       = clear_iss_i;
  wire fe_queue_deq_li       = commit_pkt_cast_i.queue_v;
  wire fe_queue_deq_skip_li  = !commit_pkt_cast_i.compressed | commit_pkt_cast_i.partial;
  wire fe_queue_roll_li      = commit_pkt_cast_i.npc_w_v;
  wire fe_queue_read_li      = dispatch_v_i & ~poison_isd_i;
  wire fe_queue_read_skip_li = !dispatch_pkt_cast_o.compressed | dispatch_pkt_cast_o.partial;
  wire fe_queue_inject_li    = ptw_fill_pkt_cast_i.v | unfreeze_i | interrupt_v_i;

  bp_be_preissue_pkt_s preissue_pkt;
  bp_be_issue_queue
   #(.bp_params_p(bp_params_p))
   issue_queue
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clr_v_i(fe_queue_clr_li)
     ,.deq_v_i(fe_queue_deq_li)
     ,.deq_skip_i(fe_queue_deq_skip_li)
     ,.roll_v_i(fe_queue_roll_li)
     ,.inject_v_i(fe_queue_inject_li)
     ,.suppress_v_i(fe_queue_suppress_li)
     ,.read_v_i(fe_queue_read_li)
     ,.read_skip_i(fe_queue_read_skip_li)

     ,.fe_queue_i(fe_queue_i)
     ,.fe_queue_v_i(fe_queue_v_i)
     ,.fe_queue_ready_and_o(fe_queue_ready_and_o)

     ,.decode_info_i(decode_info_i)
     ,.preissue_pkt_o(preissue_pkt)
     ,.issue_pkt_o(issue_pkt_cast_o)
     );
  rv64_instr_fmatype_s preissue_instr;
  assign preissue_instr = preissue_pkt.instr;

  logic [dword_width_gp-1:0] irf_rs1, irf_rs2;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(2), .zero_x0_p(1), .data_width_p(dword_width_gp))
   int_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(iwb_pkt_cast_i.ird_w_v)
     ,.rd_addr_i(iwb_pkt_cast_i.rd_addr)
     ,.rd_data_i(iwb_pkt_cast_i.rd_data[0+:dword_width_gp])

     ,.rs_r_v_i({preissue_pkt.irs2_v, preissue_pkt.irs1_v})
     ,.rs_addr_i({preissue_instr.rs2_addr, preissue_instr.rs1_addr})
     ,.rs_data_o({irf_rs2, irf_rs1})
     );

  logic [dpath_width_gp-1:0] frf_rs1, frf_rs2, frf_rs3;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(3), .zero_x0_p(0), .data_width_p(dpath_width_gp))
   fp_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(fwb_pkt_cast_i.frd_w_v)
     ,.rd_addr_i(fwb_pkt_cast_i.rd_addr)
     ,.rd_data_i(fwb_pkt_cast_i.rd_data)

     ,.rs_r_v_i({preissue_pkt.frs3_v, preissue_pkt.frs2_v, preissue_pkt.frs1_v})
     ,.rs_addr_i({preissue_instr.rs3_addr, preissue_instr.rs2_addr, preissue_instr.rs1_addr})
     ,.rs_data_o({frf_rs3, frf_rs2, frf_rs1})
     );

  // Prioritization is:
  //   1) ptw_fill_pkt, since there is no backpressure
  //   3) unfreeze request
  //   2) interrupt request
  //   4) finally, fe queue
  wire fe_instr_not_exc_li = fe_queue_read_li &  issue_pkt_cast_o.instr_v;
  wire fe_exc_not_instr_li = fe_queue_read_li & !issue_pkt_cast_o.instr_v;
  wire be_exc_not_instr_li = fe_queue_inject_li;

  wire [vaddr_width_p-1:0] fe_exc_pc_li = issue_pkt_cast_o.pc;
  wire [vaddr_width_p-1:0] fe_exc_vaddr_li = fe_exc_pc_li + (issue_pkt_cast_o.partial ? 2'b10 : 2'b00);
  wire [vaddr_width_p-1:0] be_exc_vaddr_li = ptw_fill_pkt_cast_i.vaddr;
  wire [dpath_width_gp-1:0] be_exc_data_li = ptw_fill_pkt_cast_i.entry;

  wire fe_partial = issue_pkt_cast_o.partial;
  wire be_partial = ptw_fill_pkt_cast_i.v & ptw_fill_pkt_cast_i.partial;

  wire ptw_fill_v  =  ptw_fill_pkt_cast_i.v;
  wire unfreeze_v  = ~ptw_fill_pkt_cast_i.v &  unfreeze_i;
  wire interrupt_v = ~ptw_fill_pkt_cast_i.v & ~unfreeze_i & interrupt_v_i;

  wire ptw_instr_page_fault_v = ptw_fill_v & ptw_fill_pkt_cast_i.instr_page_fault_v;
  wire ptw_load_page_fault_v  = ptw_fill_v & ptw_fill_pkt_cast_i.load_page_fault_v;
  wire ptw_store_page_fault_v = ptw_fill_v & ptw_fill_pkt_cast_i.store_page_fault_v;
  wire ptw_itlb_fill_v        = ptw_fill_v & ptw_fill_pkt_cast_i.itlb_fill_v;
  wire ptw_dtlb_fill_v        = ptw_fill_v & ptw_fill_pkt_cast_i.dtlb_fill_v;

  always_comb
    begin
      // Form dispatch packet
      dispatch_pkt_cast_o = '0;
      dispatch_pkt_cast_o.v          = fe_queue_read_li || be_exc_not_instr_li;
      dispatch_pkt_cast_o.queue_v    = fe_queue_read_li;
      dispatch_pkt_cast_o.instr_v    = fe_instr_not_exc_li;
      dispatch_pkt_cast_o.ispec_v    = ispec_v_i;
      dispatch_pkt_cast_o.pc         = expected_npc_i;
      dispatch_pkt_cast_o.instr      = issue_pkt_cast_o.instr;
      dispatch_pkt_cast_o.compressed = issue_pkt_cast_o.compressed;
      dispatch_pkt_cast_o.partial    = be_exc_not_instr_li ? be_partial : fe_partial;
      // If register injection is critical, can be done after bypass
      dispatch_pkt_cast_o.rs1        = be_exc_not_instr_li ? be_exc_vaddr_li : fe_exc_not_instr_li ? fe_exc_vaddr_li : issue_pkt_cast_o.decode.frs1_r_v ? frf_rs1 : irf_rs1;
      dispatch_pkt_cast_o.rs2        = be_exc_not_instr_li ? be_exc_data_li  : fe_exc_not_instr_li ? '0 : issue_pkt_cast_o.decode.frs2_r_v ? frf_rs2 : irf_rs2;
      dispatch_pkt_cast_o.imm        = (fe_exc_not_instr_li | be_exc_not_instr_li) ? '0 : issue_pkt_cast_o.decode.frs3_r_v ? frf_rs3 : issue_pkt_cast_o.imm;
      dispatch_pkt_cast_o.decode     = (fe_exc_not_instr_li | be_exc_not_instr_li) ? '0 : issue_pkt_cast_o.decode;

      dispatch_pkt_cast_o.exception.instr_page_fault |= be_exc_not_instr_li & ptw_instr_page_fault_v;
      dispatch_pkt_cast_o.exception.load_page_fault  |= be_exc_not_instr_li & ptw_load_page_fault_v;
      dispatch_pkt_cast_o.exception.store_page_fault |= be_exc_not_instr_li & ptw_store_page_fault_v;
      dispatch_pkt_cast_o.exception.itlb_fill        |= be_exc_not_instr_li & ptw_itlb_fill_v;
      dispatch_pkt_cast_o.exception.dtlb_fill        |= be_exc_not_instr_li & ptw_dtlb_fill_v;
      dispatch_pkt_cast_o.exception.unfreeze         |= be_exc_not_instr_li & unfreeze_v;
      dispatch_pkt_cast_o.exception._interrupt       |= be_exc_not_instr_li & interrupt_v;

      dispatch_pkt_cast_o.exception.instr_access_fault |= fe_exc_not_instr_li & issue_pkt_cast_o.instr_access_fault;
      dispatch_pkt_cast_o.exception.instr_page_fault   |= fe_exc_not_instr_li & issue_pkt_cast_o.instr_page_fault;
      dispatch_pkt_cast_o.exception.itlb_miss          |= fe_exc_not_instr_li & issue_pkt_cast_o.itlb_miss;
      dispatch_pkt_cast_o.exception.icache_miss        |= fe_exc_not_instr_li & issue_pkt_cast_o.icache_miss;
      dispatch_pkt_cast_o.exception.illegal_instr      |= fe_exc_not_instr_li & issue_pkt_cast_o.illegal_instr;

      dispatch_pkt_cast_o.exception.ecall_m       |= fe_instr_not_exc_li & issue_pkt_cast_o.ecall_m;
      dispatch_pkt_cast_o.exception.ecall_s       |= fe_instr_not_exc_li & issue_pkt_cast_o.ecall_s;
      dispatch_pkt_cast_o.exception.ecall_u       |= fe_instr_not_exc_li & issue_pkt_cast_o.ecall_u;
      dispatch_pkt_cast_o.exception.ebreak        |= fe_instr_not_exc_li & issue_pkt_cast_o.ebreak;
      dispatch_pkt_cast_o.special.dbreak          |= fe_instr_not_exc_li & issue_pkt_cast_o.dbreak;
      dispatch_pkt_cast_o.special.dret            |= fe_instr_not_exc_li & issue_pkt_cast_o.dret;
      dispatch_pkt_cast_o.special.mret            |= fe_instr_not_exc_li & issue_pkt_cast_o.mret;
      dispatch_pkt_cast_o.special.sret            |= fe_instr_not_exc_li & issue_pkt_cast_o.sret;
      dispatch_pkt_cast_o.special.wfi             |= fe_instr_not_exc_li & issue_pkt_cast_o.wfi;
      dispatch_pkt_cast_o.special.sfence_vma      |= fe_instr_not_exc_li & issue_pkt_cast_o.sfence_vma;
    end

endmodule


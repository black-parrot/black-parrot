/**
 *
 * Name:
 *   bp_be_scheduler.sv
 *
 * Description:
 *   Schedules instruction issue from the FE queue to the Calculator.
 *
 * Notes:
 *   It might make sense to use an enum for RISC-V opcodes rather than `defines.
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_scheduler
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam cfg_bus_width_lp      = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam fe_queue_width_lp     = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp    = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam isd_status_width_lp   = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam wb_pkt_width_lp       = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , output [isd_status_width_lp-1:0]   isd_status_o
   , input [vaddr_width_p-1:0]          expected_npc_i
   , input                              poison_isd_i
   , input                              dispatch_v_i
   , input                              interrupt_v_i
   , input                              suppress_iss_i
   , input                              fpu_en_i

   // Fetch interface
   , input [fe_queue_width_lp-1:0]      fe_queue_i
   , input                              fe_queue_v_i
   , output                             fe_queue_ready_o

   // Dispatch interface
   , output [dispatch_pkt_width_lp-1:0] dispatch_pkt_o

   , input [commit_pkt_width_lp-1:0]    commit_pkt_i
   , input [ptw_fill_pkt_width_lp-1:0]  ptw_fill_pkt_i
   , input [wb_pkt_width_lp-1:0]        iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]        fwb_pkt_i
   );

  // Declare parameterizable structures
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Cast input and output ports
  bp_be_isd_status_s isd_status_cast_o;
  rv64_instr_s       instr;
  bp_be_commit_pkt_s commit_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_wb_pkt_s     iwb_pkt, fwb_pkt;

  bp_fe_queue_s fe_queue_lo;
  logic fe_queue_v_lo, fe_queue_yumi_li;

  assign isd_status_o    = isd_status_cast_o;
  assign instr           = fe_queue_lo.msg.fetch.instr;
  assign ptw_fill_pkt    = ptw_fill_pkt_i;
  assign commit_pkt      = commit_pkt_i;
  assign iwb_pkt         = iwb_pkt_i;
  assign fwb_pkt         = fwb_pkt_i;

  wire fe_queue_clr_li  = suppress_iss_i;
  wire fe_queue_deq_li  = commit_pkt.queue_v & ~commit_pkt.rollback;
  wire fe_queue_roll_li = commit_pkt.rollback;
  bp_be_issue_pkt_s preissue_pkt, issue_pkt;
  bp_be_issue_queue
   #(.bp_params_p(bp_params_p))
   fe_queue_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clr_v_i(fe_queue_clr_li)
     ,.deq_v_i(fe_queue_deq_li)
     ,.roll_v_i(fe_queue_roll_li)

     ,.fe_queue_i(fe_queue_i)
     ,.fe_queue_v_i(fe_queue_v_i)
     ,.fe_queue_ready_o(fe_queue_ready_o)

     ,.fe_queue_o(fe_queue_lo)
     ,.fe_queue_v_o(fe_queue_v_lo)
     ,.fe_queue_yumi_i(fe_queue_yumi_li)

     ,.preissue_pkt_o(preissue_pkt)
     ,.issue_pkt_o(issue_pkt)
     );

  logic [dword_width_gp-1:0] irf_rs1, irf_rs2;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(2), .zero_x0_p(1), .data_width_p(dword_width_gp))
   int_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(iwb_pkt.ird_w_v)
     ,.rd_addr_i(iwb_pkt.rd_addr)
     ,.rd_data_i(iwb_pkt.rd_data[0+:dword_width_gp])

     ,.rs_r_v_i({preissue_pkt.irs2_v, preissue_pkt.irs1_v})
     ,.rs_addr_i({preissue_pkt.rs2_addr, preissue_pkt.rs1_addr})
     ,.rs_data_o({irf_rs2, irf_rs1})
     );

  logic [dpath_width_gp-1:0] frf_rs1, frf_rs2, frf_rs3;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(3), .zero_x0_p(0), .data_width_p(dpath_width_gp))
   fp_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(fwb_pkt.frd_w_v)
     ,.rd_addr_i(fwb_pkt.rd_addr)
     ,.rd_data_i(fwb_pkt.rd_data)

     ,.rs_r_v_i({preissue_pkt.frs3_v, preissue_pkt.frs2_v, preissue_pkt.frs1_v})
     ,.rs_addr_i({preissue_pkt.rs3_addr, preissue_pkt.rs2_addr, preissue_pkt.rs1_addr})
     ,.rs_data_o({frf_rs3, frf_rs2, frf_rs1})
     );

  // Decode the dispatched instruction
  wire fe_exc_not_instr_li = (fe_queue_lo.msg_type == e_fe_exception);
  wire [vaddr_width_p-1:0] fe_exc_vaddr_li = fe_queue_lo.msg.exception.vaddr;

  wire be_exc_not_instr_li = ptw_fill_pkt.instr_page_fault_v
                             | ptw_fill_pkt.load_page_fault_v
                             | ptw_fill_pkt.store_page_fault_v
                             | interrupt_v_i;
  wire [vaddr_width_p-1:0] be_exc_vaddr_li = ptw_fill_pkt.vaddr;

  bp_be_decode_s instr_decoded;
  logic [dword_width_gp-1:0] decoded_imm_lo;
  bp_be_instr_decoder
   #(.bp_params_p(bp_params_p))
   instr_decoder
    (.instr_i(fe_queue_lo.msg.fetch.instr)

     ,.decode_o(instr_decoded)
     ,.imm_o(decoded_imm_lo)

     ,.fpu_en_i(fpu_en_i)
     );

  bp_be_decode_s be_exc_decoded;
  always_comb
    begin
      be_exc_decoded = '0;
      be_exc_decoded.instr_page_fault = ptw_fill_pkt.instr_page_fault_v;
      be_exc_decoded.load_page_fault  = ptw_fill_pkt.load_page_fault_v;
      be_exc_decoded.store_page_fault = ptw_fill_pkt.store_page_fault_v;
      be_exc_decoded._interrupt       = interrupt_v_i;
    end

  bp_be_decode_s fe_exc_decoded;
  always_comb
    begin
      fe_exc_decoded = '0;
      fe_exc_decoded.queue_v            = 1'b1;
      fe_exc_decoded.instr_access_fault = fe_queue_lo.msg.exception.exception_code inside {e_instr_access_fault};
      fe_exc_decoded.instr_page_fault   = fe_queue_lo.msg.exception.exception_code inside {e_instr_page_fault};
      fe_exc_decoded.itlb_miss          = fe_queue_lo.msg.exception.exception_code inside {e_itlb_miss};
      fe_exc_decoded.icache_miss        = fe_queue_lo.msg.exception.exception_code inside {e_icache_miss};
    end

  bp_be_decode_s decoded;
  assign decoded = be_exc_not_instr_li
    ? be_exc_decoded
    : fe_exc_not_instr_li
      ? fe_exc_decoded
      : instr_decoded;

  wire [dword_width_gp-1:0] imm_lo = be_exc_not_instr_li
    ? be_exc_vaddr_li
    : fe_exc_not_instr_li
      ? fe_exc_vaddr_li
      : decoded_imm_lo;

  assign fe_queue_yumi_li = fe_queue_v_lo & dispatch_v_i & ~suppress_iss_i & ~be_exc_not_instr_li;

  bp_be_dispatch_pkt_s dispatch_pkt;
  always_comb
    begin
      // Calculator status ISD stage
      isd_status_cast_o.v        = fe_queue_yumi_li;
      isd_status_cast_o.pc       = fe_queue_lo.msg.fetch.pc;
      isd_status_cast_o.branch_metadata_fwd = fe_queue_lo.msg.fetch.branch_metadata_fwd;
      isd_status_cast_o.fence_v  = fe_queue_v_lo & issue_pkt.fence_v;
      isd_status_cast_o.csr_v    = fe_queue_v_lo & issue_pkt.csr_v;
      isd_status_cast_o.mem_v    = fe_queue_v_lo & issue_pkt.mem_v;
      isd_status_cast_o.long_v   = fe_queue_v_lo & issue_pkt.long_v;
      isd_status_cast_o.irs1_v   = fe_queue_v_lo & issue_pkt.irs1_v;
      isd_status_cast_o.frs1_v   = fe_queue_v_lo & issue_pkt.frs1_v;
      isd_status_cast_o.rs1_addr = instr.t.fmatype.rs1_addr;
      isd_status_cast_o.irs2_v   = fe_queue_v_lo & issue_pkt.irs2_v;
      isd_status_cast_o.frs2_v   = fe_queue_v_lo & issue_pkt.frs2_v;
      isd_status_cast_o.rs2_addr = instr.t.fmatype.rs2_addr;
      isd_status_cast_o.frs3_v   = fe_queue_v_lo & issue_pkt.frs3_v;
      isd_status_cast_o.rs3_addr = instr.t.fmatype.rs3_addr;
      isd_status_cast_o.rd_addr  = instr.t.fmatype.rd_addr;
      isd_status_cast_o.iwb_v    = decoded.irf_w_v;
      isd_status_cast_o.fwb_v    = decoded.frf_w_v;

      // Form dispatch packet
      dispatch_pkt.v        = (fe_queue_yumi_li & ~poison_isd_i) | be_exc_not_instr_li;
      dispatch_pkt.queue_v  = fe_queue_yumi_li;
      dispatch_pkt.pc       = expected_npc_i;
      dispatch_pkt.instr    = instr;
      dispatch_pkt.rs1_fp_v = issue_pkt.frs1_v;
      dispatch_pkt.rs1      = issue_pkt.frs1_v ? frf_rs1 : irf_rs1;
      dispatch_pkt.rs2_fp_v = issue_pkt.frs2_v;
      dispatch_pkt.rs2      = issue_pkt.frs2_v ? frf_rs2 : irf_rs2;
      dispatch_pkt.rs3_fp_v = issue_pkt.frs3_v;
      dispatch_pkt.imm      = issue_pkt.frs3_v ? frf_rs3 : imm_lo;
      dispatch_pkt.decode   = decoded;
    end
  assign dispatch_pkt_o = dispatch_pkt;

endmodule


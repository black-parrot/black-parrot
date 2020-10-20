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

module bp_be_scheduler
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam wb_pkt_width_lp     = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

  , output [isd_status_width_lp-1:0]   isd_status_o
  , input [vaddr_width_p-1:0]          expected_npc_i
  , input                              poison_isd_i
  , input                              dispatch_v_i
  , input                              suppress_iss_i
  , input                              fpu_en_i

  // Fetch interface
  , input [fe_queue_width_lp-1:0]      fe_queue_i
  , input                              fe_queue_v_i
  , output                             fe_queue_ready_o

  // Dispatch interface
  , output [dispatch_pkt_width_lp-1:0] dispatch_pkt_o

  , input [commit_pkt_width_lp-1:0]      commit_pkt_i
  , input [wb_pkt_width_lp-1:0]        iwb_pkt_i
  , input [wb_pkt_width_lp-1:0]        fwb_pkt_i
  );

  wire unused = &{clk_i, reset_i};

  // Declare parameterizable structures
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Cast input and output ports
  bp_be_isd_status_s isd_status;
  rv64_instr_s       instr;
  bp_be_commit_pkt_s   commit_pkt;
  bp_be_wb_pkt_s     iwb_pkt, fwb_pkt;

  bp_fe_queue_s fe_queue_lo;
  logic fe_queue_v_lo, fe_queue_yumi_li;

  assign isd_status_o    = isd_status;
  assign instr           = fe_queue_lo.msg.fetch.instr;
  assign commit_pkt        = commit_pkt_i;
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

  // Interface handshakes
  assign fe_queue_yumi_li = ~suppress_iss_i & fe_queue_v_lo & dispatch_v_i;
  wire issue_v = fe_queue_yumi_li;

  logic [dword_width_p-1:0] irf_rs1, irf_rs2;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(2), .data_width_p(dword_width_p))
   int_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(iwb_pkt.ird_w_v)
     ,.rd_addr_i(iwb_pkt.rd_addr)
     ,.rd_data_i(iwb_pkt.rd_data[0+:dword_width_p])

     ,.rs_r_v_i({preissue_pkt.irs2_v, preissue_pkt.irs1_v})
     ,.rs_addr_i({preissue_pkt.rs2_addr, preissue_pkt.rs1_addr})
     ,.rs_data_o({irf_rs2, irf_rs1})
     );

  logic [dpath_width_p-1:0] frf_rs1, frf_rs2, frf_rs3;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(3), .data_width_p(dpath_width_p))
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
  bp_be_decode_s            decoded;
  logic [dword_width_p-1:0] decoded_imm_lo;
  wire fe_exc_not_instr_li = (fe_queue_lo.msg_type == e_fe_exception);
  bp_be_instr_decoder
   #(.bp_params_p(bp_params_p))
   instr_decoder
     (.fe_exc_not_instr_i(fe_exc_not_instr_li)
     ,.fe_exc_i(fe_queue_lo.msg.exception.exception_code)
     ,.instr_i(fe_queue_lo.msg.fetch.instr)

     ,.decode_o(decoded)
     ,.imm_o(decoded_imm_lo)

     ,.fpu_en_i(fpu_en_i)
     );

  bp_be_dispatch_pkt_s dispatch_pkt;
  always_comb
    begin
      // Calculator status ISD stage
      isd_status.isd_v        = fe_queue_yumi_li;
      isd_status.isd_pc       = fe_queue_lo.msg.fetch.pc;
      isd_status.isd_branch_metadata_fwd = fe_queue_lo.msg.fetch.branch_metadata_fwd;
      isd_status.isd_fence_v  = fe_queue_v_lo & issue_pkt.fence_v;
      isd_status.isd_csr_v    = fe_queue_v_lo & issue_pkt.csr_v;
      isd_status.isd_mem_v    = fe_queue_v_lo & issue_pkt.mem_v;
      isd_status.isd_long_v   = fe_queue_v_lo & issue_pkt.long_v;
      isd_status.isd_irs1_v   = fe_queue_v_lo & issue_pkt.irs1_v;
      isd_status.isd_frs1_v   = fe_queue_v_lo & issue_pkt.frs1_v;
      isd_status.isd_rs1_addr = instr.t.fmatype.rs1_addr;
      isd_status.isd_irs2_v   = fe_queue_v_lo & issue_pkt.irs2_v;
      isd_status.isd_frs2_v   = fe_queue_v_lo & issue_pkt.frs2_v;
      isd_status.isd_rs2_addr = instr.t.fmatype.rs2_addr;
      isd_status.isd_frs3_v   = fe_queue_v_lo & issue_pkt.frs3_v;
      isd_status.isd_rs3_addr = instr.t.fmatype.rs3_addr;

      // Form dispatch packet
      dispatch_pkt.v        = fe_queue_yumi_li;
      dispatch_pkt.poison   = (poison_isd_i | ~dispatch_pkt.v);
      dispatch_pkt.pc       = expected_npc_i;
      dispatch_pkt.instr    = instr;
      dispatch_pkt.rs1_fp_v = issue_pkt.frs1_v;
      dispatch_pkt.rs1      = issue_pkt.frs1_v ? frf_rs1 : irf_rs1;
      dispatch_pkt.rs2_fp_v = issue_pkt.frs2_v;
      dispatch_pkt.rs2      = issue_pkt.frs2_v ? frf_rs2 : irf_rs2;
      dispatch_pkt.rs3_fp_v = issue_pkt.frs3_v;
      dispatch_pkt.imm      = issue_pkt.frs3_v ? frf_rs3 : decoded_imm_lo;
      dispatch_pkt.decode   = decoded;
    end
  assign dispatch_pkt_o = dispatch_pkt;

endmodule


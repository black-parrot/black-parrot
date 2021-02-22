/**
 *
 * Name:
 *   bp_be_pipe_sys.v
 *
 * Description:
 *
 * Notes:
 *
 */
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_sys
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam csr_cmd_width_lp       = $bits(bp_be_csr_cmd_s)
   // Generated parameters
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam exception_width_lp    = $bits(bp_be_exception_s)
   , localparam special_width_lp      = $bits(bp_be_special_s)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam decode_info_width_lp  = `bp_be_decode_info_width
   , localparam trans_info_width_lp   = `bp_be_trans_info_width(ptag_width_p)
   , localparam wb_pkt_width_lp       = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i

   , input [dispatch_pkt_width_lp-1:0]    reservation_i
   , input                                flush_i

   , input                                commit_v_i
   , input                                commit_queue_v_i
   , input [exception_width_lp-1:0]       exception_i
   , input [special_width_lp-1:0]         special_i

   , input [ptw_fill_pkt_width_lp-1:0]    ptw_fill_pkt_i

   , output logic [dpath_width_gp-1:0]    data_o
   , output logic                         satp_o
   , output logic                         illegal_instr_o
   , output logic                         v_o

   , input [wb_pkt_width_lp-1:0]          iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]          fwb_pkt_i
   , output [commit_pkt_width_lp-1:0]     commit_pkt_o

   , input                                timer_irq_i
   , input                                software_irq_i
   , input                                external_irq_i
   , output logic                         irq_pending_o
   , output logic                         irq_waiting_o
   , input                                interrupt_v_i

   , output [decode_info_width_lp-1:0]    decode_info_o
   , output [trans_info_width_lp-1:0]     trans_info_o
   , output rv64_frm_e                    frm_dyn_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  bp_be_csr_cmd_s csr_cmd_li, csr_cmd_r;
  rv64_instr_s instr;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_commit_pkt_s commit_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_decode_info_s decode_info;
  bp_be_trans_info_s trans_info;

  assign ptw_fill_pkt = ptw_fill_pkt_i;
  assign commit_pkt_o = commit_pkt;
  assign iwb_pkt = iwb_pkt_i;
  assign fwb_pkt = fwb_pkt_i;
  assign decode_info_o = decode_info;
  assign trans_info_o = trans_info;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr  = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_gp-1:0] rs1 = reservation.rs1[0+:dword_width_gp];
  wire [dword_width_gp-1:0] rs2 = reservation.rs2[0+:dword_width_gp];
  wire [dword_width_gp-1:0] imm = reservation.imm[0+:dword_width_gp];

  wire csr_imm_op = decode.fu_op inside {e_csrrwi, e_csrrsi, e_csrrci};

  wire csr_cmd_v_li = reservation.v & (decode.csr_w_v | decode.csr_r_v);
  always_comb
    begin
      csr_cmd_li.csr_op   = decode.fu_op;
      csr_cmd_li.csr_addr = instr.t.itype.imm12;
      csr_cmd_li.data     = csr_imm_op ? imm : rs1;
    end

  logic [vaddr_width_p-1:0] commit_npc_r, commit_pc_r;
  logic [vaddr_width_p-1:0] commit_nvaddr_r, commit_vaddr_r;
  logic [instr_width_gp-1:0] commit_ninstr_r, commit_instr_r;

  bp_be_exception_s exception_li;
  bp_be_special_s special_li;
  always_comb
    if (commit_v_i)
      begin
        exception_li = exception_i;
        special_li = special_i;
      end
    else
      begin
        exception_li = '0;
        exception_li.instr_page_fault = ptw_fill_pkt.instr_page_fault_v;
        exception_li.load_page_fault = ptw_fill_pkt.load_page_fault_v;
        exception_li.store_page_fault = ptw_fill_pkt.store_page_fault_v;
        special_li = '0;
      end

  wire ptw_page_fault_v  = ptw_fill_pkt.instr_page_fault_v | ptw_fill_pkt.load_page_fault_v | ptw_fill_pkt.store_page_fault_v;
  wire exception_v_li = ptw_page_fault_v | commit_v_i;
  wire exception_queue_v_li = commit_queue_v_i;
  wire [vaddr_width_p-1:0] exception_npc_li = commit_npc_r;
  wire [vaddr_width_p-1:0] exception_vaddr_li = ptw_page_fault_v ? ptw_fill_pkt.vaddr : commit_vaddr_r;
  wire [instr_width_gp-1:0] exception_instr_li = commit_instr_r;

  logic [dword_width_gp-1:0] csr_data_lo;
  bp_be_csr
   #(.bp_params_p(bp_params_p))
    csr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.csr_cmd_i(csr_cmd_li)
     ,.csr_cmd_v_i(csr_cmd_v_li)
     ,.csr_data_o(csr_data_lo)
     ,.csr_illegal_instr_o(illegal_instr_o)
     ,.csr_satp_o(satp_o)

     ,.fflags_acc_i(({5{iwb_pkt.fflags_w_v}} & iwb_pkt.fflags) | ({5{fwb_pkt.fflags_w_v}} & fwb_pkt.fflags))
     ,.frf_w_v_i(fwb_pkt.frd_w_v)

     ,.exception_v_i(exception_v_li)
     ,.exception_queue_v_i(exception_queue_v_li)
     ,.exception_npc_i(exception_npc_li)
     ,.exception_vaddr_i(exception_vaddr_li)
     ,.exception_instr_i(exception_instr_li)
     ,.exception_i(exception_li)
     ,.special_i(special_li)
     ,.ptw_fill_pkt_i(ptw_fill_pkt)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     ,.irq_pending_o(irq_pending_o)
     ,.irq_waiting_o(irq_waiting_o)
     ,.interrupt_v_i(interrupt_v_i)

     ,.commit_pkt_o(commit_pkt)
     ,.decode_info_o(decode_info)
     ,.trans_info_o(trans_info)
     ,.frm_dyn_o(frm_dyn_o)
     );
  wire sys_v_li = reservation.v & reservation.decode.pipe_sys_v;
  assign data_o = csr_data_lo;
  assign v_o    = sys_v_li;

  always_ff @(posedge clk_i)
    begin
      commit_npc_r <= reservation.pc;
      commit_pc_r  <= commit_npc_r;

      commit_nvaddr_r <= rs1 + imm;
      commit_vaddr_r  <= commit_nvaddr_r;

      commit_ninstr_r <= reservation.instr;
      commit_instr_r  <= commit_ninstr_r;
    end

endmodule


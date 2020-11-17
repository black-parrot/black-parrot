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

   , output logic                         illegal_instr_o
   , output logic                         satp_v_o
   , output logic                         sfence_v_o
   , output logic                         sret_v_o
   , output logic                         mret_v_o
   , output logic                         dret_v_o
   , output logic                         ecall_u_v_o
   , output logic                         ecall_s_v_o
   , output logic                         ecall_m_v_o
   , output logic                         ebreak_v_o
   , output logic                         dbreak_v_o
   , output logic [dpath_width_gp-1:0]    data_o
   , output logic                         v_o

   , input [wb_pkt_width_lp-1:0]          iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]          fwb_pkt_i
   , output [commit_pkt_width_lp-1:0]     commit_pkt_o

   , input                                timer_irq_i
   , input                                software_irq_i
   , input                                external_irq_i
   , output logic                         irq_pending_o

   , output [trans_info_width_lp-1:0]     trans_info_o
   , output rv64_frm_e                    frm_dyn_o
   , output                               fpu_en_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  bp_be_csr_cmd_s csr_cmd_li;
  rv64_instr_s instr;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_commit_pkt_s commit_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_trans_info_s trans_info;

  assign ptw_fill_pkt = ptw_fill_pkt_i;
  assign commit_pkt_o = commit_pkt;
  assign iwb_pkt = iwb_pkt_i;
  assign fwb_pkt = fwb_pkt_i;
  assign trans_info_o = trans_info;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr  = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_gp-1:0] rs1 = reservation.rs1[0+:dword_width_gp];
  wire [dword_width_gp-1:0] rs2 = reservation.rs2[0+:dword_width_gp];
  wire [dword_width_gp-1:0] imm = reservation.imm[0+:dword_width_gp];

  wire csr_imm_op = decode.fu_op inside {e_csrrwi, e_csrrsi, e_csrrci};
  wire [dword_width_gp-1:0] csr_data = csr_imm_op ? dword_width_gp'(instr.t.rtype.rs1_addr) : rs1;

  wire csr_cmd_v_li = reservation.v & decode.pipe_sys_v;
  assign csr_cmd_li = '{csr_op   : decode.fu_op
                        ,csr_addr: instr.t.itype.imm12
                        ,data    : csr_data
                        };

  logic [vaddr_width_p-1:0] commit_npc_r, commit_pc_r;
  logic [vaddr_width_p-1:0] commit_nvaddr_r, commit_vaddr_r;
  logic [instr_width_gp-1:0] commit_ninstr_r, commit_instr_r;
  always_ff @(posedge clk_i)
    begin
      commit_npc_r <= reservation.pc;
      commit_pc_r  <= commit_npc_r;

      // The commit virtual address, which is rs1+imm for all actual instructions
      //   and imm for out-of-band exceptions and interrupts
      commit_nvaddr_r <= (reservation.decode.pipe_mem_early_v | reservation.decode.pipe_mem_final_v)
                         ? (rs1 + imm)
                         : imm;
      commit_vaddr_r  <= commit_nvaddr_r;

      commit_ninstr_r <= reservation.instr;
      commit_instr_r  <= commit_ninstr_r;
    end

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
     ,.csr_satp_v_o(satp_v_o)
     ,.csr_sfence_v_o(sfence_v_o)
     ,.csr_sret_v_o(sret_v_o)
     ,.csr_mret_v_o(mret_v_o)
     ,.csr_dret_v_o(dret_v_o)
     ,.csr_ecall_u_v_o(ecall_u_v_o)
     ,.csr_ecall_s_v_o(ecall_s_v_o)
     ,.csr_ecall_m_v_o(ecall_m_v_o)
     ,.csr_ebreak_v_o(ebreak_v_o)
     ,.csr_dbreak_v_o(dbreak_v_o)

     ,.fflags_acc_i(({5{iwb_pkt.fflags_w_v}} & iwb_pkt.fflags) | ({5{fwb_pkt.fflags_w_v}} & fwb_pkt.fflags))
     ,.frf_w_v_i(fwb_pkt.frd_w_v)

     ,.exception_v_i(commit_v_i)
     ,.exception_queue_v_i(commit_queue_v_i)
     ,.exception_npc_i(commit_npc_r)
     ,.exception_vaddr_i(commit_vaddr_r)
     ,.exception_instr_i(commit_instr_r)
     ,.exception_i(exception_i)
     ,.special_i(special_i)
     ,.ptw_fill_pkt_i(ptw_fill_pkt_i)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     ,.irq_pending_o(irq_pending_o)

     ,.commit_pkt_o(commit_pkt)
     ,.trans_info_o(trans_info)
     ,.frm_dyn_o(frm_dyn_o)
     ,.fpu_en_o(fpu_en_o)
     );

  assign data_o = csr_data_lo;

  wire sys_v_li = reservation.v & reservation.decode.pipe_sys_v;
  assign v_o = sys_v_li;

endmodule


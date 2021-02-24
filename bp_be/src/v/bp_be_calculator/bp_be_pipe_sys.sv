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
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam decode_info_width_lp  = `bp_be_decode_info_width
   , localparam trans_info_width_lp   = `bp_be_trans_info_width(ptag_width_p)
   , localparam wb_pkt_width_lp       = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cfg_bus_width_lp-1:0]            cfg_bus_i

   , input [dispatch_pkt_width_lp-1:0]       reservation_i
   , input                                   flush_i

   , input                                   retire_v_i
   , input                                   retire_queue_v_i
   , input [dpath_width_gp-1:0]              retire_data_i
   , input [exception_width_lp-1:0]          retire_exception_i
   , input [special_width_lp-1:0]            retire_special_i

   , output logic [dpath_width_gp-1:0]       data_o
   , output logic                            satp_o
   , output logic                            illegal_instr_o
   , output logic                            v_o

   , input [wb_pkt_width_lp-1:0]             iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]             fwb_pkt_i
   , output logic [commit_pkt_width_lp-1:0]  commit_pkt_o

   , input                                   timer_irq_i
   , input                                   software_irq_i
   , input                                   external_irq_i
   , output logic                            irq_pending_o
   , output logic                            irq_waiting_o

   , output logic [decode_info_width_lp-1:0] decode_info_o
   , output logic [trans_info_width_lp-1:0]  trans_info_o
   , output rv64_frm_e                       frm_dyn_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  bp_be_csr_cmd_s csr_cmd_li;
  rv64_instr_s instr;
  bp_be_commit_pkt_s commit_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_decode_info_s decode_info;
  bp_be_trans_info_s trans_info;

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
      csr_cmd_li.csr_op   = bp_be_csr_fu_op_e'(decode.fu_op);
      csr_cmd_li.csr_addr = instr.t.itype.imm12;
      csr_cmd_li.data     = csr_imm_op ? imm : rs1;
    end

  bp_be_retire_pkt_s retire_pkt;
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

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     ,.irq_pending_o(irq_pending_o)
     ,.irq_waiting_o(irq_waiting_o)

     ,.retire_pkt_i(retire_pkt)
     ,.commit_pkt_o(commit_pkt)
     ,.decode_info_o(decode_info)
     ,.trans_info_o(trans_info)
     ,.frm_dyn_o(frm_dyn_o)
     );
  wire sys_v_li = reservation.v & reservation.decode.pipe_sys_v;
  assign data_o = csr_data_lo;
  assign v_o    = sys_v_li;

  logic [vaddr_width_p-1:0] retire_npc_r, retire_pc_r;
  logic [vaddr_width_p-1:0] retire_nvaddr_r, retire_vaddr_r;
  logic [instr_width_gp-1:0] retire_ninstr_r, retire_instr_r;
  always_ff @(posedge clk_i)
    begin
      retire_npc_r <= reservation.pc;
      retire_pc_r  <= retire_npc_r;

      retire_nvaddr_r <= rs1+imm;
      retire_vaddr_r  <= retire_nvaddr_r;

      retire_ninstr_r <= reservation.instr;
      retire_instr_r  <= retire_ninstr_r;
    end

  wire instret_li = retire_v_i & ~|retire_exception_i;
  assign retire_pkt =
    '{v          : retire_v_i
      ,queue_v   : retire_queue_v_i
      ,instret   : retire_v_i & ~|retire_exception_i
      ,npc       : retire_npc_r
      ,vaddr     : retire_vaddr_r
      ,data      : retire_data_i
      ,instr     : retire_instr_r
      // Could do a preemptive onehot decode here
      ,exception : retire_v_i ? retire_exception_i : '0
      ,special   : instret_li ? retire_special_i   : '0
      };

endmodule


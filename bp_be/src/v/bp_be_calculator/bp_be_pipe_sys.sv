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

   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   // Generated parameters
   , localparam reservation_width_lp = `bp_be_reservation_width(vaddr_width_p)
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

   , input [reservation_width_lp-1:0]        reservation_i
   , input                                   flush_i

   , input                                   retire_v_i
   , input                                   retire_queue_v_i
   , input [dpath_width_gp-1:0]              retire_data_i
   , input [exception_width_lp-1:0]          retire_exception_i
   , input [special_width_lp-1:0]            retire_special_i

   , output logic [dpath_width_gp-1:0]       data_o
   , output logic                            v_o
   , output logic                            illegal_instr_o

   , input [wb_pkt_width_lp-1:0]             iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]             fwb_pkt_i
   , output logic [commit_pkt_width_lp-1:0]  commit_pkt_o

   , input                                   debug_irq_i
   , input                                   timer_irq_i
   , input                                   software_irq_i
   , input                                   m_external_irq_i
   , input                                   s_external_irq_i
   , output logic                            irq_pending_o
   , output logic                            irq_waiting_o

   , output logic [decode_info_width_lp-1:0] decode_info_o
   , output logic [trans_info_width_lp-1:0]  trans_info_o
   , output rv64_frm_e                       frm_dyn_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_be_reservation_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;
  `bp_cast_i(bp_be_wb_pkt_s, iwb_pkt);
  `bp_cast_i(bp_be_wb_pkt_s, fwb_pkt);
  `bp_cast_o(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_o(bp_be_decode_info_s, decode_info);
  `bp_cast_o(bp_be_trans_info_s, trans_info);

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr  = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc;
  wire [dword_width_gp-1:0] rs1 = reservation.isrc1;
  wire [dword_width_gp-1:0] rs2 = reservation.isrc2;
  wire [dword_width_gp-1:0] imm = reservation.isrc3;

  wire csr_v_li = reservation.decode.csr_r_v | reservation.decode.csr_w_v;
  wire [rv64_csr_addr_width_gp-1:0] csr_addr_li = instr.t.itype.imm12;

  bp_be_retire_pkt_s retire_pkt;
  logic [dword_width_gp-1:0] csr_data_lo;
  wire [4:0] fflags_acc_li = iwb_pkt_cast_i.fflags | fwb_pkt_cast_i.fflags;
  bp_be_csr
   #(.bp_params_p(bp_params_p))
    csr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.csr_r_v_i(csr_v_li)
     ,.csr_r_addr_i(csr_addr_li)
     ,.csr_r_data_o(csr_data_lo)
     ,.csr_r_illegal_o(illegal_instr_o)

     ,.fflags_acc_i(fflags_acc_li)
     ,.frf_w_v_i(fwb_pkt_cast_i.frd_w_v)

     ,.debug_irq_i(debug_irq_i)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     ,.irq_pending_o(irq_pending_o)
     ,.irq_waiting_o(irq_waiting_o)

     ,.retire_pkt_i(retire_pkt)
     ,.commit_pkt_o(commit_pkt_cast_o)
     ,.decode_info_o(decode_info_cast_o)
     ,.trans_info_o(trans_info_cast_o)
     ,.frm_dyn_o(frm_dyn_o)
     );

  logic [vaddr_width_p-1:0] retire_npc_r;
  logic [dword_width_gp-1:0] retire_nvaddr_r, retire_vaddr_r;
  logic [dword_width_gp-1:0] retire_ndata_r, retire_data_r;
  logic [fetch_ptr_gp-1:0] retire_nsize_r, retire_size_r;
  logic [fetch_ptr_gp-1:0] retire_ncount_r, retire_count_r;
  rv64_instr_s retire_ninstr_r, retire_instr_r;
  logic retire_niscore_r, retire_iscore_r;
  logic retire_nfscore_r, retire_fscore_r;
  logic retire_nspec_w_r, retire_spec_w_r;
  always_ff @(posedge clk_i)
    begin
      retire_npc_r <= reservation.pc;

      retire_nvaddr_r <= rs1+imm;
      retire_vaddr_r  <= retire_nvaddr_r;

      retire_ndata_r <= rs2;
      retire_data_r  <= retire_ndata_r;

      retire_nsize_r <= reservation.size;
      retire_size_r <= retire_nsize_r;

      retire_ncount_r <= reservation.count;
      retire_count_r <= retire_ncount_r;

      retire_ninstr_r <= reservation.instr;
      retire_instr_r  <= retire_ninstr_r;

      retire_niscore_r <= reservation.decode.score_v & reservation.decode.irf_w_v;
      retire_iscore_r  <= retire_niscore_r;

      retire_nfscore_r <= reservation.decode.score_v & reservation.decode.frf_w_v;
      retire_fscore_r  <= retire_nfscore_r;

      retire_nspec_w_r <= reservation.decode.score_v & reservation.decode.spec_w_v;
      retire_spec_w_r  <= retire_nspec_w_r;
    end

  // Compute input CSR data
  logic [dword_width_gp-1:0] retire_data_li;
  wire [dword_width_gp-1:0] retire_imm_li = retire_instr_r.t.fmatype.rs1_addr;
  always_comb
    unique casez ({retire_queue_v_i, retire_instr_r})
      {1'b1, `RV64_CSRRSI}: retire_data_li =  retire_imm_li | retire_data_i;
      {1'b1, `RV64_CSRRCI}: retire_data_li = ~retire_imm_li & retire_data_i;
      {1'b1, `RV64_CSRRWI}: retire_data_li =  retire_imm_li;

      {1'b1, `RV64_CSRRS }: retire_data_li =  retire_vaddr_r | retire_data_i;
      {1'b1, `RV64_CSRRC }: retire_data_li = ~retire_vaddr_r & retire_data_i;
      {1'b1, `RV64_CSRRW }: retire_data_li =  retire_vaddr_r;
      default             : retire_data_li = retire_data_i;
    endcase

  wire instret_li = retire_v_i & retire_queue_v_i & ~|retire_exception_i;
  wire iscore_li =
    (~retire_spec_w_r & retire_iscore_r) | (retire_spec_w_r & retire_iscore_r & |retire_special_i);
  wire fscore_li =
    (~retire_spec_w_r & retire_fscore_r) | (retire_spec_w_r & retire_fscore_r & |retire_special_i);
  assign retire_pkt =
    '{v            : retire_v_i
      ,queue_v     : retire_queue_v_i
      ,instret     : instret_li
      ,size        : retire_size_r
      ,count       : retire_count_r
      ,npc         : retire_npc_r
      ,vaddr       : retire_vaddr_r
      ,data        : retire_data_li
      ,instr       : retire_instr_r
      ,exception   : retire_v_i ? retire_exception_i : '0
      ,special     : instret_li ? retire_special_i   : '0
      ,iscore      : instret_li ? iscore_li : '0
      ,fscore      : instret_li ? fscore_li : '0
      };

  assign v_o = csr_v_li;
  assign data_o = csr_data_lo;

endmodule


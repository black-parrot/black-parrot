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
   , localparam ptw_miss_pkt_width_lp = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam trans_info_width_lp   = `bp_be_trans_info_width(ptag_width_p)
   , localparam wb_pkt_width_lp       = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i

   , input [dispatch_pkt_width_lp-1:0]    reservation_i
   , input                                flush_i

   , output                               ready_o
   , input                                ptw_busy_i

   , input                                commit_v_i
   , input                                commit_queue_v_i
   , input [exception_width_lp-1:0]       exception_i

   , output [ptw_miss_pkt_width_lp-1:0]   ptw_miss_pkt_o
   , input [ptw_fill_pkt_width_lp-1:0]    ptw_fill_pkt_i

   , output logic                         miss_v_o
   , output logic                         exc_v_o
   , output logic [dpath_width_gp-1:0]     data_o
   , output logic                         v_o

   , input [wb_pkt_width_lp-1:0]          iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]          fwb_pkt_i
   , output [commit_pkt_width_lp-1:0]     commit_pkt_o

   , input                                timer_irq_i
   , input                                software_irq_i
   , input                                external_irq_i

   , output [trans_info_width_lp-1:0]     trans_info_o
   , output rv64_frm_e                    frm_dyn_o
   , output                               fpu_en_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  bp_be_csr_cmd_s csr_cmd_li, csr_cmd_r;
  rv64_instr_s instr;
  bp_be_ptw_miss_pkt_s ptw_miss_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_commit_pkt_s commit_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_trans_info_s trans_info;

  assign ptw_miss_pkt_o = ptw_miss_pkt;
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

  always_comb
    begin
      csr_cmd_li.csr_op   = decode.fu_op;
      csr_cmd_li.csr_addr = instr.t.itype.imm12;
      csr_cmd_li.data     = csr_imm_op ? imm : rs1;
    end

  logic csr_cmd_v_lo;
  bsg_shift_reg
   #(.width_p($bits(bp_be_csr_cmd_s))
     ,.stages_p(2)
     )
   csr_shift_reg
    (.clk(clk_i)
     ,.reset_i(reset_i)

     ,.valid_i(decode.csr_v)
     ,.data_i(csr_cmd_li)

     ,.valid_o(csr_cmd_v_lo)
     ,.data_o(csr_cmd_r)
     );

  logic [vaddr_width_p-1:0] commit_npc_r, commit_pc_r;
  logic [vaddr_width_p-1:0] commit_nvaddr_r, commit_vaddr_r;
  logic [instr_width_gp-1:0] commit_ninstr_r, commit_instr_r;

  bp_be_exception_s exception_li;
  always_comb
    if (ptw_fill_pkt.instr_page_fault_v)
      begin
        exception_li = '{instr_page_fault: 1'b1, default: '0};
      end
    else if (ptw_fill_pkt.store_page_fault_v)
      begin
        exception_li = '{store_page_fault: 1'b1, default: '0};
      end
    else if (ptw_fill_pkt.load_page_fault_v)
      begin
        exception_li = '{load_page_fault: 1'b1, default: '0};
      end
    else if (commit_v_i)
      begin
        exception_li = exception_i;
      end
    else
      begin
        exception_li = '0;
      end

  always_comb
    begin
      ptw_miss_pkt.instr_miss_v = commit_v_i & exception_li.itlb_miss;
      ptw_miss_pkt.load_miss_v  = commit_v_i & exception_li.dtlb_load_miss;
      ptw_miss_pkt.store_miss_v = commit_v_i & exception_li.dtlb_store_miss;
      ptw_miss_pkt.vaddr        = exception_li.itlb_miss ? commit_pc_r : commit_vaddr_r;
    end

  wire ptw_page_fault_v  = ptw_fill_pkt.instr_page_fault_v | ptw_fill_pkt.load_page_fault_v | ptw_fill_pkt.store_page_fault_v;
  wire exception_v_li = ptw_page_fault_v | commit_v_i;
  wire exception_queue_v_li = commit_queue_v_i;
  wire [vaddr_width_p-1:0] exception_npc_li = commit_npc_r;
  wire [vaddr_width_p-1:0] exception_vaddr_li = ptw_page_fault_v ? ptw_fill_pkt.vaddr : commit_vaddr_r;
  wire [instr_width_gp-1:0] exception_instr_li = commit_instr_r;

  logic [dword_width_gp-1:0] csr_data_lo;
  logic interrupt_ready_lo, interrupt_v_li;
  bp_be_csr
   #(.bp_params_p(bp_params_p))
    csr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.csr_cmd_i(csr_cmd_r)
     ,.csr_cmd_v_i(csr_cmd_v_lo & commit_v_i)
     ,.csr_data_o(csr_data_lo)

     ,.fflags_acc_i(({5{iwb_pkt.fflags_w_v}} & iwb_pkt.fflags) | ({5{fwb_pkt.fflags_w_v}} & fwb_pkt.fflags))
     ,.frf_w_v_i(fwb_pkt.frd_w_v)

     ,.exception_v_i(exception_v_li)
     ,.exception_queue_v_i(exception_queue_v_li)
     ,.exception_npc_i(exception_npc_li)
     ,.exception_vaddr_i(exception_vaddr_li)
     ,.exception_instr_i(exception_instr_li)
     ,.exception_i(exception_li)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     ,.interrupt_ready_o(interrupt_ready_lo)
     ,.interrupt_v_i(interrupt_v_li)

     ,.commit_pkt_o(commit_pkt)
     ,.trans_info_o(trans_info)
     ,.frm_dyn_o(frm_dyn_o)
     ,.fpu_en_o(fpu_en_o)
     );

  assign interrupt_v_li   = interrupt_ready_lo & ~ptw_busy_i & ~commit_v_i;

  always_ff @(posedge clk_i)
    begin
      commit_npc_r <= reservation.pc;
      commit_pc_r  <= commit_npc_r;

      commit_nvaddr_r <= rs1 + imm;
      commit_vaddr_r  <= commit_nvaddr_r;

      commit_ninstr_r <= reservation.instr;
      commit_instr_r  <= commit_ninstr_r;
    end

  assign ready_o          = ~interrupt_ready_lo;
  assign data_o           = csr_data_lo;
  assign exc_v_o          = commit_pkt.exception;
  assign miss_v_o         = commit_pkt.rollback;

  wire sys_v_li = reservation.v & ~reservation.poison & reservation.decode.pipe_sys_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   sys_chain
    (.clk_i(clk_i)

     ,.data_i(sys_v_li)
     ,.data_o(v_o)
     );

endmodule


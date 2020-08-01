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
module bp_be_pipe_sys
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam csr_cmd_width_lp       = `bp_be_csr_cmd_width
   // Generated parameters
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam exception_width_lp    = `bp_be_exception_width
   , localparam ptw_miss_pkt_width_lp = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p)
   , localparam commit_pkt_width_lp   = `bp_be_commit_pkt_width(vaddr_width_p)
   , localparam trap_pkt_width_lp     = `bp_be_trap_pkt_width(vaddr_width_p)
   , localparam trans_info_width_lp   = `bp_be_trans_info_width(ptag_width_p)
   , localparam wb_pkt_width_lp       = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i

   , input [dispatch_pkt_width_lp-1:0]    reservation_i

   , input                                kill_ex1_i
   , input                                kill_ex2_i
   , input                                kill_ex3_i

   , input [exception_width_lp-1:0]       exception_i
   , input [vaddr_width_p-1:0]            exception_pc_i
   , input [vaddr_width_p-1:0]            exception_vaddr_i

   , output [ptw_miss_pkt_width_lp-1:0]   ptw_miss_pkt_o
   , input [ptw_fill_pkt_width_lp-1:0]    ptw_fill_pkt_i

   , output logic                         miss_v_o
   , output logic                         exc_v_o
   , output logic [dpath_width_p-1:0]     data_o

   , input [wb_pkt_width_lp-1:0]          iwb_pkt_i
   , input [wb_pkt_width_lp-1:0]          fwb_pkt_i
   , input [commit_pkt_width_lp-1:0]      commit_pkt_i
   , output [trap_pkt_width_lp-1:0]       trap_pkt_o

   , input                                interrupt_v_i
   , output                               interrupt_ready_o
   , input                                timer_irq_i
   , input                                software_irq_i
   , input                                external_irq_i

   , output [trans_info_width_lp-1:0]     trans_info_o
   , output rv64_frm_e                    frm_dyn_o
   , output                               fpu_en_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_mem_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p/8)

  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  bp_be_csr_cmd_s csr_cmd_li, csr_cmd_r, csr_cmd_lo;
  rv64_instr_s instr;
  bp_be_ptw_miss_pkt_s ptw_miss_pkt;
  bp_be_ptw_fill_pkt_s ptw_fill_pkt;
  bp_be_commit_pkt_s commit_pkt;
  bp_be_trap_pkt_s trap_pkt;
  bp_be_wb_pkt_s iwb_pkt, fwb_pkt;
  bp_be_trans_info_s trans_info;

  assign ptw_miss_pkt_o = ptw_miss_pkt;
  assign ptw_fill_pkt = ptw_fill_pkt_i;
  assign commit_pkt = commit_pkt_i;
  assign trap_pkt_o = trap_pkt;
  assign iwb_pkt = iwb_pkt_i;
  assign fwb_pkt = fwb_pkt_i;
  assign trans_info_o = trans_info;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr  = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_p-1:0] rs1 = reservation.rs1[0+:dword_width_p];
  wire [dword_width_p-1:0] rs2 = reservation.rs2[0+:dword_width_p];
  wire [dword_width_p-1:0] imm = reservation.imm[0+:dword_width_p];

  wire csr_imm_op = decode.fu_op inside {e_csrrwi, e_csrrsi, e_csrrci};

  always_comb
    begin
      csr_cmd_li.csr_op   = decode.fu_op;
      csr_cmd_li.csr_addr = instr.t.itype.imm12;
      csr_cmd_li.data     = csr_imm_op ? imm : rs1;
      csr_cmd_li.exc      = '0;
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

  // Track if an incoming tlb miss is store or load
  logic is_store_r;
  bsg_dff_chain
   #(.width_p(1)
     ,.num_stages_p(2)
     )
   store_reg
    (.clk_i(clk_i)

     ,.data_i(decode.dcache_w_v)
     ,.data_o(is_store_r)
     );

  always_comb
    begin
      ptw_miss_pkt.instr_miss_v = ~kill_ex3_i & csr_cmd_lo.exc.itlb_miss;
      ptw_miss_pkt.load_miss_v = ~kill_ex3_i & csr_cmd_lo.exc.dtlb_miss & ~is_store_r;
      ptw_miss_pkt.store_miss_v = ~kill_ex3_i & csr_cmd_lo.exc.dtlb_miss & is_store_r;
      ptw_miss_pkt.pc = exception_pc_i;
      ptw_miss_pkt.vaddr = csr_cmd_lo.exc.itlb_miss ? exception_pc_i : exception_vaddr_i;
    end

  always_comb
    begin
      csr_cmd_lo = csr_cmd_r;

      if (ptw_fill_pkt.instr_page_fault_v)
        begin
          csr_cmd_lo.exc.instr_page_fault = 1'b1;
        end
      else if (ptw_fill_pkt.store_page_fault_v)
        begin
          csr_cmd_lo.exc.store_page_fault = 1'b1;
        end
      else if (ptw_fill_pkt.load_page_fault_v)
        begin
          csr_cmd_lo.exc.load_page_fault = 1'b1;
        end
      else
        begin
          // Override data width vaddr for dtlb fill
          // Kill exception on ex3
          csr_cmd_lo.exc = kill_ex3_i ? '0 : exception_i;
          csr_cmd_lo.data = csr_cmd_lo.data;
        end
    end

  wire ptw_page_fault_v  = ptw_fill_pkt.instr_page_fault_v | ptw_fill_pkt.load_page_fault_v | ptw_fill_pkt.store_page_fault_v;
  wire exception_v_li = ptw_page_fault_v | commit_pkt.v;
  wire [vaddr_width_p-1:0] exception_pc_li = ptw_page_fault_v ? ptw_fill_pkt.pc : commit_pkt.pc;
  wire [vaddr_width_p-1:0] exception_npc_li = ptw_page_fault_v ? '0 : commit_pkt.npc;
  wire [vaddr_width_p-1:0] exception_vaddr_li = ptw_page_fault_v ? ptw_fill_pkt.vaddr : exception_vaddr_i;
  wire [instr_width_p-1:0] exception_instr_li = commit_pkt.instr;

  logic [dword_width_p-1:0] csr_data_lo;
  bp_be_csr
   #(.bp_params_p(bp_params_p))
    csr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.csr_cmd_i(csr_cmd_lo)
     ,.csr_cmd_v_i(csr_cmd_v_lo & ~kill_ex3_i)
     ,.csr_data_o(csr_data_lo)

     ,.instret_i(commit_pkt.instret)
     ,.fflags_acc_i(iwb_pkt.fflags_acc | fwb_pkt.fflags_acc)
     ,.frf_w_v_i(fwb_pkt.rd_w_v)

     ,.exception_v_i(exception_v_li)
     ,.exception_pc_i(exception_pc_li)
     ,.exception_npc_i(exception_npc_li)
     ,.exception_vaddr_i(exception_vaddr_li)
     ,.exception_instr_i(exception_instr_li)

     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.external_irq_i(external_irq_i)
     ,.interrupt_ready_o(interrupt_ready_o)
     ,.interrupt_v_i(interrupt_v_i)

     ,.trap_pkt_o(trap_pkt)
     ,.trans_info_o(trans_info)
     ,.frm_dyn_o(frm_dyn_o)
     ,.fpu_en_o(fpu_en_o)
     );

  assign data_o           = csr_data_lo;
  assign exc_v_o          = trap_pkt.exception;
  assign miss_v_o         = trap_pkt.rollback;

endmodule


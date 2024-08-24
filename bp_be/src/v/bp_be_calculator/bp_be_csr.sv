
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_csr
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)

   , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam decode_info_width_lp = `bp_be_decode_info_width
   , localparam trans_info_width_lp = `bp_be_trans_info_width(ptag_width_p)
   , localparam retire_pkt_width_lp = `bp_be_retire_pkt_width(vaddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cfg_bus_width_lp-1:0]            cfg_bus_i

   // CSR check interface
   , input                                   csr_r_v_i
   , input [rv64_csr_addr_width_gp-1:0]      csr_r_addr_i
   , output logic [dword_width_gp-1:0]       csr_r_data_o
   , output logic                            csr_r_illegal_o

   // Misc interface
   , input [retire_pkt_width_lp-1:0]         retire_pkt_i
   , input rv64_fflags_s                     fflags_acc_i
   , input                                   frf_w_v_i

   // Interrupts
   , input                                   debug_irq_i
   , input                                   timer_irq_i
   , input                                   software_irq_i
   , input                                   m_external_irq_i
   , input                                   s_external_irq_i
   , output logic                            irq_pending_o
   , output logic                            irq_waiting_o

   // The final commit packet
   , output logic [commit_pkt_width_lp-1:0]  commit_pkt_o

   // Slow signals
   , output logic [decode_info_width_lp-1:0] decode_info_o
   , output logic [trans_info_width_lp-1:0]  trans_info_o
   , output rv64_frm_e                       frm_dyn_o
   );

  // Declare parameterizable structs
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `declare_csr_structs(vaddr_width_p, paddr_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  `bp_cast_i(bp_be_retire_pkt_s, retire_pkt);
  `bp_cast_o(bp_be_commit_pkt_s, commit_pkt);
  `bp_cast_o(bp_be_decode_info_s, decode_info);
  `bp_cast_o(bp_be_trans_info_s, trans_info);

  // The muxed and demuxed CSR outputs
  logic [dword_width_gp-1:0] csr_data_lo;
  logic exception_v_lo, interrupt_v_lo;

  rv64_mstatus_s sstatus_wmask_li, sstatus_rmask_li;
  rv64_mie_s sie_rwmask_li;
  rv64_mip_s sip_wmask_li, sip_rmask_li, mip_wmask_li;

  logic [rv64_priv_width_gp-1:0] priv_mode_n, priv_mode_r;
  logic debug_mode_n, debug_mode_r;
  logic translation_en_n, translation_en_r;

  wire is_debug_mode = debug_mode_r;
  // Debug Mode grants pseudo M-mode permission
  wire is_m_mode = is_debug_mode | (priv_mode_r == `PRIV_MODE_M);
  wire is_s_mode = (priv_mode_r == `PRIV_MODE_S);
  wire is_u_mode = (priv_mode_r == `PRIV_MODE_U);

  `declare_csr(dcsr);
  `declare_csr_addr(dpc, vaddr_width_p, paddr_width_p);
  `declare_csr(dscratch0);
  `declare_csr(dscratch1);

  // We have no vendorid currently
  wire [dword_width_gp-1:0] mvendorid_lo = 64'h0;
  // https://github.com/riscv/riscv-isa-manual/blob/master/marchid.md
  //   Lucky 13 (*v*)
  wire [dword_width_gp-1:0] marchid_lo = 13;
  // 0: Tapeout 0, July 2019
  // 1: Tapeout 1, June 2021
  // 2: Tapeout 2, Sept 2022
  // 3: Current
  wire [dword_width_gp-1:0] mimpid_lo  = 64'd3;
  wire [dword_width_gp-1:0] mhartid_lo = cfg_bus_cast_i.core_id;

  `declare_csr(mstatus);
  // MISA is optionally read-write, but all fields are read-only in BlackParrot
  //   64 bit MXLEN, IMACFDSUB extensions
  wire [dword_width_gp-1:0] misa_lo = {2'b10, 36'b0, 26'h14112f};
  `declare_csr(medeleg);
  `declare_csr(mideleg);
  `declare_csr(mie);
  `declare_csr_addr(mtvec, vaddr_width_p, paddr_width_p);
  `declare_csr(mcounteren);

  `declare_csr(mscratch);
  `declare_csr_addr(mepc, vaddr_width_p, paddr_width_p);
  `declare_csr(mcause);
  `declare_csr_addr(mtval, vaddr_width_p, paddr_width_p);
  `declare_csr(mip);

  // No support for PMP currently

  `declare_csr(mcycle);
  `declare_csr(minstret);
  // mhpmcounter not implemented
  //   This is non-compliant. We should hardcode to 0 instead of trapping
  `declare_csr(mcountinhibit);
  // mhpmevent not implemented
  //   This is non-compliant. We should hardcode to 0 instead of trapping

  // sstatus subset of mstatus
  wire [dword_width_gp-1:0] sstatus_lo = mstatus_lo & sstatus_rmask_li;
  wire [dword_width_gp-1:0] sedeleg_lo = '0;
  wire [dword_width_gp-1:0] sideleg_lo = '0;
  wire [dword_width_gp-1:0] sie_lo = mie_lo & sie_rwmask_li;
  `declare_csr_addr(stvec, vaddr_width_p, paddr_width_p);
  `declare_csr(scounteren);

  `declare_csr(sscratch);
  `declare_csr_addr(sepc, vaddr_width_p, paddr_width_p);
  `declare_csr(scause);
  `declare_csr_addr(stval, vaddr_width_p, paddr_width_p);
  // sip subset of mip
  wire [dword_width_gp-1:0] sip_lo = mip_lo & sip_rmask_li;

  `declare_csr_addr(satp, vaddr_width_p, paddr_width_p);

  `declare_csr(fcsr);
  wire [dword_width_gp-1:0] fflags_lo = fcsr_lo.fflags;
  wire [dword_width_gp-1:0] frm_lo    = fcsr_lo.frm;

  wire dgie = ~is_debug_mode;
  wire mgie = ~is_debug_mode & (mstatus_r.mie & is_m_mode) | is_s_mode | is_u_mode;
  wire sgie = ~is_debug_mode & (mstatus_r.sie & is_s_mode) | is_u_mode;

  wire mti_v = mie_r.mtie & mip_r.mtip;
  wire msi_v = mie_r.msie & mip_r.msip;
  wire mei_v = mie_r.meie & mip_r.meip;

  wire sti_v = mie_r.stie & mip_r.stip;
  wire ssi_v = mie_r.ssie & mip_r.ssip;
  wire sei_v = mie_r.seie & (mip_r.seip | s_external_irq_i);

  // TODO: interrupt priority is non-compliant with the spec.
  wire [15:0] interrupt_icode_dec_li =
    {4'b0

     ,mei_v
     ,1'b0
     ,sei_v
     ,1'b0

     ,mti_v
     ,1'b0 // Reserved
     ,sti_v
     ,1'b0

     ,msi_v
     ,1'b0 // Reserved
     ,ssi_v
     ,1'b0
     };

  assign irq_waiting_o = |interrupt_icode_dec_li;

  rv64_exception_dec_s exception_dec_li;
  assign exception_dec_li =
      '{instr_misaligned    : retire_pkt_cast_i.exception.instr_misaligned
        ,instr_access_fault : retire_pkt_cast_i.exception.instr_access_fault
        ,illegal_instr      : retire_pkt_cast_i.exception.illegal_instr
        ,breakpoint         : retire_pkt_cast_i.exception.ebreak
        ,load_misaligned    : retire_pkt_cast_i.exception.load_misaligned
        ,load_access_fault  : retire_pkt_cast_i.exception.load_access_fault
        ,store_misaligned   : retire_pkt_cast_i.exception.store_misaligned
        ,store_access_fault : retire_pkt_cast_i.exception.store_access_fault
        ,ecall_u_mode       : retire_pkt_cast_i.exception.ecall_u
        ,ecall_s_mode       : retire_pkt_cast_i.exception.ecall_s
        ,ecall_m_mode       : retire_pkt_cast_i.exception.ecall_m
        ,instr_page_fault   : retire_pkt_cast_i.exception.instr_page_fault
        ,load_page_fault    : retire_pkt_cast_i.exception.load_page_fault
        ,store_page_fault   : retire_pkt_cast_i.exception.store_page_fault
        ,default : '0
        };

  logic [3:0] exception_ecode_li;
  logic       exception_ecode_v_li;
  bsg_priority_encode
   #(.width_p($bits(exception_dec_li)), .lo_to_hi_p(1))
   mcause_exception_enc
    (.i(exception_dec_li)
     ,.addr_o(exception_ecode_li)
     ,.v_o(exception_ecode_v_li)
     );

  wire d_interrupt_icode_v_li = debug_irq_i;

  logic [3:0] m_interrupt_icode_li, s_interrupt_icode_li;
  logic       m_interrupt_icode_v_li, s_interrupt_icode_v_li;
  bsg_priority_encode
   #(.width_p($bits(exception_dec_li)), .lo_to_hi_p(1))
   m_interrupt_enc
    (.i(interrupt_icode_dec_li & ~mideleg_lo[0+:$bits(exception_dec_li)])
     ,.addr_o(m_interrupt_icode_li)
     ,.v_o(m_interrupt_icode_v_li)
     );

  bsg_priority_encode
   #(.width_p($bits(exception_dec_li)), .lo_to_hi_p(1))
   s_interrupt_enc
    (.i(interrupt_icode_dec_li & mideleg_lo[0+:$bits(exception_dec_li)])
     ,.addr_o(s_interrupt_icode_li)
     ,.v_o(s_interrupt_icode_v_li)
     );

  wire                               csr_w_v_li = retire_pkt_cast_i.special.csrw; 
  wire [rv64_reg_data_width_gp-1:0] csr_data_li = retire_pkt_cast_i.data;
  wire [rv64_csr_addr_width_gp-1:0] csr_addr_li = retire_pkt_cast_i.instr.t.itype.imm12;
  wire [rv64_funct3_width_gp-1:0]   csr_func_li = retire_pkt_cast_i.instr.t.itype.funct3;

  wire csr_fany_li = csr_addr_li inside {`CSR_ADDR_FCSR, `CSR_ADDR_FFLAGS, `CSR_ADDR_FRM};
  wire instr_fany_li = retire_pkt_cast_i.instr.t.rtype.opcode inside
    {`RV64_FLOAD_OP, `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FP_OP};

  logic enter_debug, exit_debug;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   debug_mode_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(enter_debug)
     ,.clear_i(exit_debug)

     ,.data_o(debug_mode_r)
     );

  logic [vaddr_width_p-1:0] apc_n, apc_r;
  bsg_dff_reset
   #(.width_p(vaddr_width_p))
   apc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(apc_n)
     ,.data_o(apc_r)
     );

  // Just for timing, could remove and save some regs...
  logic [vaddr_width_p-1:0] cfg_npc_r;
  wire [vaddr_width_p-1:0] cfg_npc_n = cfg_bus_cast_i.npc;
  bsg_dff
   #(.width_p(vaddr_width_p))
   cfg_npc_reg
    (.clk_i(clk_i)
     ,.data_i(cfg_npc_n)
     ,.data_o(cfg_npc_r)
     );
  // This currently depends on specific offsets in the debug module which are
  //   compatible with the pulp-platform debug rom:
  // https://github.com/pulp-platform/riscv-dbg/blob/64f48cd8ef3ed4269ab3dfcc32e8a137a871e3e1/src/dm_pkg.sv#L28
  // For now, assume that debug_halt_pc is 16 byte aligned to avoid another mux
  wire [vaddr_width_p-1:0] debug_halt_pc      = {cfg_npc_r[vaddr_width_p-1:4], 4'b0000};
  wire [vaddr_width_p-1:0] debug_resume_pc    = {cfg_npc_r[vaddr_width_p-1:4], 4'b0100};
  wire [vaddr_width_p-1:0] debug_exception_pc = {cfg_npc_r[vaddr_width_p-1:4], 4'b1000};

  wire [vaddr_width_p-1:0] ret_pc =
    retire_pkt_cast_i.special.sret
    ? sepc_lo
    : retire_pkt_cast_i.special.mret
      ? mepc_lo
      : dpc_lo;
  wire [vaddr_width_p-1:0] tvec_pc =
    is_debug_mode ? debug_exception_pc
    : (priv_mode_n == `PRIV_MODE_S)
      ? {stvec_lo.base, 2'b00}
      : {mtvec_lo.base, 2'b00};

  wire [vaddr_width_p-1:0] core_npc =
    (exception_v_lo | interrupt_v_lo)
    ? tvec_pc
    : commit_pkt_cast_o.eret
      ? ret_pc
      : retire_pkt_cast_i.instret
        ? retire_pkt_cast_i.npc
        : apc_r;

  assign apc_n = (enter_debug | cfg_bus_cast_i.freeze) ? debug_halt_pc : core_npc;

  assign translation_en_n = ((priv_mode_n < `PRIV_MODE_M) & (satp_li.mode == 4'd8));
  bsg_dff_reset
   #(.width_p(3), .reset_val_p({1'b0, `PRIV_MODE_M}))
   priv_mode_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({translation_en_n, priv_mode_n})
     ,.data_o({translation_en_r, priv_mode_r})
     );

  // sstatus mask
  assign sstatus_wmask_li = '{fs: 2'b11
                              ,mxr: 1'b1, sum: 1'b1
                              ,mpp: 2'b00, spp: 2'b11
                              ,mpie: 1'b0, spie: 1'b1
                              ,mie: 1'b0, sie: 1'b1
                              ,default: '0
                              };
  assign sstatus_rmask_li = '{sd: 1'b1, uxl: 2'b11, fs: 2'b11
                              ,mxr: 1'b1, sum: 1'b1
                              ,mpp: 2'b00, spp: 2'b11
                              ,mpie: 1'b0, spie: 1'b1
                              ,mie: 1'b0, sie: 1'b1
                              ,default: '0
                              };

  // sie mask
  assign sie_rwmask_li    = mideleg_lo;

  // sip mask
  assign sip_rmask_li     = mideleg_lo;
  assign sip_wmask_li     = '{meip: 1'b0, seip: 1'b0
                              ,mtip: 1'b0, stip: 1'b0
                              ,msip: 1'b0, ssip: mideleg_lo.ssi
                              ,default: '0
                              };

  // CSR read
  always_comb
    begin
      csr_r_illegal_o = 1'b0;
      unique casez (csr_r_addr_i)
        {`CSR_ADDR_FFLAGS       }: csr_data_lo = fcsr_lo.fflags;
        {`CSR_ADDR_FRM          }: csr_data_lo = fcsr_lo.frm;
        {`CSR_ADDR_FCSR         }: csr_data_lo = fcsr_lo;
        {`CSR_ADDR_CYCLE        }: csr_data_lo = mcycle_lo;
        {`CSR_ADDR_INSTRET      }: csr_data_lo = minstret_lo;
        {`CSR_ADDR_SSTATUS      }: csr_data_lo = sstatus_lo;
        {`CSR_ADDR_SEDELEG      }: csr_data_lo = sedeleg_lo;
        {`CSR_ADDR_SIDELEG      }: csr_data_lo = sideleg_lo;
        {`CSR_ADDR_SIE          }: csr_data_lo = sie_lo;
        {`CSR_ADDR_STVEC        }: csr_data_lo = stvec_lo;
        {`CSR_ADDR_SCOUNTEREN   }: csr_data_lo = scounteren_lo;
        {`CSR_ADDR_SSCRATCH     }: csr_data_lo = sscratch_lo;
        {`CSR_ADDR_SEPC         }: csr_data_lo = sepc_lo;
        {`CSR_ADDR_SCAUSE       }: csr_data_lo = scause_lo;
        {`CSR_ADDR_STVAL        }: csr_data_lo = stval_lo;
        {`CSR_ADDR_SIP          }: csr_data_lo = sip_lo;
        {`CSR_ADDR_SATP         }: csr_data_lo = satp_lo;
        {`CSR_ADDR_MVENDORID    }: csr_data_lo = mvendorid_lo;
        {`CSR_ADDR_MARCHID      }: csr_data_lo = marchid_lo;
        {`CSR_ADDR_MIMPID       }: csr_data_lo = mimpid_lo;
        {`CSR_ADDR_MHARTID      }: csr_data_lo = mhartid_lo;
        {`CSR_ADDR_MSTATUS      }: csr_data_lo = mstatus_lo;
        {`CSR_ADDR_MISA         }: csr_data_lo = misa_lo;
        {`CSR_ADDR_MEDELEG      }: csr_data_lo = medeleg_lo;
        {`CSR_ADDR_MIDELEG      }: csr_data_lo = mideleg_lo;
        {`CSR_ADDR_MIE          }: csr_data_lo = mie_lo;
        {`CSR_ADDR_MTVEC        }: csr_data_lo = mtvec_lo;
        {`CSR_ADDR_MCOUNTEREN   }: csr_data_lo = mcounteren_lo;
        {`CSR_ADDR_MIP          }: csr_data_lo = mip_lo;
        {`CSR_ADDR_MSCRATCH     }: csr_data_lo = mscratch_lo;
        {`CSR_ADDR_MEPC         }: csr_data_lo = mepc_lo;
        {`CSR_ADDR_MCAUSE       }: csr_data_lo = mcause_lo;
        {`CSR_ADDR_MTVAL        }: csr_data_lo = mtval_lo;
        {`CSR_ADDR_MCYCLE       }: csr_data_lo = mcycle_lo;
        {`CSR_ADDR_MINSTRET     }: csr_data_lo = minstret_lo;
        {`CSR_ADDR_MCOUNTINHIBIT}: csr_data_lo = mcountinhibit_lo;
        {`CSR_ADDR_DCSR         }: csr_data_lo = dcsr_lo;
        {`CSR_ADDR_DPC          }: csr_data_lo = dpc_lo;
        {`CSR_ADDR_DSCRATCH0    }: csr_data_lo = dscratch0_lo;
        {`CSR_ADDR_DSCRATCH1    }: csr_data_lo = dscratch1_lo;
        default:
          begin
            csr_data_lo = '0;
            csr_r_illegal_o = csr_r_v_i;
          end
      endcase
    end

  // CSR update
  always_comb
    begin
      priv_mode_n   = priv_mode_r;

      fcsr_li       = fcsr_lo;

      stvec_li      = stvec_lo;
      scounteren_li = scounteren_lo;

      sscratch_li = sscratch_lo;
      sepc_li     = sepc_lo;
      scause_li   = scause_lo;
      stval_li    = stval_lo;

      satp_li     = satp_lo;

      mstatus_li    = mstatus_lo;
      medeleg_li    = medeleg_lo;
      mideleg_li    = mideleg_lo;
      mie_li        = mie_lo;
      mtvec_li      = mtvec_lo;
      mcounteren_li = mcounteren_lo;

      mscratch_li = mscratch_lo;
      mepc_li     = mepc_lo;
      mcause_li   = mcause_lo;
      mtval_li    = mtval_lo;
      mip_li      = mip_lo;

      mcycle_li        = mcycle_lo;
      minstret_li      = minstret_lo;
      mcountinhibit_li = mcountinhibit_lo;

      dcsr_li     = dcsr_lo;
      dpc_li      = dpc_lo;
      dscratch0_li = dscratch0_lo;
      dscratch1_li = dscratch1_lo;

      enter_debug = '0;
      exit_debug  = '0;
      exception_v_lo    = '0;
      interrupt_v_lo    = '0;

      unique casez ({csr_w_v_li, csr_addr_li})
        {1'b1, `CSR_ADDR_FFLAGS       }: fcsr_li = '{frm: fcsr_lo.frm, fflags: csr_data_li, default: '0};
        {1'b1, `CSR_ADDR_FRM          }: fcsr_li = '{frm: csr_data_li, fflags: fcsr_lo.fflags, default: '0};
        {1'b1, `CSR_ADDR_FCSR         }: fcsr_li = csr_data_li;
        // Time must be done by trapping, since we can't stall at this point
        {1'b1, `CSR_ADDR_INSTRET      }: minstret_li = csr_data_li;
        // SSTATUS subset of MSTATUS
        {1'b1, `CSR_ADDR_SSTATUS      }: mstatus_li = (mstatus_lo & ~sstatus_wmask_li) | (csr_data_li & sstatus_wmask_li);
        // Read-only because we don't support N-extension
        // Read-only because we don't support N-extension
        {1'b1, `CSR_ADDR_SEDELEG      }: begin end
        {1'b1, `CSR_ADDR_SIDELEG      }: begin end
        {1'b1, `CSR_ADDR_SIE          }: mie_li = (mie_lo & ~sie_rwmask_li) | (csr_data_li & sie_rwmask_li);
        {1'b1, `CSR_ADDR_STVEC        }: stvec_li = csr_data_li;
        {1'b1, `CSR_ADDR_SCOUNTEREN   }: scounteren_li = csr_data_li;
        {1'b1, `CSR_ADDR_SSCRATCH     }: sscratch_li = csr_data_li;
        {1'b1, `CSR_ADDR_SEPC         }: sepc_li = csr_data_li;
        {1'b1, `CSR_ADDR_SCAUSE       }: scause_li = csr_data_li;
        {1'b1, `CSR_ADDR_STVAL        }: stval_li = csr_data_li;
        // SIP subset of MIP
        {1'b1, `CSR_ADDR_SIP          }: mip_li = (mip_lo & ~sip_wmask_li) | (csr_data_li & sip_wmask_li);
        {1'b1, `CSR_ADDR_SATP         }: satp_li = csr_data_li;
        {1'b1, `CSR_ADDR_MSTATUS      }: mstatus_li = csr_data_li;
        {1'b1, `CSR_ADDR_MISA         }: begin end
        {1'b1, `CSR_ADDR_MEDELEG      }: medeleg_li = csr_data_li;
        {1'b1, `CSR_ADDR_MIDELEG      }: mideleg_li = csr_data_li;
        {1'b1, `CSR_ADDR_MIE          }: mie_li = csr_data_li;
        {1'b1, `CSR_ADDR_MTVEC        }: mtvec_li = csr_data_li;
        {1'b1, `CSR_ADDR_MCOUNTEREN   }: mcounteren_li = csr_data_li;
        {1'b1, `CSR_ADDR_MIP          }: mip_li = csr_data_li;
        {1'b1, `CSR_ADDR_MSCRATCH     }: mscratch_li = csr_data_li;
        {1'b1, `CSR_ADDR_MEPC         }: mepc_li = csr_data_li;
        {1'b1, `CSR_ADDR_MCAUSE       }: mcause_li = csr_data_li;
        {1'b1, `CSR_ADDR_MTVAL        }: mtval_li = csr_data_li;
        {1'b1, `CSR_ADDR_MCYCLE       }: mcycle_li = csr_data_li;
        {1'b1, `CSR_ADDR_MINSTRET     }: minstret_li = csr_data_li;
        {1'b1, `CSR_ADDR_MCOUNTINHIBIT}: mcountinhibit_li = csr_data_li;
        {1'b1, `CSR_ADDR_DCSR         }: dcsr_li = csr_data_li;
        {1'b1, `CSR_ADDR_DPC          }: dpc_li = csr_data_li;
        {1'b1, `CSR_ADDR_DSCRATCH0    }: dscratch0_li = csr_data_li;
        {1'b1, `CSR_ADDR_DSCRATCH1    }: dscratch1_li = csr_data_li;
        default: begin end
      endcase

      if (retire_pkt_cast_i.exception._interrupt)
        begin
          if (m_interrupt_icode_v_li & mgie)
            begin
              priv_mode_n          = `PRIV_MODE_M;

              mstatus_li.mpp       = priv_mode_r;
              mstatus_li.mpie      = mstatus_lo.mie;
              mstatus_li.mie       = 1'b0;

              mepc_li              = `BSG_SIGN_EXTEND(apc_r, dword_width_gp);
              mtval_li             = '0;
              mcause_li._interrupt = 1'b1;
              mcause_li.ecode      = m_interrupt_icode_li;

              interrupt_v_lo        = 1'b1;
            end
          else if (s_interrupt_icode_v_li & sgie)
            begin
              priv_mode_n          = `PRIV_MODE_S;

              mstatus_li.spp       = priv_mode_r;
              mstatus_li.spie      = mstatus_lo.sie;
              mstatus_li.sie       = 1'b0;

              sepc_li              = `BSG_SIGN_EXTEND(apc_r, dword_width_gp);
              stval_li             = '0;
              scause_li._interrupt = 1'b1;
              scause_li.ecode      = s_interrupt_icode_li;

              interrupt_v_lo        = 1'b1;
            end
        end
      else if (exception_ecode_v_li)
        begin
          if (is_debug_mode)
            begin
              // Trap back into debug mode, don't set any CSRs
              exception_v_lo       = 1'b1;
            end
          else if (medeleg_lo[exception_ecode_li] & ~is_m_mode)
            begin
              priv_mode_n          = `PRIV_MODE_S;

              mstatus_li.spp       = priv_mode_r;
              mstatus_li.spie      = mstatus_lo.sie;
              mstatus_li.sie       = 1'b0;

              sepc_li              = `BSG_SIGN_EXTEND(apc_r, dword_width_gp);
              stval_li             = (exception_ecode_li == 2)
                                    ? retire_pkt_cast_i.instr
                                    : `BSG_SIGN_EXTEND(retire_pkt_cast_i.vaddr, dword_width_gp);

              scause_li._interrupt = 1'b0;
              scause_li.ecode      = exception_ecode_li;

              exception_v_lo        = 1'b1;
            end
          else
            begin
              priv_mode_n          = `PRIV_MODE_M;

              mstatus_li.mpp       = priv_mode_r;
              mstatus_li.mpie      = mstatus_lo.mie;
              mstatus_li.mie       = 1'b0;

              mepc_li              = `BSG_SIGN_EXTEND(apc_r, dword_width_gp);
              mtval_li             = (exception_ecode_li == 2)
                                    ? retire_pkt_cast_i.instr
                                    : `BSG_SIGN_EXTEND(retire_pkt_cast_i.vaddr, dword_width_gp);

              mcause_li._interrupt = 1'b0;
              mcause_li.ecode      = exception_ecode_li;

              exception_v_lo        = 1'b1;
            end
        end

      // Re-enter debug mode if ebreaking during debug sequence
      if (is_debug_mode)
        begin
          enter_debug = retire_pkt_cast_i.special.dbreak;
        end
      else if (retire_pkt_cast_i.exception._interrupt & d_interrupt_icode_v_li & dgie)
        begin
          enter_debug    = 1'b1;
          dpc_li         = `BSG_SIGN_EXTEND(apc_r, dword_width_gp);
          dcsr_li.cause  = 3; // Debugger
          dcsr_li.prv    = priv_mode_r;
        end
      else if (retire_pkt_cast_i.special.dbreak)
        begin
          enter_debug    = 1'b1;
          dpc_li         = `BSG_SIGN_EXTEND(apc_r, dword_width_gp);
          dcsr_li.cause  = 1; // Ebreak
          dcsr_li.prv    = priv_mode_r;
        end
      // Always break in single step mode
      else if (retire_pkt_cast_i.queue_v & dcsr_lo.step)
        begin
          enter_debug    = 1'b1;
          dpc_li         = `BSG_SIGN_EXTEND(core_npc, dword_width_gp);
          dcsr_li.cause  = 4;
          dcsr_li.prv    = priv_mode_r;
        end

      // Only exit debug mode through dret
      if (retire_pkt_cast_i.special.dret)
        begin
          exit_debug     = 1'b1;
          priv_mode_n    = dcsr_lo.prv;
        end

      if (retire_pkt_cast_i.special.mret)
        begin
          priv_mode_n      = mstatus_lo.mpp;

          mstatus_li.mpp   = `PRIV_MODE_U;
          mstatus_li.mpie  = 1'b1;
          mstatus_li.mie   = mstatus_lo.mpie;
          mstatus_li.mprv  = (priv_mode_n < `PRIV_MODE_M) ? '0 : mstatus_li.mprv;
        end

      if (retire_pkt_cast_i.special.sret)
        begin
          priv_mode_n      = {1'b0, mstatus_lo.spp};

          mstatus_li.spp   = `PRIV_MODE_U;
          mstatus_li.spie  = 1'b1;
          mstatus_li.sie   = mstatus_lo.spie;
          mstatus_li.mprv  = (priv_mode_n < `PRIV_MODE_M) ? '0 : mstatus_li.mprv;
        end

      // Accumulate interrupts
      mip_li.mtip = timer_irq_i;
      mip_li.msip = software_irq_i;
      mip_li.meip = m_external_irq_i;

      // Accumulate FFLAGS if we're not writing them this cycle
      if (~(csr_w_v_li & csr_addr_li inside {`CSR_ADDR_FFLAGS, `CSR_ADDR_FCSR}))
        fcsr_li.fflags |= fflags_acc_i;

      // Accumulate counters if we're not writing them
      if (~(csr_w_v_li & csr_addr_li inside {`CSR_ADDR_CYCLE, `CSR_ADDR_MCYCLE}) & ~mcountinhibit_lo.cy)
        mcycle_li = mcycle_lo + 1'b1;
      if (~(csr_w_v_li & csr_addr_li inside {`CSR_ADDR_INSTRET, `CSR_ADDR_MINSTRET}) & ~mcountinhibit_lo.ir)
        minstret_li = minstret_lo + retire_pkt_cast_i.instret;

      // Set FS to dirty if: fflags set, frf written, fcsr written
      mstatus_li.fs |= {2{csr_w_v_li & csr_fany_li}};
      mstatus_li.fs |= {2{retire_pkt_cast_i.instret & instr_fany_li}};
    end

  assign irq_pending_o = (~dcsr_lo.step | dcsr_lo.stepie)
    & ((d_interrupt_icode_v_li & dgie) | (m_interrupt_icode_v_li & mgie) | (s_interrupt_icode_v_li & sgie));

  // The supervisor external interrupt line does not impact the supervisor software interrupt bit of MIP.
  // However, software read operations return as if it does. bit 9 is supervisor software interrupt
  always_comb
    unique casez (csr_addr_li)
      `CSR_ADDR_SIP   : csr_r_data_o = csr_data_lo | ((s_external_irq_i & sip_rmask_li) << 9);
      `CSR_ADDR_MIP   : csr_r_data_o = csr_data_lo | (s_external_irq_i << 9);
      `CSR_ADDR_FFLAGS
      ,`CSR_ADDR_FCSR : csr_r_data_o = csr_data_lo | fflags_acc_i;
      default: csr_r_data_o = csr_data_lo;
    endcase

  assign commit_pkt_cast_o.npc_w_v           = |{retire_pkt_cast_i.special, retire_pkt_cast_i.exception};
  assign commit_pkt_cast_o.queue_v           = retire_pkt_cast_i.queue_v & ~|retire_pkt_cast_i.exception;
  assign commit_pkt_cast_o.instret           = retire_pkt_cast_i.instret;
  assign commit_pkt_cast_o.size              = retire_pkt_cast_i.size;
  assign commit_pkt_cast_o.count             = retire_pkt_cast_i.count;
  assign commit_pkt_cast_o.pc                = apc_r;
  assign commit_pkt_cast_o.npc               = apc_n;
  assign commit_pkt_cast_o.vaddr             = retire_pkt_cast_i.vaddr;
  assign commit_pkt_cast_o.instr             = retire_pkt_cast_i.instr;
  assign commit_pkt_cast_o.pte_leaf          = retire_pkt_cast_i.data;
  assign commit_pkt_cast_o.priv_n            = priv_mode_n;
  assign commit_pkt_cast_o.translation_en_n  = translation_en_n;
  assign commit_pkt_cast_o.exception         = exception_v_lo;
  // Debug mode acts as a pseudo-interrupt
  assign commit_pkt_cast_o._interrupt        = interrupt_v_lo | enter_debug;
  assign commit_pkt_cast_o.fencei            = retire_pkt_cast_i.special.fencei;
  assign commit_pkt_cast_o.sfence            = retire_pkt_cast_i.special.sfence_vma;
  assign commit_pkt_cast_o.wfi               = retire_pkt_cast_i.special.wfi;
  assign commit_pkt_cast_o.eret              = |{retire_pkt_cast_i.special.dret, retire_pkt_cast_i.special.mret, retire_pkt_cast_i.special.sret};
  assign commit_pkt_cast_o.csrw              = retire_pkt_cast_i.special.csrw;
  assign commit_pkt_cast_o.resume            = retire_pkt_cast_i.exception.resume;
  assign commit_pkt_cast_o.itlb_miss         = retire_pkt_cast_i.exception.itlb_miss;
  assign commit_pkt_cast_o.icache_miss       = retire_pkt_cast_i.exception.icache_miss;
  assign commit_pkt_cast_o.dtlb_store_miss   = retire_pkt_cast_i.exception.dtlb_store_miss;
  assign commit_pkt_cast_o.dtlb_load_miss    = retire_pkt_cast_i.exception.dtlb_load_miss;
  assign commit_pkt_cast_o.dcache_replay     = retire_pkt_cast_i.exception.dcache_replay;
  assign commit_pkt_cast_o.dcache_miss       = retire_pkt_cast_i.special.dcache_miss;
  assign commit_pkt_cast_o.itlb_fill_v       = retire_pkt_cast_i.exception.itlb_fill;
  assign commit_pkt_cast_o.dtlb_fill_v       = retire_pkt_cast_i.exception.dtlb_fill;
  assign commit_pkt_cast_o.iscore_v          = retire_pkt_cast_i.iscore;
  assign commit_pkt_cast_o.fscore_v          = retire_pkt_cast_i.fscore;

  assign trans_info_cast_o.priv_mode      = priv_mode_r;
  assign trans_info_cast_o.base_ppn       = satp_lo.ppn;
  assign trans_info_cast_o.translation_en = translation_en_r
    | ((~is_debug_mode | dcsr_lo.mprven) & mstatus_lo.mprv & (mstatus_lo.mpp < `PRIV_MODE_M) & (satp_lo.mode == 4'd8));
  assign trans_info_cast_o.mstatus_sum = mstatus_lo.sum;
  assign trans_info_cast_o.mstatus_mxr = mstatus_lo.mxr;

  assign decode_info_cast_o.m_mode     = is_m_mode;
  assign decode_info_cast_o.s_mode     = is_s_mode;
  assign decode_info_cast_o.u_mode     = is_u_mode;
  assign decode_info_cast_o.debug_mode = debug_mode_r;
  assign decode_info_cast_o.tsr        = mstatus_lo.tsr;
  assign decode_info_cast_o.tw         = mstatus_lo.tw;
  assign decode_info_cast_o.tvm        = mstatus_lo.tvm;
  assign decode_info_cast_o.ebreakm    = dcsr_lo.ebreakm;
  assign decode_info_cast_o.ebreaks    = dcsr_lo.ebreaks;
  assign decode_info_cast_o.ebreaku    = dcsr_lo.ebreaku;
  assign decode_info_cast_o.fpu_en     = (mstatus_lo.fs != 2'b00);
  assign decode_info_cast_o.cycle_en   = is_m_mode | (is_s_mode & mcounteren_lo.cy) | (is_u_mode & scounteren_lo.cy);
  assign decode_info_cast_o.instret_en = is_m_mode | (is_m_mode & mcounteren_lo.ir) | (is_u_mode & mcounteren_lo.ir);

  assign frm_dyn_o = rv64_frm_e'(fcsr_lo.frm);

endmodule


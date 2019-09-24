module bp_be_csr
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    , localparam fu_op_width_lp = `bp_be_fu_op_width
    , localparam csr_cmd_width_lp = `bp_be_csr_cmd_width
    , localparam ecode_dec_width_lp = `bp_be_ecode_dec_width

    , localparam satp_width_lp  = `bp_satp_width

    , localparam hartid_width_lp = `BSG_SAFE_CLOG2(num_core_p)
    )
   (input                            clk_i
    , input                          reset_i

    // CSR instruction interface
    , input [csr_cmd_width_lp-1:0]   csr_cmd_i
    , input                          csr_cmd_v_i
    , output                         csr_cmd_ready_o

    , output [dword_width_p-1:0]     data_o
    , output                         v_o
    , output logic                   illegal_instr_o

    // Misc interface
    , input [hartid_width_lp-1:0]    hartid_i
    , input                          instret_i

    , input                          exception_v_i
    , input [vaddr_width_p-1:0]      exception_pc_i
    , input [vaddr_width_p-1:0]      exception_vaddr_i
    , input [instr_width_p-1:0]      exception_instr_i
    , input [ecode_dec_width_lp-1:0] exception_ecode_dec_i

    , input                          timer_int_i
    , input                          software_int_i
    , input                          external_int_i
    , input [vaddr_width_p-1:0]      interrupt_pc_i

    , output [rv64_priv_width_gp-1:0]   priv_mode_o
    , output logic                      trap_v_o
    , output logic                      ret_v_o
    , output logic [vaddr_width_p-1:0]  epc_o
    , output logic [vaddr_width_p-1:0]  tvec_o
    , output [satp_width_lp-1:0]        satp_o
    , output                            translation_en_o
    , output logic                      tlb_fence_o
    );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p/8)

// Casting input and output ports
bp_be_csr_cmd_s csr_cmd;
bp_be_ecode_dec_s exception_ecode_dec_cast_i;

assign csr_cmd = csr_cmd_i;
assign exception_ecode_dec_cast_i = exception_ecode_dec_i;

// The muxed and demuxed CSR outputs
logic [dword_width_p-1:0] csr_data_li, csr_data_lo;

rv64_mstatus_s sstatus_wmask_li, sstatus_rmask_li;
rv64_mie_s sie_wmask_li, sie_rmask_li;
rv64_mip_s sip_wmask_li, sip_rmask_li;;

logic [1:0] priv_mode_n, priv_mode_r;

assign priv_mode_o = priv_mode_r;

wire is_m_mode = (priv_mode_r == `PRIV_MODE_M);
wire is_s_mode = (priv_mode_r == `PRIV_MODE_S);
wire is_u_mode = (priv_mode_r == `PRIV_MODE_U);

wire mti_v = mstatus_r.mie & mie_r.mtie & mip_r.mtip;
wire msi_v = mstatus_r.mie & mie_r.msie & mip_r.msip;
wire mei_v = mstatus_r.mie & mie_r.meie & mip_r.meip;

wire sti_v = mstatus_r.sie & mie_r.stie & mip_r.stip;
wire ssi_v = mstatus_r.sie & mie_r.ssie & mip_r.ssip;
wire sei_v = mstatus_r.sie & mie_r.seie & mip_r.seip;

wire [15:0] exception_icode_dec_li =
  {4'b0

   ,mei_v & ~mideleg_lo.mei
   ,1'b0
   ,sei_v &  mideleg_lo.sei
   ,1'b0

   ,mti_v & ~mideleg_lo.mti
   ,1'b0 // Reserved
   ,sti_v &  mideleg_lo.sei
   ,1'b0

   ,msi_v & ~mideleg_lo.msi
   ,1'b0 // Reserved
   ,ssi_v &  mideleg_lo.ssi
   ,1'b0
   };

logic [3:0] exception_ecode_li;
logic       exception_ecode_v_li;
bsg_priority_encode 
 #(.width_p(ecode_dec_width_lp)
   ,.lo_to_hi_p(1)
   )
 mcause_exception_enc
  (.i(exception_ecode_dec_i)
   ,.addr_o(exception_ecode_li)
   ,.v_o(exception_ecode_v_li)
   );

// TODO: This priority encoder needs to be swizzled, right now it is non-compliant with the spec...
logic [3:0] exception_icode_li;
logic       exception_icode_v_li;
bsg_priority_encode
 #(.width_p(ecode_dec_width_lp)
   ,.lo_to_hi_p(1)
   )
 mcause_interrupt_enc
  (.i(exception_icode_dec_li)
   ,.addr_o(exception_icode_li)
   ,.v_o(exception_icode_v_li)
   );

// Compute input CSR data
wire [dword_width_p-1:0] csr_imm_li = dword_width_p'(csr_cmd.data[4:0]);
always_comb 
  begin
    unique casez (csr_cmd.csr_op)
      e_csrrw : csr_data_li =  csr_cmd.data;
      e_csrrs : csr_data_li =  csr_cmd.data | csr_data_lo;
      e_csrrc : csr_data_li = ~csr_cmd.data & csr_data_lo;

      e_csrrwi: csr_data_li =  csr_imm_li;
      e_csrrsi: csr_data_li =  csr_imm_li | csr_data_lo;
      e_csrrci: csr_data_li = ~csr_imm_li & csr_data_lo;
      default : csr_data_li = '0;
    endcase
  end

// sstatus subset of mstatus
// sedeleg hardcoded to 0
// sideleg hardcoded to 0
// sie subset of mie
`declare_csr(stvec)
`declare_csr(scounteren)

`declare_csr(sscratch)
`declare_csr(sepc)
`declare_csr(scause)
`declare_csr(stval)
// sip subset of mip

`declare_csr(satp)

// mvendorid readonly
// marchid readonly
// mimpid readonly
// mhartid readonly

`declare_csr(mstatus)
// misa readonly
`declare_csr(medeleg)
`declare_csr(mideleg)
`declare_csr(mie)
`declare_csr(mtvec)
`declare_csr(mcounteren)

`declare_csr(mscratch)
`declare_csr(mepc)
`declare_csr(mcause)
`declare_csr(mtval)
`declare_csr(mip)

`declare_csr(pmpcfg0)
`declare_csr(pmpaddr0)
`declare_csr(pmpaddr1)
`declare_csr(pmpaddr2)
`declare_csr(pmpaddr3)

`declare_csr(mcycle)
`declare_csr(minstret)
// mhpmcounter not implemented
//   This is non-compliant. We should hardcode to 0 instead of trapping
`declare_csr(mcountinhibit)
// mhpmevent not implemented
//   This is non-compliant. We should hardcode to 0 instead of trapping

bsg_dff_reset
 #(.width_p(2) 
   ,.reset_val_p(`PRIV_MODE_M)
   )
 priv_mode_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(priv_mode_n)
   ,.data_o(priv_mode_r)
   );

// CSR data
always_comb
  begin
    priv_mode_n = priv_mode_r;

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

    pmpcfg0_li  = pmpcfg0_lo;
    pmpaddr0_li = pmpaddr0_lo;
    pmpaddr1_li = pmpaddr1_lo;
    pmpaddr2_li = pmpaddr2_lo;
    pmpaddr3_li = pmpaddr3_lo;

    mcycle_li        = mcountinhibit_lo.cy ? mcycle_lo + dword_width_p'(1) : mcycle_lo;
    minstret_li      = mcountinhibit_lo.ir ? minstret_lo + dword_width_p'(instret_i) : minstret_lo;
    mcountinhibit_li = mcountinhibit_lo;

    trap_v_o        = '0;
    ret_v_o         = '0;
    illegal_instr_o = '0;
    csr_data_lo     = '0;
    tlb_fence_o     = '0;

    sstatus_wmask_li = '0;
    sstatus_rmask_li = '0;
    sie_wmask_li     = '0;
    sie_rmask_li     = '0;
    sip_wmask_li     = '0;
    sip_rmask_li     = '0;
        
    if (csr_cmd_v_i)
      if (csr_cmd.csr_op == e_sfence_vma)
        begin
          illegal_instr_o = (priv_mode_r < `PRIV_MODE_S);
          tlb_fence_o     = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op == e_mret)
        begin
          priv_mode_n      = mstatus_lo.mpp;

          mstatus_li.mpp   = `PRIV_MODE_M; // Should be U when U-mode is supported
          mstatus_li.mpie  = 1'b1;
          mstatus_li.mie   = mstatus_lo.mpie;

          illegal_instr_o  = (priv_mode_r < `PRIV_MODE_M);
          ret_v_o          = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op == e_sret)
        begin
          priv_mode_n      = {1'b0, mstatus_lo.spp};
          
          mstatus_li.spp   = `PRIV_MODE_M; // Should be U when U-mode is supported
          mstatus_li.spie  = 1'b1;
          mstatus_li.sie   = mstatus_lo.spie;

          illegal_instr_o  = (priv_mode_r < `PRIV_MODE_S);
          ret_v_o          = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op inside {e_ebreak, e_ecall, e_wfi})
        begin
          // NOPs for now. EBREAK and WFI are likely to remain a NOP for a while, whereas
          // ECALL is implemented as part of the exception cause vector
        end
      else 
        begin
          sstatus_wmask_li = '{mpp: 2'b00, spp: 2'b11
                               ,mpie: 1'b0, spie: 1'b1, upie: 1'b1
                               ,mie: 1'b0, sie: 1'b1, uie: 1'b1
                               ,default: '0
                               };
          sstatus_rmask_li = '{sd: 1'b1, uxl: 2'b11
                               ,mxr: 1'b1, sum: 1'b1
                               ,xs: 2'b11, fs: 2'b11
                               ,mpp: 2'b00, spp: 2'b11
                               ,mpie: 1'b0, spie: 1'b1, upie: 1'b1
                               ,mie: 1'b0, sie: 1'b1, uie: 1'b1
                               ,default: '0
                               };
          sie_wmask_li     = '{meie: mideleg_lo.mei, seie: 1'b1
                               ,mtie: mideleg_lo.mti, stie: 1'b1
                               ,msie: mideleg_lo.msi, ssie: 1'b1
                               ,default: '0
                               };
          sie_rmask_li     = '{meie: mideleg_lo.mei, seie: 1'b1
                               ,mtie: mideleg_lo.mti, stie: 1'b1
                               ,msie: mideleg_lo.msi, ssie: 1'b1
                               ,default: '0
                               };
          sip_wmask_li     = '{meip: 1'b0, seip: 1'b1
                               ,mtip: 1'b0, stip: 1'b1
                               ,msip: 1'b0, ssip: 1'b1
                               ,default: '0
                               };
          sip_rmask_li     = '{meip: mideleg_lo.mei, seip: 1'b1
                               ,mtip: mideleg_lo.mti, stip: 1'b1
                               ,msip: mideleg_lo.msi, ssip: 1'b1
                               ,default: '0};

          unique casez (csr_cmd.csr_addr)
            `declare_csr_case_ro(`PRIV_MODE_U, `CSR_ADDR_CYCLE, cycle, mcycle_r, csr_data_lo)
            // Time must be done by trapping, since we can't stall at this point
            `declare_csr_case_ro(`PRIV_MODE_U, `CSR_ADDR_INSTRET, instret, minstret_r, csr_data_lo)
            `declare_csr_case_rw_mask(`PRIV_MODE_S, `CSR_ADDR_SSTATUS, mstatus, csr_data_li, csr_data_lo, sstatus_wmask_li, sstatus_rmask_li)
            // Read-only because we don't support N-extension
            `declare_csr_case_ro(`PRIV_MODE_S, `CSR_ADDR_SEDELEG, sedeleg, '0, csr_data_lo)
            // Read-only because we don't support N-extension
            `declare_csr_case_ro(`PRIV_MODE_S, `CSR_ADDR_SIDELEG, sideleg, '0, csr_data_lo)
            `declare_csr_case_rw_mask(`PRIV_MODE_S, `CSR_ADDR_SIE, mie, csr_data_li, csr_data_lo, sie_wmask_li, sie_rmask_li)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_STVEC, stvec, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_SCOUNTEREN, scounteren, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_SSCRATCH, sscratch, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_SEPC, sepc, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_SCAUSE, scause, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_STVAL, stval, csr_data_li, csr_data_lo)
            // SIP subset of MIP
            `declare_csr_case_rw_mask(`PRIV_MODE_S, `CSR_ADDR_SIP, mip, csr_data_li, csr_data_lo, sip_wmask_li, sip_rmask_li)
            `declare_csr_case_rw(`PRIV_MODE_S, `CSR_ADDR_SATP, satp, csr_data_li, csr_data_lo)
            // We havr no vendorid currently
            `declare_csr_case_ro(`PRIV_MODE_M, `CSR_ADDR_MVENDORID, mvendorid, '0, csr_data_lo)
            // https://github.com/riscv/riscv-isa-manual/blob/master/marchid.md
            //   Lucky 13 (*v*)
            `declare_csr_case_ro(`PRIV_MODE_M, `CSR_ADDR_MARCHID, marchid, 13, csr_data_lo)
            // 0: Tapeout 0, July 2019
            // 1: Current
            `declare_csr_case_ro(`PRIV_MODE_M, `CSR_ADDR_MIMPID, mimpid, 1, csr_data_lo)
            `declare_csr_case_ro(`PRIV_MODE_M, `CSR_ADDR_MHARTID, mhartid, hartid_i, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MSTATUS, mstatus, csr_data_li, csr_data_lo)
            // MISA is optionally read-write, but all fields are read-only in BlackParrot
            //   64 bit MXLEN, AISU extensions
            `declare_csr_case_ro(`PRIV_MODE_M, `CSR_ADDR_MISA, misa, {2'b10, 36'b0, 26'h140101}, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MEDELEG, medeleg, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MIDELEG, mideleg, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MIE, mie, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MTVEC, mtvec, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MCOUNTEREN, mcounteren, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MIP, mip, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MSCRATCH, mscratch, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MEPC, mepc, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MCAUSE, mcause, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MTVAL, mtval, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_PMPCFG0, pmpcfg0, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_PMPADDR0, pmpaddr0, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_PMPADDR1, pmpaddr1, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_PMPADDR2, pmpaddr2, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_PMPADDR3, pmpaddr3, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MCYCLE, mcycle, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MINSTRET, minstret, csr_data_li, csr_data_lo)
            `declare_csr_case_rw(`PRIV_MODE_M, `CSR_ADDR_MCOUNTINHIBIT, mcountinhibit, csr_data_li, csr_data_lo)
            default: illegal_instr_o = 1'b1;
          endcase
        end

    // Check for access violations
    if (is_s_mode & (csr_cmd.csr_addr == `CSR_ADDR_CYCLE) & ~mcounteren_lo.cy)
      illegal_instr_o = 1'b1;
    if (is_u_mode & (csr_cmd.csr_addr == `CSR_ADDR_CYCLE) & ~scounteren_lo.cy)
      illegal_instr_o = 1'b1;
    if (is_s_mode & (csr_cmd.csr_addr == `CSR_ADDR_INSTRET) & ~mcounteren_lo.ir)
      illegal_instr_o = 1'b1;
    if (is_u_mode & (csr_cmd.csr_addr == `CSR_ADDR_INSTRET) & ~scounteren_lo.ir)
      illegal_instr_o = 1'b1;

    if (timer_int_i)
        mip_li.mtip = 1'b1;

    if (software_int_i)
        mip_li.msip = 1'b1;

    if (external_int_i)
        mip_li.meip = 1'b1;

    if (exception_v_i & exception_ecode_v_li) 
      if (medeleg_lo[exception_ecode_li] & ~is_m_mode)
        begin
          priv_mode_n          = `PRIV_MODE_S;

          mstatus_li.spp       = priv_mode_r;
          mstatus_li.spie      = mstatus_lo.sie;
          mstatus_li.sie       = 1'b0;

          sepc_li              = paddr_width_p'($signed(exception_pc_i));
          stval_li             = exception_ecode_dec_cast_i.illegal_instr 
                                ? exception_instr_i 
                                : paddr_width_p'($signed(exception_vaddr_i));

          scause_li._interrupt = 1'b0;
          scause_li.ecode      = exception_ecode_li;

          trap_v_o            = 1'b1;
        end
      else
        begin
          priv_mode_n          = `PRIV_MODE_M;

          mstatus_li.mpp       = priv_mode_r;
          mstatus_li.mpie      = mstatus_lo.mie;
          mstatus_li.mie       = 1'b0;

          mepc_li              = paddr_width_p'($signed(exception_pc_i));
          mtval_li             = exception_ecode_dec_cast_i.illegal_instr 
                                ? exception_instr_i 
                                : paddr_width_p'($signed(exception_vaddr_i));

          mcause_li._interrupt = 1'b0;
          mcause_li.ecode      = exception_ecode_li;

          trap_v_o             = 1'b1;
        end

    if (exception_icode_v_li)
      if (mideleg_lo[exception_icode_li] & ~is_m_mode)
        begin
          priv_mode_n          = `PRIV_MODE_S;

          mstatus_li.spp       = priv_mode_r;
          mstatus_li.spie      = mstatus_lo.sie;
          mstatus_li.sie       = 1'b0;

          sepc_li              = (exception_v_i & exception_ecode_v_li) 
                                ? paddr_width_p'($signed(exception_pc_i))
                                : paddr_width_p'($signed(interrupt_pc_i));
          stval_li             = '0;
          scause_li._interrupt = 1'b1;
          scause_li.ecode      = exception_icode_li;

          trap_v_o             = 1'b1;
        end
      else
        begin
          priv_mode_n          = `PRIV_MODE_M;

          mstatus_li.mpp       = priv_mode_r;
          mstatus_li.mpie      = mstatus_lo.mie;
          mstatus_li.mie       = 1'b0;

          mepc_li              = (exception_v_i & exception_ecode_v_li) 
                                ? paddr_width_p'($signed(exception_pc_i))
                                : paddr_width_p'($signed(interrupt_pc_i));
          mtval_li             = '0;
          mcause_li._interrupt = 1'b1;
          mcause_li.ecode      = exception_icode_li;

          trap_v_o            = 1'b1;
        end
  end

// CSR slow paths
assign epc_o           = (csr_cmd.csr_op == e_sret) ? sepc_r : mepc_r;
assign tvec_o          = (priv_mode_n == `PRIV_MODE_S) ? stvec_r : mtvec_r;
assign satp_o          = satp_r;
// We only support SV39 so the mode can either be 0(off) or 1(SV39)
assign translation_en_o = ((priv_mode_r < `PRIV_MODE_M) & (satp_r.mode == 1'b1))
                          | (mstatus_lo.mprv & (mstatus_lo.mpp < `PRIV_MODE_M) & (satp_r.mode == 1'b1));

assign csr_cmd_ready_o = 1'b1;
assign data_o          = dword_width_p'(csr_data_lo);
assign v_o             = csr_cmd_v_i;

endmodule: bp_be_csr


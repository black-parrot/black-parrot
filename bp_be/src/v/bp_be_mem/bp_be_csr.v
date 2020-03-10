module bp_be_csr
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam csr_cmd_width_lp = `bp_be_csr_cmd_width
    , localparam ecode_dec_width_lp = `bp_be_ecode_dec_width

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

    , localparam trap_pkt_width_lp = `bp_be_trap_pkt_width(vaddr_width_p)
    )
   (input                               clk_i
    , input                             reset_i

    , input [cfg_bus_width_lp-1:0]      cfg_bus_i
    , output [dword_width_p-1:0]        cfg_csr_data_o
    , output [1:0]                      cfg_priv_data_o

    // CSR instruction interface
    , input [csr_cmd_width_lp-1:0]      csr_cmd_i
    , input                             csr_cmd_v_i
    , output                            csr_cmd_ready_o

    , output [dword_width_p-1:0]        data_o
    , output                            v_o
    , output logic                      illegal_instr_o

    // Misc interface
    , input [core_id_width_p-1:0]       hartid_i
    , input                             instret_i

    , input                             exception_v_i
    , input                             fencei_v_i
    , input [vaddr_width_p-1:0]         exception_pc_i
    , input [vaddr_width_p-1:0]         exception_npc_i
    , input [vaddr_width_p-1:0]         exception_vaddr_i
    , input [instr_width_p-1:0]         exception_instr_i
    , input [ecode_dec_width_lp-1:0]    exception_ecode_dec_i

    , input                             timer_irq_i
    , input                             software_irq_i
    , input                             external_irq_i
    , output                            accept_irq_o
    , output                            single_step_o

    , output [trap_pkt_width_lp-1:0]    trap_pkt_o

    , output                            debug_mode_o
    , output [rv64_priv_width_gp-1:0]   priv_mode_o
    , output [ptag_width_p-1:0]         satp_ppn_o
    , output                            translation_en_o
    , output                            mstatus_sum_o
    , output                            mstatus_mxr_o
    
    // FE Exceptions
    , output logic                      itlb_fill_o
    , output logic                      instr_page_fault_o
    , output logic                      instr_access_fault_o
    , output logic                      instr_misaligned_o
    , output logic                      ebreak_o
    );

// Declare parameterizable structs
`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p); 
`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p/8)

// Casting input and output ports
bp_cfg_bus_s cfg_bus_cast_i;
bp_be_csr_cmd_s csr_cmd;
bp_be_csr_cmd_s cfg_bus_csr_cmd_li;
bp_be_ecode_dec_s exception_ecode_dec_cast_i;
bp_be_trap_pkt_s trap_pkt_cast_o;

assign cfg_bus_csr_cmd_li.csr_op   = cfg_bus_cast_i.csr_r_v ? e_csrrs : e_csrrw;
assign cfg_bus_csr_cmd_li.csr_addr = cfg_bus_cast_i.csr_addr;
assign cfg_bus_csr_cmd_li.data     = cfg_bus_cast_i.csr_r_v ? '0 : cfg_bus_cast_i.csr_data;

assign cfg_bus_cast_i = cfg_bus_i;
assign csr_cmd = (cfg_bus_cast_i.csr_r_v | cfg_bus_cast_i.csr_w_v) ? cfg_bus_csr_cmd_li : csr_cmd_i;
assign exception_ecode_dec_cast_i = exception_ecode_dec_i;
assign trap_pkt_o = trap_pkt_cast_o;

// The muxed and demuxed CSR outputs
logic [dword_width_p-1:0] csr_data_li, csr_data_lo;

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
`declare_csr(dcsr)
`declare_csr(dpc)

wire mgie = (mstatus_r.mie & is_m_mode) | is_s_mode | is_u_mode;
wire sgie = (mstatus_r.sie & is_s_mode) | is_u_mode;

wire mti_v = mie_r.mtie & mip_r.mtip;
wire msi_v = mie_r.msie & mip_r.msip;
wire mei_v = mie_r.meie & mip_r.meip;

wire sti_v = mie_r.stie & mip_r.stip;
wire ssi_v = mie_r.ssie & mip_r.ssip;
wire sei_v = mie_r.seie & mip_r.seip;

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

logic [3:0] m_interrupt_icode_li, s_interrupt_icode_li;
logic       m_interrupt_icode_v_li, s_interrupt_icode_v_li;
bsg_priority_encode
 #(.width_p(ecode_dec_width_lp)
   ,.lo_to_hi_p(1)
   )
 m_interrupt_enc
  (.i(interrupt_icode_dec_li & ~mideleg_lo[0+:ecode_dec_width_lp] & ecode_dec_width_lp'($signed(mgie)))
   ,.addr_o(m_interrupt_icode_li)
   ,.v_o(m_interrupt_icode_v_li)
   );

bsg_priority_encode
 #(.width_p(ecode_dec_width_lp)
   ,.lo_to_hi_p(1)
   )
 s_interrupt_enc
  (.i(interrupt_icode_dec_li & mideleg_lo[0+:ecode_dec_width_lp] & ecode_dec_width_lp'($signed(sgie)))
   ,.addr_o(s_interrupt_icode_li)
   ,.v_o(s_interrupt_icode_v_li)
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

bsg_dff_reset
 #(.width_p(1))
 debug_mode_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(debug_mode_n)
   ,.data_o(debug_mode_r)
   );
assign debug_mode_o = debug_mode_r;

bsg_dff_reset
 #(.width_p(2) 
   ,.reset_val_p(`PRIV_MODE_M)
   )
 priv_mode_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(cfg_bus_cast_i.priv_w_v ? cfg_bus_cast_i.priv_data : priv_mode_n)
   ,.data_o(priv_mode_r)
   );
assign cfg_priv_data_o = priv_mode_r;

assign translation_en_n = ((priv_mode_n < `PRIV_MODE_M) & (satp_li.mode == 4'd8));
bsg_dff_reset
 #(.width_p(1)
   )
 translation_en_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(translation_en_n)
   ,.data_o(translation_en_r)
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

// mip mask
assign mip_wmask_li     = '{meip: 1'b0, seip: 1'b1
                            ,mtip: 1'b0, stip: 1'b1
                            ,msip: 1'b0, ssip: 1'b1
                            ,default: '0
                            };

// sie mask
assign sie_rwmask_li    = mideleg_lo;

// sip mask
assign sip_rmask_li     = mideleg_lo;
assign sip_wmask_li    = '{meip: 1'b0, seip: 1'b0
                            ,mtip: 1'b0, stip: 1'b0
                            ,msip: 1'b0, ssip: mideleg_lo.ssi
                            ,default: '0
                           };

logic exception_v_o, interrupt_v_o, null_trap_v_o, ret_v_o, sfence_v_o;
// CSR data
always_comb
  begin
    debug_mode_n = debug_mode_r;
    priv_mode_n  = priv_mode_r;

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

    dcsr_li = dcsr_lo;
    dpc_li  = dpc_lo;

    exception_v_o    = '0;
    interrupt_v_o    = '0;
    null_trap_v_o    = '0;
    ret_v_o          = '0;
    illegal_instr_o  = '0;
    csr_data_lo      = '0;
    sfence_v_o       = '0;
    
    itlb_fill_o           = '0;
    instr_page_fault_o    = '0;
    instr_access_fault_o  = '0;
    instr_misaligned_o    = '0;
    ebreak_o              = '0;

    if (csr_cmd_v_i | cfg_bus_cast_i.csr_r_v | cfg_bus_cast_i.csr_w_v)
      if (~is_debug_mode & (csr_cmd.csr_op == e_ebreak))
        begin
          ebreak_o = (is_m_mode & ~dcsr_lo.ebreakm) 
                     | (is_s_mode & ~dcsr_lo.ebreaks) 
                     | (is_u_mode & ~dcsr_lo.ebreaku);

          if (~ebreak_o)
            begin
              debug_mode_n   = 1'b1;
              dpc_li         = paddr_width_p'($signed(exception_pc_i));
              dcsr_li.cause  = 1; // Ebreak
              dcsr_li.prv    = priv_mode_r;
            end
        end
      else if (csr_cmd.csr_op == e_sfence_vma)
        begin
          if (is_s_mode & mstatus_lo.tvm)
              illegal_instr_o = 1'b1;
          else
            begin
              sfence_v_o = 1'b1;
            end
        end
      else if (csr_cmd.csr_op == e_dret)
        begin
          priv_mode_n      = dcsr_lo.prv;

          illegal_instr_o  = ~is_debug_mode;
          ret_v_o          = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op == e_mret)
        begin
          if (priv_mode_r < `PRIV_MODE_M)
            illegal_instr_o = 1'b1;
          else
            begin
              priv_mode_n      = mstatus_lo.mpp;

              mstatus_li.mpp   = `PRIV_MODE_U;
              mstatus_li.mpie  = 1'b1;
              mstatus_li.mie   = mstatus_lo.mpie;
              mstatus_li.mprv  = (priv_mode_n < `PRIV_MODE_M) ? '0 : mstatus_li.mprv;

              ret_v_o          = 1'b1;
            end
        end
      else if (csr_cmd.csr_op == e_sret)
        begin
          if ((is_s_mode & mstatus_lo.tsr) || (priv_mode_r < `PRIV_MODE_S))
            illegal_instr_o = 1'b1;
          else
            begin
              priv_mode_n      = {1'b0, mstatus_lo.spp};
              
              mstatus_li.spp   = `PRIV_MODE_U;
              mstatus_li.spie  = 1'b1;
              mstatus_li.sie   = mstatus_lo.spie;
              mstatus_li.mprv  = (priv_mode_n < `PRIV_MODE_M) ? '0 : mstatus_li.mprv;

              ret_v_o          = 1'b1;
            end
        end
      else if (csr_cmd.csr_op == e_itlb_fill)
        begin
          itlb_fill_o = 1'b1;
        end
      else if (csr_cmd.csr_op == e_op_instr_page_fault)
        begin
          instr_page_fault_o = 1'b1;
        end
      else if (csr_cmd.csr_op == e_op_instr_access_fault)
        begin
          instr_access_fault_o = 1'b1;
        end
      else if (csr_cmd.csr_op == e_op_instr_misaligned)
        begin
          instr_misaligned_o = 1'b1;
        end
      else if (csr_cmd.csr_op == e_op_take_interrupt)
        begin
          if (~is_debug_mode & m_interrupt_icode_v_li)
            begin
              priv_mode_n          = `PRIV_MODE_M;

              mstatus_li.mpp       = priv_mode_r;
              mstatus_li.mpie      = mstatus_lo.mie;
              mstatus_li.mie       = 1'b0;

              mepc_li              = paddr_width_p'($signed(exception_pc_i));
              mtval_li             = '0;
              mcause_li._interrupt = 1'b1;
              mcause_li.ecode      = m_interrupt_icode_li;

              exception_v_o        = 1'b0;
              interrupt_v_o        = 1'b1;
              ret_v_o              = 1'b0;
            end
          else if (~is_debug_mode & s_interrupt_icode_v_li)
            begin
              priv_mode_n          = `PRIV_MODE_S;

              mstatus_li.spp       = priv_mode_r;
              mstatus_li.spie      = mstatus_lo.sie;
              mstatus_li.sie       = 1'b0;

              sepc_li              = paddr_width_p'($signed(exception_pc_i));
              stval_li             = '0;
              scause_li._interrupt = 1'b1;
              scause_li.ecode      = s_interrupt_icode_li;

              exception_v_o        = 1'b0;
              interrupt_v_o        = 1'b1;
              ret_v_o              = 1'b0;
            end
          else
            begin
              // The interrupt has gone away by the time we went to take it
              null_trap_v_o        = 1'b1;
            end
        end
      else if (csr_cmd.csr_op == e_wfi)
        begin
          illegal_instr_o = mstatus_lo.tw;
        end
      else if (csr_cmd.csr_op inside {e_ebreak, e_ecall})
      begin
          // ECALL is implemented as part of the exception cause vector
          // EBreak is implemented below
        end
      // Check for access violations
      else if (is_s_mode & mstatus_lo.tvm & (csr_cmd.csr_addr == `CSR_ADDR_SATP))
        illegal_instr_o = 1'b1;
      else if (is_s_mode & (csr_cmd.csr_addr == `CSR_ADDR_CYCLE) & ~mcounteren_lo.cy)
        illegal_instr_o = 1'b1;
      else if (is_u_mode & (csr_cmd.csr_addr == `CSR_ADDR_CYCLE) & ~scounteren_lo.cy)
        illegal_instr_o = 1'b1;
      else if (is_s_mode & (csr_cmd.csr_addr == `CSR_ADDR_INSTRET) & ~mcounteren_lo.ir)
        illegal_instr_o = 1'b1;
      else if (is_u_mode & (csr_cmd.csr_addr == `CSR_ADDR_INSTRET) & ~scounteren_lo.ir)
        illegal_instr_o = 1'b1;
      else if (priv_mode_r < csr_cmd.csr_addr[9:8])
        illegal_instr_o = 1'b1;
      else
        begin
            // Read case
            unique casez (csr_cmd.csr_addr)
              `CSR_ADDR_CYCLE  : csr_data_lo = mcycle_lo;
              // Time must be done by trapping, since we can't stall at this point
              `CSR_ADDR_INSTRET: csr_data_lo = minstret_lo;
              // SSTATUS subset of MSTATUS
              `CSR_ADDR_SSTATUS: csr_data_lo = mstatus_lo & sstatus_rmask_li;
              // Read-only because we don't support N-extension
              // Read-only because we don't support N-extension
              `CSR_ADDR_SEDELEG: csr_data_lo = '0;
              `CSR_ADDR_SIDELEG: csr_data_lo = '0;
              `CSR_ADDR_SIE: csr_data_lo = mie_lo & sie_rwmask_li;
              `CSR_ADDR_STVEC: csr_data_lo = stvec_lo;
              `CSR_ADDR_SCOUNTEREN: csr_data_lo = scounteren_lo;
              `CSR_ADDR_SSCRATCH: csr_data_lo = sscratch_lo;
              `CSR_ADDR_SEPC: csr_data_lo = sepc_lo;
              `CSR_ADDR_SCAUSE: csr_data_lo = scause_lo;
              `CSR_ADDR_STVAL: csr_data_lo = stval_lo;
              // SIP subset of MIP
              `CSR_ADDR_SIP: csr_data_lo = mip_lo & sip_rmask_li;
              `CSR_ADDR_SATP: csr_data_lo = satp_lo;
              // We havr no vendorid currently
              `CSR_ADDR_MVENDORID: csr_data_lo = '0;
              // https://github.com/riscv/riscv-isa-manual/blob/master/marchid.md
              //   Lucky 13 (*v*)
              `CSR_ADDR_MARCHID: csr_data_lo = 64'd13;
              // 0: Tapeout 0, July 2019
              // 1: Current
              `CSR_ADDR_MIMPID: csr_data_lo = 64'd1;
              `CSR_ADDR_MHARTID: csr_data_lo = hartid_i;
              `CSR_ADDR_MSTATUS: csr_data_lo = mstatus_lo;
              // MISA is optionally read-write, but all fields are read-only in BlackParrot
              //   64 bit MXLEN, AISU extensions
              `CSR_ADDR_MISA: csr_data_lo = {2'b10, 36'b0, 26'h140101};
              `CSR_ADDR_MEDELEG: csr_data_lo = medeleg_lo;
              `CSR_ADDR_MIDELEG: csr_data_lo = mideleg_lo;
              `CSR_ADDR_MIE: csr_data_lo = mie_lo;
              `CSR_ADDR_MTVEC: csr_data_lo = mtvec_lo;
              `CSR_ADDR_MCOUNTEREN: csr_data_lo = mcounteren_lo;
              `CSR_ADDR_MIP: csr_data_lo = mip_lo;
              `CSR_ADDR_MSCRATCH: csr_data_lo = mscratch_lo;
              `CSR_ADDR_MEPC: csr_data_lo = mepc_lo;
              `CSR_ADDR_MCAUSE: csr_data_lo = mcause_lo;
              `CSR_ADDR_MTVAL: csr_data_lo = mtval_lo;
              `CSR_ADDR_PMPCFG0: csr_data_lo = pmpcfg0_lo;
              `CSR_ADDR_PMPADDR0: csr_data_lo = pmpaddr0_lo;
              `CSR_ADDR_PMPADDR1: csr_data_lo = pmpaddr1_lo;
              `CSR_ADDR_PMPADDR2: csr_data_lo = pmpaddr2_lo;
              `CSR_ADDR_PMPADDR3: csr_data_lo = pmpaddr3_lo;
              `CSR_ADDR_MCYCLE: csr_data_lo = mcycle_lo;
              `CSR_ADDR_MINSTRET: csr_data_lo = minstret_lo;
              `CSR_ADDR_MCOUNTINHIBIT: csr_data_lo = mcountinhibit_lo;
              `CSR_ADDR_DCSR: csr_data_lo = dcsr_lo;
              `CSR_ADDR_DPC: csr_data_lo = dpc_lo;
              default: illegal_instr_o = 1'b1;
            endcase
            // Write case
            unique casez (csr_cmd.csr_addr)
              `CSR_ADDR_CYCLE  : mcycle_li = csr_data_li;
              // Time must be done by trapping, since we can't stall at this point
              `CSR_ADDR_INSTRET: minstret_li = csr_data_li;
              // SSTATUS subset of MSTATUS
              `CSR_ADDR_SSTATUS: mstatus_li = (mstatus_lo & ~sstatus_wmask_li) | (csr_data_li & sstatus_wmask_li);
              // Read-only because we don't support N-extension
              // Read-only because we don't support N-extension
              `CSR_ADDR_SEDELEG: begin end
              `CSR_ADDR_SIDELEG: begin end
              `CSR_ADDR_SIE: mie_li = (mie_lo & ~sie_rwmask_li) | (csr_data_li & sie_rwmask_li);
              `CSR_ADDR_STVEC: stvec_li = csr_data_li;
              `CSR_ADDR_SCOUNTEREN: scounteren_li = csr_data_li;
              `CSR_ADDR_SSCRATCH: sscratch_li = csr_data_li;
              `CSR_ADDR_SEPC: sepc_li = csr_data_li;
              `CSR_ADDR_SCAUSE: scause_li = csr_data_li;
              `CSR_ADDR_STVAL: stval_li = csr_data_li;
              // SIP subset of MIP
              `CSR_ADDR_SIP: mip_li = (mip_lo & ~sip_wmask_li) | (csr_data_li & sip_wmask_li);
              `CSR_ADDR_SATP: satp_li = csr_data_li;
              `CSR_ADDR_MVENDORID: begin end
              `CSR_ADDR_MARCHID: begin end
              `CSR_ADDR_MIMPID: begin end
              `CSR_ADDR_MHARTID: begin end
              `CSR_ADDR_MSTATUS: mstatus_li = csr_data_li;
              `CSR_ADDR_MISA: begin end
              `CSR_ADDR_MEDELEG: medeleg_li = csr_data_li;
              `CSR_ADDR_MIDELEG: mideleg_li = csr_data_li;
              `CSR_ADDR_MIE: mie_li = csr_data_li;
              `CSR_ADDR_MTVEC: mtvec_li = csr_data_li;
              `CSR_ADDR_MCOUNTEREN: mcounteren_li = csr_data_li;
              `CSR_ADDR_MIP: mip_li = (mip_lo & ~mip_wmask_li) | (csr_data_li & mip_wmask_li);
              `CSR_ADDR_MSCRATCH: mscratch_li = csr_data_li;
              `CSR_ADDR_MEPC: mepc_li = csr_data_li;
              `CSR_ADDR_MCAUSE: mcause_li = csr_data_li;
              `CSR_ADDR_MTVAL: mtval_li = csr_data_li;
              `CSR_ADDR_PMPCFG0: pmpcfg0_li = csr_data_li;
              `CSR_ADDR_PMPADDR0: pmpaddr0_li = csr_data_li;
              `CSR_ADDR_PMPADDR1: pmpaddr1_li = csr_data_li;
              `CSR_ADDR_PMPADDR2: pmpaddr2_li = csr_data_li;
              `CSR_ADDR_PMPADDR3: pmpaddr3_li = csr_data_li;
              `CSR_ADDR_MCYCLE: mcycle_li = csr_data_li;
              `CSR_ADDR_MINSTRET: minstret_li = csr_data_li;
              `CSR_ADDR_MCOUNTINHIBIT: mcountinhibit_li = csr_data_li;
              `CSR_ADDR_DCSR: dcsr_li = csr_data_li;
              `CSR_ADDR_DPC: dpc_li = csr_data_li;
              default: illegal_instr_o = 1'b1;
            endcase
        end

    mip_li.mtip = timer_irq_i;
    mip_li.msip = software_irq_i;
    mip_li.meip = external_irq_i;

    if (~is_debug_mode & exception_v_i & exception_ecode_v_li)
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

          exception_v_o        = 1'b1;
          interrupt_v_o        = 1'b0;
          ret_v_o              = 1'b0;
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

          exception_v_o        = 1'b1;
          interrupt_v_o        = 1'b0;
          ret_v_o              = 1'b0;
        end

      if (~is_debug_mode & exception_v_i & dcsr_lo.step)
        begin
          debug_mode_n = 1'b1;
          dpc_li        = paddr_width_p'($signed(exception_npc_i));
          dcsr_li.cause = 4;
          dcsr_li.prv   = priv_mode_r;
        end
  end

// Debug Mode masks all interrupts
assign accept_irq_o = ~is_debug_mode & (m_interrupt_icode_v_li | s_interrupt_icode_v_li);

// CSR slow paths
assign satp_ppn_o       = satp_r.ppn;

assign mstatus_sum_o = mstatus_lo.sum;
assign mstatus_mxr_o = mstatus_lo.mxr;

assign single_step_o = ~is_debug_mode & dcsr_lo.step;

assign csr_cmd_ready_o = 1'b1;
assign data_o          = dword_width_p'(csr_data_lo);
assign v_o             = csr_cmd_v_i;

assign cfg_csr_data_o = csr_data_lo;
assign cfg_priv_data_o = priv_mode_r;

assign trap_pkt_cast_o.epc              = (csr_cmd.csr_op == e_sret)
                                          ? sepc_r
                                          : (csr_cmd.csr_op == e_mret)
                                            ? mepc_r
                                            : dpc_r;
assign trap_pkt_cast_o.tvec             = (priv_mode_n == `PRIV_MODE_S) ? stvec_r : mtvec_r;
assign trap_pkt_cast_o.cause            = (priv_mode_n == `PRIV_MODE_S) ? scause_li : mcause_li;
assign trap_pkt_cast_o.priv_n           = priv_mode_n;
assign trap_pkt_cast_o.translation_en_n = translation_en_n;
// TODO: Find more solid invariant
assign trap_pkt_cast_o.fencei           = fencei_v_i;
assign trap_pkt_cast_o.sfence           = sfence_v_o;
assign trap_pkt_cast_o.exception        = exception_v_o;
assign trap_pkt_cast_o._interrupt       = interrupt_v_o;
assign trap_pkt_cast_o.null_trap        = null_trap_v_o;
assign trap_pkt_cast_o.eret             = ret_v_o;

assign priv_mode_o      = priv_mode_r;
assign translation_en_o = translation_en_r
                          | (mstatus_lo.mprv & (mstatus_lo.mpp < `PRIV_MODE_M) & (satp_lo.mode == 4'd8));

endmodule


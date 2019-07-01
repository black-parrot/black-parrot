module bp_be_csr
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    , localparam fu_op_width_lp = `bp_be_fu_op_width
    , localparam csr_cmd_width_lp = `bp_be_csr_cmd_width
    , localparam ecode_dec_width_lp = `bp_be_ecode_dec_width

    , localparam mepc_width_lp  = `bp_mepc_width
    , localparam mtvec_width_lp = `bp_mtvec_width
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

    , output [rv64_priv_width_gp-1:0] priv_mode_o
    , output logic                   trap_v_o
    , output logic                   ret_v_o
    , output [mepc_width_lp-1:0]     mepc_o
    , output [mtvec_width_lp-1:0]    mtvec_o
    , output [satp_width_lp-1:0]     satp_o
    , output                         translation_en_o
    , output logic                   tlb_fence_o
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

logic [1:0] priv_mode_n, priv_mode_r;

assign priv_mode_o = priv_mode_r;

wire tint_m_to_m  = (priv_mode_r == `RV64_PRIV_MODE_M) & mstatus_r.mie & mie_r.mtie & mip_r.mtip;
wire sint_m_to_m  = (priv_mode_r == `RV64_PRIV_MODE_M) & mstatus_r.mie & mie_r.msie & mip_r.msip;
wire eint_m_to_m  = (priv_mode_r == `RV64_PRIV_MODE_M) & mstatus_r.mie & mie_r.meie & mip_r.meip;
wire int_m_to_m   = tint_m_to_m | sint_m_to_m | eint_m_to_m;

wire tint_s_to_m  = (priv_mode_r == `RV64_PRIV_MODE_S) & mstatus_r.sie & mie_r.stie & mip_r.stip;
wire sint_s_to_m  = (priv_mode_r == `RV64_PRIV_MODE_S) & mstatus_r.sie & mie_r.ssie & mip_r.ssip;
wire eint_s_to_m  = (priv_mode_r == `RV64_PRIV_MODE_S) & mstatus_r.sie & mie_r.seie & mip_r.seip;
wire int_s_to_m   = tint_s_to_m | sint_s_to_m | eint_s_to_m;

wire tint_u_to_m  = (priv_mode_r == `RV64_PRIV_MODE_U) & mstatus_r.uie & mie_r.utie & mip_r.utip;
wire sint_u_to_m  = (priv_mode_r == `RV64_PRIV_MODE_U) & mstatus_r.uie & mie_r.usie & mip_r.usip;
wire eint_u_to_m  = (priv_mode_r == `RV64_PRIV_MODE_U) & mstatus_r.uie & mie_r.ueie & mip_r.ueip;
wire int_u_to_m   = tint_u_to_m | sint_u_to_m | eint_u_to_m;

wire int_to_m = int_m_to_m | int_s_to_m | int_u_to_m;

logic [3:0] exception_ecode_li;
logic       exception_ecode_v_li;
bsg_priority_encode 
 #(.width_p(ecode_dec_width_lp)
   ,.lo_to_hi_p(1)
   )
 mcause_enc
  (.i(exception_ecode_dec_i)
   ,.addr_o(exception_ecode_li)
   ,.v_o(exception_ecode_v_li)
   );

// Compute input CSR data
always_comb 
  begin
    unique casez (csr_cmd.csr_op)
      e_csrrw  : csr_data_li =  csr_cmd.data;
      e_csrrs  : csr_data_li =  csr_cmd.data | csr_data_lo;
      e_csrrc  : csr_data_li = ~csr_cmd.data & csr_data_lo;

      e_csrrwi : csr_data_li =  csr_cmd.data[4:0];
      e_csrrsi : csr_data_li =  csr_cmd.data[4:0] | csr_data_lo;
      e_csrrci : csr_data_li = ~csr_cmd.data[4:0] & csr_data_lo;
      default  : csr_data_li = '0;
    endcase
  end

bp_satp_s       satp_n    , satp_r;

bp_mstatus_s    mstatus_n , mstatus_r;
bp_mie_s        mie_n     , mie_r;
bp_mtvec_s      mtvec_n   , mtvec_r;

bp_mscratch_s   mscratch_n, mscratch_r;
bp_mepc_s       mepc_n    , mepc_r;
bp_mcause_s     mcause_n  , mcause_r;
bp_mtval_s      mtval_n   , mtval_r;
bp_mip_s        mip_n     , mip_r;

bp_pmpcfg_s     pmpcfg0_n , pmpcfg0_r;
bp_pmpaddr_s    pmpaddr0_n, pmpaddr0_r;
bp_pmpaddr_s    pmpaddr1_n, pmpaddr1_r;
bp_pmpaddr_s    pmpaddr2_n, pmpaddr2_r;
bp_pmpaddr_s    pmpaddr3_n, pmpaddr3_r;

bp_mcounter_s   mcycle_n  , mcycle_r;
bp_mcounter_s   minstret_n, minstret_r;

rv64_satp_s     satp_li   , satp_lo;

rv64_mstatus_s  mstatus_li, mstatus_lo;
rv64_mie_s      mie_li    , mie_lo;
rv64_mtvec_s    mtvec_li  , mtvec_lo;

rv64_mscratch_s mscratch_li, mscratch_lo;
rv64_mepc_s     mepc_li    , mepc_lo;
rv64_mcause_s   mcause_li  , mcause_lo;
rv64_mtval_s    mtval_li   , mtval_lo;
rv64_mip_s      mip_li     , mip_lo;

rv64_pmpcfg_s   pmpcfg0_li , pmpcfg0_lo;
rv64_pmpaddr_s  pmpaddr0_li, pmpaddr0_lo;
rv64_pmpaddr_s  pmpaddr1_li, pmpaddr1_lo;
rv64_pmpaddr_s  pmpaddr2_li, pmpaddr2_lo;
rv64_pmpaddr_s  pmpaddr3_li, pmpaddr3_lo;

rv64_mcounter_s mcycle_li  , mcycle_lo;
rv64_mcounter_s minstret_li, minstret_lo;

//synopsys sync_set_reset "reset_i"
always_ff @(posedge clk_i)
  begin
    if (reset_i)
      begin
        priv_mode_r <= `RV64_PRIV_MODE_M;

        satp_r      <= '0;

        mstatus_r   <= '0;
        mie_r       <= '0;
        mtvec_r     <= '0;

        mscratch_r  <= '0;
        mepc_r      <= '0;
        mcause_r    <= '0;
        mtval_r     <= '0;
        mip_r       <= '0;

        pmpcfg0_r   <= '0;
        pmpaddr0_r  <= '0;
        pmpaddr1_r  <= '0;
        pmpaddr2_r  <= '0;
        pmpaddr3_r  <= '0;

        mcycle_r    <= '0;
        minstret_r  <= '0;
      end
    else
      begin
        priv_mode_r <= priv_mode_n;

        satp_r      <= satp_n;

        mstatus_r   <= mstatus_n;
        mie_r       <= mie_n;
        mtvec_r     <= mtvec_n;

        mscratch_r  <= mscratch_n;
        mepc_r      <= mepc_n;
        mcause_r    <= mcause_n;
        mtval_r     <= mtval_n;
        mip_r       <= mip_n;

        pmpcfg0_r   <= pmpcfg0_n;
        pmpaddr0_r  <= pmpaddr0_n;
        pmpaddr1_r  <= pmpaddr1_n;
        pmpaddr2_r  <= pmpaddr2_n;
        pmpaddr3_r  <= pmpaddr3_n;

        mcycle_r    <= mcycle_n;
        minstret_r  <= minstret_n;
      end
  end

// CSR data
always_comb
  begin
    priv_mode_n = priv_mode_r;

    satp_n     = satp_r;

    mstatus_n  = mstatus_r;
    mie_n      = mie_r;
    mtvec_n    = mtvec_r;

    mscratch_n = mscratch_r;
    mepc_n     = mepc_r;
    mcause_n   = mcause_r;
    mtval_n    = mtval_r;
    mip_n      = mip_r;

    pmpcfg0_n  = pmpcfg0_r;
    pmpaddr0_n = pmpaddr0_r;
    pmpaddr1_n = pmpaddr1_r;
    pmpaddr2_n = pmpaddr2_r;
    pmpaddr3_n = pmpaddr3_r;

    mcycle_n   = mcycle_r   + dword_width_p'(1);
    minstret_n = minstret_r + dword_width_p'(instret_i);

    trap_v_o        = '0;
    ret_v_o         = '0;
    illegal_instr_o = '0;
    csr_data_lo     = '0;
    tlb_fence_o     = '0;
        
    if (csr_cmd_v_i)
      if (csr_cmd.csr_op == e_sfence_vma)
        begin
          illegal_instr_o = (priv_mode_r < `RV64_PRIV_MODE_S);
          tlb_fence_o     = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op == e_mret)
        begin
          priv_mode_n     = mstatus_r.mpp;

          mstatus_n.mpp   = `RV64_PRIV_MODE_M; // Should be U when U-mode is supported
          mstatus_n.mpie  = 1'b1;
          mstatus_n.mie   = mstatus_r.mpie;

          illegal_instr_o = (priv_mode_r < `RV64_PRIV_MODE_M);
          ret_v_o         = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op == e_sret)
        begin
          priv_mode_n     = {1'b0, mstatus_r.spp};
          
          mstatus_n.spp   = `RV64_PRIV_MODE_M; // Should be U when U-mode is supported
          mstatus_n.spie  = 1'b1;
          mstatus_n.sie   = mstatus_r.spie;

          illegal_instr_o = (priv_mode_r < `RV64_PRIV_MODE_S);
          ret_v_o         = ~illegal_instr_o;
        end
      else if (csr_cmd.csr_op == e_uret)
        begin
          priv_mode_n     = `RV64_PRIV_MODE_U;
          
          mstatus_n.upie  = 1'b1;
          mstatus_n.uie   = mstatus_r.upie;

          ret_v_o         = 1'b1;
        end
      else if (csr_cmd.csr_op inside {e_ebreak, e_ecall, e_wfi})
        begin
          // TODO: NOPs for now. EBREAK and WFI are likely to remain a NOP for a while, whereas
          //   ECALL should be implemented
        end
      else 
        begin
          unique casez (csr_cmd.csr_addr)
            `RV64_CSR_ADDR_SATP: 
              begin
                satp_li     = rv64_satp_s'(csr_data_li);
                satp_n      = `compress_satp_s(satp_li);
                satp_lo     = `decompress_satp_s(satp_r);
                csr_data_lo = satp_lo;
              end
            `RV64_CSR_ADDR_MISA:
              begin
                // 64 bit MXLEN, AISU extensions
                csr_data_lo = {2'b10, 36'b0, 26'h140101};
              end
            `RV64_CSR_ADDR_MVENDORID:
              begin
                csr_data_lo = '0;
              end
            `RV64_CSR_ADDR_MARCHID:
              begin
                csr_data_lo = '0;
              end
            `RV64_CSR_ADDR_MIMPID:
              begin
                csr_data_lo = '0;
              end
            `RV64_CSR_ADDR_MHARTID:
              begin
                csr_data_lo = dword_width_p'(hartid_i);
              end
            `RV64_CSR_ADDR_MSTATUS: 
              begin
                mstatus_li  = rv64_mstatus_s'(csr_data_li);
                mstatus_n   = `compress_mstatus_s(mstatus_li);
                mstatus_lo  = `decompress_mstatus_s(mstatus_r);
                csr_data_lo = mstatus_lo;
              end
            `RV64_CSR_ADDR_MTVEC: 
              begin
                mtvec_li    = rv64_mtvec_s'(csr_data_li);
                mtvec_n     = `compress_mtvec_s(mtvec_li);
                mtvec_lo    = `decompress_mtvec_s(mtvec_r);
                csr_data_lo = mtvec_lo;
              end
            `RV64_CSR_ADDR_MEDELEG:
              begin
                csr_data_lo = dword_width_p'(0);
              end
            `RV64_CSR_ADDR_MIDELEG:
              begin
                csr_data_lo = dword_width_p'(0);
              end
            `RV64_CSR_ADDR_MIP: 
              begin
                mip_li      = rv64_mip_s'(csr_data_li);
                mip_n       = `compress_mip_s(mip_li);
                mip_lo      = `decompress_mip_s(mip_r);
                csr_data_lo = mip_lo;
              end
            `RV64_CSR_ADDR_MIE: 
              begin
                mie_li      = rv64_mie_s'(csr_data_li);
                mie_n       = `compress_mie_s(mie_li);
                mie_lo      = `decompress_mie_s(mie_r);
                csr_data_lo = mie_lo;
              end
            `RV64_CSR_ADDR_MCOUNTEREN:
              begin
                csr_data_lo = dword_width_p'(0);
              end
            `RV64_CSR_ADDR_MSCRATCH: 
              begin
                mscratch_li = rv64_mscratch_s'(csr_data_li);
                mscratch_n  = `compress_mscratch_s(mscratch_li);
                mscratch_lo = `decompress_mscratch_s(mscratch_r);
                csr_data_lo = mscratch_lo;
              end
            `RV64_CSR_ADDR_MEPC: 
              begin
                mepc_li     = rv64_mepc_s'(csr_data_li);
                mepc_n      = `compress_mepc_s(mepc_li);
                mepc_lo     = `decompress_mepc_s(mepc_r);
                csr_data_lo = mepc_lo;
              end
            `RV64_CSR_ADDR_MCAUSE: 
              begin
                mcause_li   = rv64_mcause_s'(csr_data_li);
                mcause_n    = `compress_mcause_s(mcause_li);
                mcause_lo   = `decompress_mcause_s(mcause_r);
                csr_data_lo = mcause_lo;
              end
            `RV64_CSR_ADDR_MTVAL: 
              begin
                mtval_li    = rv64_mtval_s'(csr_data_li);
                mtval_n     = `compress_mtval_s(mtval_li);
                mtval_lo    = `decompress_mtval_s(mtval_r);
                csr_data_lo = mtval_lo;
              end
            `RV64_CSR_ADDR_PMPCFG0: 
              begin
                pmpcfg0_li  = rv64_pmpcfg_s'(csr_data_li);
                pmpcfg0_n   = `compress_pmpcfg_s(pmpcfg0_li);
                pmpcfg0_lo  = `decompress_pmpcfg_s(pmpcfg0_r);
                csr_data_lo = pmpcfg0_lo;
              end
            `RV64_CSR_ADDR_PMPADDR0: 
              begin
                pmpaddr0_li = rv64_pmpaddr_s'(csr_data_li);
                pmpaddr0_n  = `compress_pmpaddr_s(pmpaddr0_li);
                pmpaddr0_lo = `decompress_pmpaddr_s(pmpaddr0_r);
                csr_data_lo = pmpaddr0_lo;
              end
            `RV64_CSR_ADDR_PMPADDR1: 
              begin
                pmpaddr1_li = rv64_pmpaddr_s'(csr_data_li);
                pmpaddr1_n  = `compress_pmpaddr_s(pmpaddr1_li);
                pmpaddr1_lo = `decompress_pmpaddr_s(pmpaddr1_r);
                csr_data_lo = pmpaddr1_lo;
              end
            `RV64_CSR_ADDR_PMPADDR2: 
              begin
                pmpaddr2_li = rv64_pmpaddr_s'(csr_data_li);
                pmpaddr2_n  = `compress_pmpaddr_s(pmpaddr2_li);
                pmpaddr2_lo = `decompress_pmpaddr_s(pmpaddr2_r);
                csr_data_lo = pmpaddr2_lo;
              end
            `RV64_CSR_ADDR_PMPADDR3: 
              begin
                pmpaddr3_li = rv64_pmpaddr_s'(csr_data_li);
                pmpaddr3_n  = `compress_pmpaddr_s(pmpaddr3_li);
                pmpaddr3_lo = `decompress_pmpaddr_s(pmpaddr3_r);
                csr_data_lo = pmpaddr3_lo;
              end
            `RV64_CSR_ADDR_MCYCLE: 
              begin
                mcycle_li   = rv64_mcounter_s'(csr_data_li);
                mcycle_n    = `compress_mcycle_s(mcycle_li);
                mcycle_lo   = `decompress_mcounter_s(mcycle_r);
                csr_data_lo = mcycle_lo;
              end
            `RV64_CSR_ADDR_MINSTRET: 
              begin
                mcycle_li   = rv64_mcounter_s'(csr_data_li);
                minstret_n  = `compress_mcounter_s(minstret_li);
                minstret_lo = `decompress_mcounter_s(minstret_r);
                csr_data_lo = minstret_lo;
              end
            `BP_CSR_ADDR_UFINISH:
              begin
                // Needed as a patch for using the same termination sequence for spike
                //   and BP.  Implemented as nop so we don't choke. Ideally, we'll hack in 
                //   our MMIO host controller into spike.
                csr_data_lo = '0;
              end
            default : illegal_instr_o = 1'b1;
          endcase
        end

    if (timer_int_i)
        mip_li.mtip = 1'b1;

    if (software_int_i)
        mip_li.msip = 1'b1;

    if (external_int_i)
        mip_li.meip = 1'b1;

    if (exception_v_i & exception_ecode_v_li) 
      begin
        priv_mode_n         = `RV64_PRIV_MODE_M;

        mstatus_n.mpp       = priv_mode_r;
        mstatus_n.mpie      = mstatus_r.mie;
        mstatus_n.mie       = 1'b0;

        mepc_n              = exception_pc_i;
        mtval_n             = exception_ecode_dec_cast_i.illegal_instr ? exception_instr_i : exception_vaddr_i;

        mcause_n._interrupt = 1'b0;
        mcause_n.ecode      = exception_ecode_li;

        trap_v_o            = 1'b1;
      end

    if (int_to_m)
      begin
        priv_mode_n         = `RV64_PRIV_MODE_M;

        mstatus_n.mpp       = priv_mode_r;
        mstatus_n.mpie      = mstatus_r.mie;
        mstatus_n.mie       = 1'b0;

        mepc_n              = (exception_v_i & exception_ecode_v_li) ? exception_pc_i : 64'(interrupt_pc_i);
        mtval_n             = '0;
        mcause_n._interrupt = 1'b1;
        // I'm sure there's a more clever way to encode this. Revisit once 
        //   we're implementing interrupts in other privilege modes.
        // The values are based on mcause from the privileged spec.
        // The priority of interrupts is MEI, MSI, MTI, SEI, SSI, STI, UEI, USI, UTI
        // Software interrupts are in the bottom 5 bits so they can be written by an
        //   immediate.  With some bit swizzling, we could reduce this to an & and pencode.
        mcause_n.ecode      = mip_r.meip
                              ? 4'd11
                              : mip_r.msip
                                ? 4'd3
                                : mip_r.mtip
                                  ? 4'd7
                                  : '0; // Should not get here

        trap_v_o            = 1'b1;
      end
  end

// CSR slow paths
assign mepc_o           = mepc_r;
assign mtvec_o          = mtvec_r;
assign satp_o           = satp_r;
// We only support SV39 so the mode can either be 0(off) or 1(SV39)
assign translation_en_o = (priv_mode_r < `RV64_PRIV_MODE_M) & (satp_r.mode == 1'b1);

assign csr_cmd_ready_o = 1'b1;
assign data_o          = dword_width_p'(csr_data_lo);
assign v_o             = csr_cmd_v_i;

endmodule : bp_be_csr


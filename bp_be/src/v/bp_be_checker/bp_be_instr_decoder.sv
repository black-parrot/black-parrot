/**
 *
 * Name:
 *   bp_be_instr_decode.v
 *
 * Description:
 *   BlackParrot instruction decoder for translating RISC-V instructions into pipeline control
 *     signals. Currently supports most of rv64i with the exception of fences and csrs.
 *
 * Notes:
 *   We may want to break this up into a decoder for each standard extension.
 *   Each pipe may need different signals. Use a union in decode_s to save bits?
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_instr_decoder
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam instr_width_lp = rv64_instr_width_gp
   , localparam decode_width_lp = $bits(bp_be_decode_s)
   , localparam decode_info_width_lp = `bp_be_decode_info_width
   )
  (input [instr_width_lp-1:0]           instr_i
   , input [decode_info_width_lp-1:0]   decode_info_i

   , output logic [decode_width_lp-1:0] decode_o
   , output logic                       illegal_instr_o
   , output logic                       ecall_m_o
   , output logic                       ecall_s_o
   , output logic                       ecall_u_o
   , output logic                       ebreak_o
   , output logic                       dbreak_o
   , output logic                       dret_o
   , output logic                       mret_o
   , output logic                       sret_o
   , output logic                       wfi_o
   , output logic                       sfence_vma_o

   , output logic [dword_width_gp-1:0]  imm_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  rv64_instr_fmatype_s instr;
  bp_be_decode_s decode_cast_o;
  bp_be_decode_info_s decode_info_cast_i;

  assign instr              = instr_i;
  assign decode_info_cast_i = decode_info_i;
  assign decode_o           = decode_cast_o;

  // Decode logic
  always_comb
    begin
      decode_cast_o = '0;

      illegal_instr_o = '0;
      ecall_m_o       = '0;
      ecall_s_o       = '0;
      ecall_u_o       = '0;
      ebreak_o        = '0;
      dbreak_o        = '0;
      dret_o          = '0;
      mret_o          = '0;
      sret_o          = '0;
      wfi_o           = '0;
      sfence_vma_o    = '0;

      unique casez (instr.opcode)
        `RV64_OP_OP, `RV64_OP_32_OP:
          begin
            if (instr inside {`RV64_MUL, `RV64_MULW})
              decode_cast_o.pipe_mul_v = 1'b1;
            else if (instr inside {`RV64_DIV, `RV64_DIVU, `RV64_DIVW, `RV64_DIVUW
                                   ,`RV64_REM, `RV64_REMU, `RV64_REMW, `RV64_REMUW
                                   })
              begin
                decode_cast_o.pipe_long_v = 1'b1;
                decode_cast_o.late_iwb_v  = (instr.rd_addr != '0);
              end
            else
              decode_cast_o.pipe_int_v = 1'b1;

            // The writeback for long latency ops comes out of band
            decode_cast_o.irf_w_v    = ~decode_cast_o.late_iwb_v & (instr.rd_addr != '0);
            decode_cast_o.opw_v      = (instr.opcode == `RV64_OP_32_OP);
            unique casez (instr)
              `RV64_ADD, `RV64_ADDW : decode_cast_o.fu_op = e_int_op_add;
              `RV64_SUB, `RV64_SUBW : decode_cast_o.fu_op = e_int_op_sub;
              `RV64_SLL, `RV64_SLLW : decode_cast_o.fu_op = e_int_op_sll;
              `RV64_SRL, `RV64_SRLW : decode_cast_o.fu_op = e_int_op_srl;
              `RV64_SRA, `RV64_SRAW : decode_cast_o.fu_op = e_int_op_sra;
              `RV64_SLT             : decode_cast_o.fu_op = e_int_op_slt;
              `RV64_SLTU            : decode_cast_o.fu_op = e_int_op_sltu;
              `RV64_XOR             : decode_cast_o.fu_op = e_int_op_xor;
              `RV64_OR              : decode_cast_o.fu_op = e_int_op_or;
              `RV64_AND             : decode_cast_o.fu_op = e_int_op_and;

              `RV64_MUL, `RV64_MULW   : decode_cast_o.fu_op = e_fma_op_imul;
              `RV64_DIV, `RV64_DIVW   : decode_cast_o.fu_op = e_mul_op_div;
              `RV64_DIVU, `RV64_DIVUW : decode_cast_o.fu_op = e_mul_op_divu;
              `RV64_REM, `RV64_REMW   : decode_cast_o.fu_op = e_mul_op_rem;
              `RV64_REMU, `RV64_REMUW : decode_cast_o.fu_op = e_mul_op_remu;
              default : illegal_instr_o = 1'b1;
            endcase

            decode_cast_o.src1_sel   = e_src1_is_rs1;
            decode_cast_o.src2_sel   = e_src2_is_rs2;
          end
        `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP:
          begin
            decode_cast_o.pipe_int_v = 1'b1;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            decode_cast_o.opw_v      = (instr.opcode == `RV64_OP_IMM_32_OP);
            unique casez (instr)
              `RV64_ADDI, `RV64_ADDIW : decode_cast_o.fu_op = e_int_op_add;
              `RV64_SLLI, `RV64_SLLIW : decode_cast_o.fu_op = e_int_op_sll;
              `RV64_SRLI, `RV64_SRLIW : decode_cast_o.fu_op = e_int_op_srl;
              `RV64_SRAI, `RV64_SRAIW : decode_cast_o.fu_op = e_int_op_sra;
              `RV64_SLTI              : decode_cast_o.fu_op = e_int_op_slt;
              `RV64_SLTIU             : decode_cast_o.fu_op = e_int_op_sltu;
              `RV64_XORI              : decode_cast_o.fu_op = e_int_op_xor;
              `RV64_ORI               : decode_cast_o.fu_op = e_int_op_or;
              `RV64_ANDI              : decode_cast_o.fu_op = e_int_op_and;
              default : illegal_instr_o = 1'b1;
            endcase

            decode_cast_o.src1_sel   = e_src1_is_rs1;
            decode_cast_o.src2_sel   = e_src2_is_imm;
          end
        `RV64_LUI_OP:
          begin
            decode_cast_o.pipe_int_v = 1'b1;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            decode_cast_o.fu_op      = e_int_op_pass_src2;
            decode_cast_o.src2_sel   = e_src2_is_imm;
          end
        `RV64_AUIPC_OP:
          begin
            decode_cast_o.pipe_int_v = 1'b1;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            decode_cast_o.fu_op      = e_int_op_add;
            decode_cast_o.src1_sel   = e_src1_is_pc;
            decode_cast_o.src2_sel   = e_src2_is_imm;
          end
        `RV64_JAL_OP:
          begin
            decode_cast_o.pipe_ctl_v = 1'b1;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            decode_cast_o.fu_op      = e_ctrl_op_jal;
            decode_cast_o.baddr_sel  = e_baddr_is_pc;
          end
        `RV64_JALR_OP:
          begin
            decode_cast_o.pipe_ctl_v = 1'b1;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            unique casez (instr)
              `RV64_JALR: decode_cast_o.fu_op = e_ctrl_op_jalr;
              default : illegal_instr_o = 1'b1;
            endcase
            decode_cast_o.baddr_sel  = e_baddr_is_rs1;
          end
        `RV64_BRANCH_OP:
          begin
            decode_cast_o.pipe_ctl_v = 1'b1;
            unique casez (instr)
              `RV64_BEQ  : decode_cast_o.fu_op = e_ctrl_op_beq;
              `RV64_BNE  : decode_cast_o.fu_op = e_ctrl_op_bne;
              `RV64_BLT  : decode_cast_o.fu_op = e_ctrl_op_blt;
              `RV64_BGE  : decode_cast_o.fu_op = e_ctrl_op_bge;
              `RV64_BLTU : decode_cast_o.fu_op = e_ctrl_op_bltu;
              `RV64_BGEU : decode_cast_o.fu_op = e_ctrl_op_bgeu;
              default : illegal_instr_o = 1'b1;
            endcase
            decode_cast_o.baddr_sel  = e_baddr_is_pc;
          end
        `RV64_LOAD_OP:
          begin
            decode_cast_o.pipe_mem_early_v = instr inside {`RV64_LD, `RV64_LW, `RV64_LWU};
            decode_cast_o.pipe_mem_final_v = ~decode_cast_o.pipe_mem_early_v;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            decode_cast_o.dcache_r_v = 1'b1;
            decode_cast_o.mem_v      = 1'b1;
            unique casez (instr)
              `RV64_LB : decode_cast_o.fu_op = e_dcache_op_lb;
              `RV64_LH : decode_cast_o.fu_op = e_dcache_op_lh;
              `RV64_LW : decode_cast_o.fu_op = e_dcache_op_lw;
              `RV64_LBU: decode_cast_o.fu_op = e_dcache_op_lbu;
              `RV64_LHU: decode_cast_o.fu_op = e_dcache_op_lhu;
              `RV64_LWU: decode_cast_o.fu_op = e_dcache_op_lwu;
              `RV64_LD : decode_cast_o.fu_op = e_dcache_op_ld;
              default : illegal_instr_o = 1'b1;
            endcase
          end
        `RV64_FLOAD_OP:
          begin
            decode_cast_o.pipe_mem_final_v = 1'b1;
            decode_cast_o.frf_w_v    = 1'b1;
            decode_cast_o.dcache_r_v = 1'b1;
            decode_cast_o.mem_v      = 1'b1;
            decode_cast_o.ops_v      = instr inside {`RV64_FL_W};

            illegal_instr_o = ~decode_info_cast_i.fpu_en;

            unique casez (instr)
              `RV64_FL_W: decode_cast_o.fu_op = e_dcache_op_flw;
              `RV64_FL_D: decode_cast_o.fu_op = e_dcache_op_fld;
              default: illegal_instr_o = 1'b1;
            endcase
          end
        `RV64_STORE_OP:
          begin
            decode_cast_o.pipe_mem_early_v = 1'b1;
            decode_cast_o.dcache_w_v = 1'b1;
            decode_cast_o.mem_v      = 1'b1;
            unique casez (instr)
              `RV64_SB : decode_cast_o.fu_op = e_dcache_op_sb;
              `RV64_SH : decode_cast_o.fu_op = e_dcache_op_sh;
              `RV64_SW : decode_cast_o.fu_op = e_dcache_op_sw;
              `RV64_SD : decode_cast_o.fu_op = e_dcache_op_sd;
              default : illegal_instr_o = 1'b1;
            endcase
          end
        `RV64_FSTORE_OP:
          begin
            decode_cast_o.pipe_mem_early_v = 1'b1;
            decode_cast_o.dcache_w_v = 1'b1;
            decode_cast_o.mem_v      = 1'b1;
            decode_cast_o.ops_v      = instr inside {`RV64_FS_W};
            decode_cast_o.fflags_w_v = 1'b1;

            illegal_instr_o = ~decode_info_cast_i.fpu_en;

            unique casez (instr)
              `RV64_FS_W : decode_cast_o.fu_op = e_dcache_op_fsw;
              `RV64_FS_D : decode_cast_o.fu_op = e_dcache_op_fsd;
              default: illegal_instr_o = 1'b1;
            endcase
          end
        `RV64_MISC_MEM_OP:
          begin
            unique casez (instr)
              `RV64_FENCE   : begin end
              `RV64_FENCE_I :
                begin
                  decode_cast_o.pipe_mem_early_v = 1'b1;
                  decode_cast_o.fu_op            = e_dcache_op_fencei;
                end
              default : illegal_instr_o = 1'b1;
            endcase
          end
        `RV64_SYSTEM_OP:
          begin
            decode_cast_o.pipe_sys_v = 1'b1;
            unique casez (instr)
              `RV64_ECALL:
                begin
                  ecall_m_o = (decode_info_cast_i.priv_mode == `PRIV_MODE_M);
                  ecall_s_o = (decode_info_cast_i.priv_mode == `PRIV_MODE_S);
                  ecall_u_o = (decode_info_cast_i.priv_mode == `PRIV_MODE_U);
                end
              `RV64_EBREAK:
                begin
                  dbreak_o = decode_info_cast_i.debug_mode
                             | (decode_info_cast_i.ebreakm & (decode_info_cast_i.priv_mode == `PRIV_MODE_M))
                             | (decode_info_cast_i.ebreaks & (decode_info_cast_i.priv_mode == `PRIV_MODE_S))
                             | (decode_info_cast_i.ebreaku & (decode_info_cast_i.priv_mode == `PRIV_MODE_U));
                  ebreak_o = ~dbreak_o;
                end
              `RV64_DRET:
                begin
                  illegal_instr_o = ~decode_info_cast_i.debug_mode;
                  dret_o = ~illegal_instr_o;
                end
              `RV64_MRET:
                begin
                  illegal_instr_o = ~decode_info_cast_i.debug_mode & (decode_info_cast_i.priv_mode < `PRIV_MODE_M);
                  mret_o = ~illegal_instr_o;
                end
              `RV64_SRET:
                begin
                  illegal_instr_o = (~decode_info_cast_i.debug_mode & (decode_info_cast_i.priv_mode < `PRIV_MODE_S))
                    | (decode_info_cast_i.tsr & (decode_info_cast_i.priv_mode == `PRIV_MODE_S));
                  sret_o = ~illegal_instr_o;
                end
              `RV64_WFI:
                begin
                  // WFI operates as NOP in debug mode
                  illegal_instr_o = decode_info_cast_i.tw;
                  wfi_o = ~illegal_instr_o & ~decode_info_cast_i.debug_mode;
                end
              `RV64_SFENCE_VMA:
                begin
                  illegal_instr_o = (decode_info_cast_i.tvm & (decode_info_cast_i.priv_mode == `PRIV_MODE_S))
                    | (~decode_info_cast_i.debug_mode & (decode_info_cast_i.priv_mode < `PRIV_MODE_S));
                  sfence_vma_o = ~illegal_instr_o;
                end
              default:
                begin
                  decode_cast_o.csr_w_v = instr inside {`RV64_CSRRW, `RV64_CSRRWI} || (instr.rs1_addr != '0);
                  decode_cast_o.csr_r_v = ~(instr inside {`RV64_CSRRW, `RV64_CSRRWI}) || (instr.rd_addr != '0);
                  decode_cast_o.irf_w_v = (instr.rd_addr != '0);
                  unique casez (instr)
                    `RV64_CSRRW : decode_cast_o.fu_op = decode_cast_o.csr_w_v ? e_csrrw  : e_csrr;
                    `RV64_CSRRWI: decode_cast_o.fu_op = decode_cast_o.csr_w_v ? e_csrrwi : e_csrr;
                    `RV64_CSRRS : decode_cast_o.fu_op = decode_cast_o.csr_w_v ? e_csrrs  : e_csrr;
                    `RV64_CSRRSI: decode_cast_o.fu_op = decode_cast_o.csr_w_v ? e_csrrsi : e_csrr;
                    `RV64_CSRRC : decode_cast_o.fu_op = decode_cast_o.csr_w_v ? e_csrrc  : e_csrr;
                    `RV64_CSRRCI: decode_cast_o.fu_op = decode_cast_o.csr_w_v ? e_csrrci : e_csrr;
                    default : illegal_instr_o = 1'b1;
                  endcase
                end
            endcase
          end
        `RV64_FP_OP:
          begin
            illegal_instr_o = ~decode_info_cast_i.fpu_en;
            unique casez (instr)
              `RV64_FCVT_SD, `RV64_FCVT_DS:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FCVT_DS};
                  decode_cast_o.fu_op        = e_aux_op_f2f;
                end
              `RV64_FCVT_WS, `RV64_FCVT_LS:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_WS};
                  decode_cast_o.ops_v        = 1'b1;
                  decode_cast_o.fu_op        = e_aux_op_f2i;
                end
              `RV64_FCVT_WUS, `RV64_FCVT_LUS:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_WUS};
                  decode_cast_o.ops_v        = 1'b1;
                  decode_cast_o.fu_op        = e_aux_op_f2iu;
                end
              `RV64_FCVT_SW, `RV64_FCVT_SL:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_SW};
                  decode_cast_o.ops_v        = 1'b1;
                  decode_cast_o.fu_op        = e_aux_op_i2f;
                end
              `RV64_FCVT_SWU, `RV64_FCVT_SLU:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_SWU};
                  decode_cast_o.ops_v        = 1'b1;
                  decode_cast_o.fu_op        = e_aux_op_iu2f;
                end
              `RV64_FCVT_WD, `RV64_FCVT_LD:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_WD};
                  decode_cast_o.fu_op        = e_aux_op_f2i;
                end
              `RV64_FCVT_WUD, `RV64_FCVT_LUD:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_WUD};
                  decode_cast_o.fu_op        = e_aux_op_f2iu;
                end
              `RV64_FCVT_DW, `RV64_FCVT_DL:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_DW};
                  decode_cast_o.fu_op        = e_aux_op_i2f;
                end
              `RV64_FCVT_DWU, `RV64_FCVT_DLU:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FCVT_DWU};
                  decode_cast_o.fu_op        = e_aux_op_iu2f;
                end
              `RV64_FMV_XW, `RV64_FMV_XD:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FMV_XW};
                  decode_cast_o.ops_v        = instr inside {`RV64_FMV_XW};
                  decode_cast_o.fu_op        = e_aux_op_fmvi;
                end
              `RV64_FMV_WX, `RV64_FMV_DX:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.opw_v        = instr inside {`RV64_FMV_WX};
                  decode_cast_o.ops_v        = instr inside {`RV64_FMV_WX};
                  decode_cast_o.fu_op        = e_aux_op_imvf;
                end
              `RV64_FSGNJ_S, `RV64_FSGNJ_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FSGNJ_S};
                  decode_cast_o.fu_op        = e_aux_op_fsgnj;
                end
              `RV64_FSGNJN_S, `RV64_FSGNJN_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FSGNJN_S};
                  decode_cast_o.fu_op        = e_aux_op_fsgnjn;
                end
              `RV64_FSGNJX_S, `RV64_FSGNJX_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FSGNJX_S};
                  decode_cast_o.fu_op        = e_aux_op_fsgnjx;
                end
              `RV64_FMIN_S, `RV64_FMIN_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FMIN_S};
                  decode_cast_o.fu_op        = e_aux_op_fmin;
                end
              `RV64_FMAX_S, `RV64_FMAX_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FMAX_S};
                  decode_cast_o.fu_op        = e_aux_op_fmax;
                end
              `RV64_FEQ_S, `RV64_FEQ_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FEQ_S};
                  decode_cast_o.fu_op        = e_aux_op_feq;
                end
              `RV64_FLT_S, `RV64_FLT_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FLT_S};
                  decode_cast_o.fu_op        = e_aux_op_flt;
                end
              `RV64_FLE_S, `RV64_FLE_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FLE_S};
                  decode_cast_o.fu_op        = e_aux_op_fle;
                end
              `RV64_FCLASS_S, `RV64_FCLASS_D:
                begin
                  decode_cast_o.pipe_aux_v   = 1'b1;
                  decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FCLASS_S};
                  decode_cast_o.fu_op        = e_aux_op_fclass;
                end
              `RV64_FADD_S, `RV64_FADD_D:
                begin
                  decode_cast_o.pipe_fma_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FADD_S};
                  decode_cast_o.fu_op        = e_fma_op_fadd;
                end
              `RV64_FSUB_S, `RV64_FSUB_D:
                begin
                  decode_cast_o.pipe_fma_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FSUB_S};
                  decode_cast_o.fu_op        = e_fma_op_fsub;
                end
              `RV64_FMUL_S, `RV64_FMUL_D:
                begin
                  decode_cast_o.pipe_fma_v   = 1'b1;
                  decode_cast_o.frf_w_v      = 1'b1;
                  decode_cast_o.fflags_w_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FMUL_S};
                  decode_cast_o.fu_op        = e_fma_op_fmul;
                end
              `RV64_FDIV_S, `RV64_FDIV_D:
                begin
                  decode_cast_o.pipe_long_v  = 1'b1;
                  decode_cast_o.late_fwb_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FDIV_S};
                  decode_cast_o.fu_op        = e_fma_op_fdiv;
                end
              `RV64_FSQRT_S, `RV64_FSQRT_D:
                begin
                  decode_cast_o.pipe_long_v  = 1'b1;
                  decode_cast_o.late_fwb_v   = 1'b1;
                  decode_cast_o.ops_v        = instr inside {`RV64_FSQRT_S};
                  decode_cast_o.fu_op        = e_fma_op_fsqrt;
                end
              default: illegal_instr_o = 1'b1;
            endcase
          end


        `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
          begin
            decode_cast_o.pipe_fma_v = 1'b1;
            decode_cast_o.frf_w_v    = 1'b1;
            decode_cast_o.fflags_w_v = 1'b1;
            decode_cast_o.ops_v      = (instr.fmt == e_fmt_single);

            casez (instr.opcode)
              `RV64_FMADD_OP : decode_cast_o.fu_op = e_fma_op_fmadd;
              `RV64_FMSUB_OP : decode_cast_o.fu_op = e_fma_op_fmsub;
              `RV64_FNMSUB_OP: decode_cast_o.fu_op = e_fma_op_fnmsub;
              `RV64_FNMADD_OP: decode_cast_o.fu_op = e_fma_op_fnmadd;
              default: decode_cast_o.fu_op = e_fma_op_fmadd;
            endcase

            illegal_instr_o = ~decode_info_cast_i.fpu_en;
          end

        `RV64_AMO_OP:
          begin
            decode_cast_o.pipe_mem_early_v = 1'b1;
            decode_cast_o.irf_w_v    = (instr.rd_addr != '0);
            decode_cast_o.dcache_r_v = ~(instr inside {`RV64_SCD, `RV64_SCW});
            decode_cast_o.dcache_w_v = ~(instr inside {`RV64_LRD, `RV64_LRW});
            decode_cast_o.mem_v      = 1'b1;
            // Note: could do a more efficent decoding here by having atomic be a flag
            //   And having the op simply taken from funct3
            unique casez (instr)
              `RV64_LRD      : decode_cast_o.fu_op = e_dcache_op_lrd;
              `RV64_LRW      : decode_cast_o.fu_op = e_dcache_op_lrw;
              `RV64_SCD      : decode_cast_o.fu_op = e_dcache_op_scd;
              `RV64_SCW      : decode_cast_o.fu_op = e_dcache_op_scw;
              `RV64_AMOSWAPD : decode_cast_o.fu_op = e_dcache_op_amoswapd;
              `RV64_AMOSWAPW : decode_cast_o.fu_op = e_dcache_op_amoswapw;
              `RV64_AMOADDD  : decode_cast_o.fu_op = e_dcache_op_amoaddd;
              `RV64_AMOADDW  : decode_cast_o.fu_op = e_dcache_op_amoaddw;
              `RV64_AMOXORD  : decode_cast_o.fu_op = e_dcache_op_amoxord;
              `RV64_AMOXORW  : decode_cast_o.fu_op = e_dcache_op_amoxorw;
              `RV64_AMOANDD  : decode_cast_o.fu_op = e_dcache_op_amoandd;
              `RV64_AMOANDW  : decode_cast_o.fu_op = e_dcache_op_amoandw;
              `RV64_AMOORD   : decode_cast_o.fu_op = e_dcache_op_amoord;
              `RV64_AMOORW   : decode_cast_o.fu_op = e_dcache_op_amoorw;
              `RV64_AMOMIND  : decode_cast_o.fu_op = e_dcache_op_amomind;
              `RV64_AMOMINW  : decode_cast_o.fu_op = e_dcache_op_amominw;
              `RV64_AMOMAXD  : decode_cast_o.fu_op = e_dcache_op_amomaxd;
              `RV64_AMOMAXW  : decode_cast_o.fu_op = e_dcache_op_amomaxw;
              `RV64_AMOMINUD : decode_cast_o.fu_op = e_dcache_op_amominud;
              `RV64_AMOMINUW : decode_cast_o.fu_op = e_dcache_op_amominuw;
              `RV64_AMOMAXUD : decode_cast_o.fu_op = e_dcache_op_amomaxud;
              `RV64_AMOMAXUW : decode_cast_o.fu_op = e_dcache_op_amomaxuw;
              default : illegal_instr_o = 1'b1;
            endcase

            // Detect AMO support level
            unique casez (instr)
              `RV64_LRD, `RV64_LRW, `RV64_SCD, `RV64_SCW:
                illegal_instr_o =
                  ~|{dcache_amo_support_p[e_lr_sc], l2_amo_support_p[e_lr_sc]};
              `RV64_AMOSWAPD, `RV64_AMOSWAPW:
                illegal_instr_o =
                  ~|{dcache_amo_support_p[e_amo_swap], l2_amo_support_p[e_amo_swap]};
              `RV64_AMOANDD, `RV64_AMOANDW
              ,`RV64_AMOORD, `RV64_AMOORW
              ,`RV64_AMOXORD, `RV64_AMOXORW:
                illegal_instr_o =
                  ~|{dcache_amo_support_p[e_amo_fetch_logic], l2_amo_support_p[e_amo_fetch_logic]};
              `RV64_AMOADDD, `RV64_AMOADDW
              ,`RV64_AMOMIND, `RV64_AMOMINW, `RV64_AMOMAXD, `RV64_AMOMAXW
              ,`RV64_AMOMINUD, `RV64_AMOMINUW, `RV64_AMOMAXUD, `RV64_AMOMAXUW:
                illegal_instr_o =
                  ~|{dcache_amo_support_p[e_amo_fetch_arithmetic], l2_amo_support_p[e_amo_fetch_arithmetic]};
              default: begin end
            endcase
          end
        default : illegal_instr_o = 1'b1;
      endcase

      // Immediate extraction
      unique casez (instr.opcode)
        `RV64_LUI_OP, `RV64_AUIPC_OP:
          imm_o = `rv64_signext_u_imm(instr);
        `RV64_JAL_OP:
          imm_o = `rv64_signext_j_imm(instr);
        `RV64_BRANCH_OP:
          imm_o = `rv64_signext_b_imm(instr);
        `RV64_STORE_OP, `RV64_FSTORE_OP:
          imm_o = `rv64_signext_s_imm(instr);
        `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_FLOAD_OP:
          imm_o = `rv64_signext_i_imm(instr);
        `RV64_SYSTEM_OP:
          imm_o = `rv64_signext_c_imm(instr);
        //`RV64_AMO_OP:
        default: imm_o = '0;
      endcase
    end

endmodule


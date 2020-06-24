/**
 *
 * Name:
 *   bp_be_instr_decoder.v
 *
 * Description:
 *   BlackParrot instruction decoder for translating RISC-V instructions into pipeline control
 *     signals. Currently supports most of rv64i with the exception of fences and csrs.
 *
 * Notes:
 *   We may want to break this up into a decoder for each standard extension.
 *   decode_s might not be the best name for control signals. Additionally, each pipe may need
 *     different signals. Use a union in decode_s to save bits?
 *   Only MHARTID is supported at the moment. When more CSRs are added, we'll need to
 *     reevaluate this method of CSRRW.
 */

module bp_be_instr_decoder
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam instr_width_lp = rv64_instr_width_gp
   , localparam decode_width_lp = `bp_be_decode_width
   )
  (input                             fe_exc_not_instr_i
   , input bp_fe_exception_code_e    fe_exc_i
   , input [instr_width_lp-1:0]      instr_i

   , output [decode_width_lp-1:0]    decode_o
   , output [dword_width_p-1:0]      imm_o

   , input                           fpu_en_i
   );

  rv64_instr_fmatype_s instr;
  bp_be_decode_s decode;
  logic [dword_width_p-1:0] imm;

  assign instr    = instr_i;
  assign decode_o = decode;
  assign imm_o    = imm;

  logic illegal_instr;
  // Decode logic
  always_comb
    begin
      // Set decoded defaults
      // NOPs are set after bypassing for critical path reasons
      decode               = '0;

      // Destination pipe
      decode.pipe_ctl_v       = '0;
      decode.pipe_int_v       = '0;
      decode.pipe_mem_early_v = '0;
      decode.pipe_aux_v       = '0;
      decode.pipe_mem_final_v = '0;
      decode.pipe_mul_v       = '0;
      decode.pipe_fma_v       = '0;
      decode.pipe_long_v      = '0;

      // R/W signals
      decode.irf_w_v       = '0;
      decode.frf_w_v       = '0;
      decode.fflags_w_v    = '0;
      decode.dcache_r_v    = '0;
      decode.dcache_w_v    = '0;
      decode.csr_r_v       = '0;
      decode.csr_w_v       = '0;
      decode.late_iwb_v    = '0;
      decode.late_fwb_v    = '0;

      // Metadata signals
      decode.mem_v         = '0;
      decode.csr_v         = '0;

      // Decode metadata
      decode.opw_v         = '0;
      decode.ops_v         = '0;

      // Decode control signals
      decode.fu_op         = bp_be_fu_op_s'(0);
      decode.src1_sel      = bp_be_src1_e'('0);
      decode.src2_sel      = bp_be_src2_e'('0);
      decode.baddr_sel     = bp_be_baddr_e'('0);

      imm                  = '0;
      illegal_instr        = '0;

      unique casez (instr.opcode)
        `RV64_OP_OP, `RV64_OP_32_OP :
          begin
            if (instr inside {`RV64_MUL, `RV64_MULW})
              decode.pipe_mul_v = 1'b1;
            else if (instr inside {`RV64_DIV, `RV64_DIVU, `RV64_DIVW, `RV64_DIVUW
                                   ,`RV64_REM, `RV64_REMU, `RV64_REMW, `RV64_REMUW
                                   })
              begin
                decode.pipe_long_v = 1'b1;
                decode.late_iwb_v  = 1'b1;
              end
            else
              decode.pipe_int_v = 1'b1;

            // The writeback for long latency ops comes out of band
            decode.irf_w_v    = ~decode.late_iwb_v;
            decode.opw_v      = (instr.opcode == `RV64_OP_32_OP);
            unique casez (instr)
              `RV64_ADD, `RV64_ADDW : decode.fu_op = e_int_op_add;
              `RV64_SUB, `RV64_SUBW : decode.fu_op = e_int_op_sub;
              `RV64_SLL, `RV64_SLLW : decode.fu_op = e_int_op_sll;
              `RV64_SRL, `RV64_SRLW : decode.fu_op = e_int_op_srl;
              `RV64_SRA, `RV64_SRAW : decode.fu_op = e_int_op_sra;
              `RV64_SLT             : decode.fu_op = e_int_op_slt;
              `RV64_SLTU            : decode.fu_op = e_int_op_sltu;
              `RV64_XOR             : decode.fu_op = e_int_op_xor;
              `RV64_OR              : decode.fu_op = e_int_op_or;
              `RV64_AND             : decode.fu_op = e_int_op_and;

              `RV64_MUL, `RV64_MULW   : decode.fu_op = e_fma_op_imul;
              `RV64_DIV, `RV64_DIVW   : decode.fu_op = e_mul_op_div;
              `RV64_DIVU, `RV64_DIVUW : decode.fu_op = e_mul_op_divu;
              `RV64_REM, `RV64_REMW   : decode.fu_op = e_mul_op_rem;
              `RV64_REMU, `RV64_REMUW : decode.fu_op = e_mul_op_remu;
              default : illegal_instr = 1'b1;
            endcase

            decode.src1_sel   = e_src1_is_rs1;
            decode.src2_sel   = e_src2_is_rs2;
          end
        `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP :
          begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.opw_v      = (instr.opcode == `RV64_OP_IMM_32_OP);
            unique casez (instr)
              `RV64_ADDI, `RV64_ADDIW : decode.fu_op = e_int_op_add;
              `RV64_SLLI, `RV64_SLLIW : decode.fu_op = e_int_op_sll;
              `RV64_SRLI, `RV64_SRLIW : decode.fu_op = e_int_op_srl;
              `RV64_SRAI, `RV64_SRAIW : decode.fu_op = e_int_op_sra;
              `RV64_SLTI              : decode.fu_op = e_int_op_slt;
              `RV64_SLTIU             : decode.fu_op = e_int_op_sltu;
              `RV64_XORI              : decode.fu_op = e_int_op_xor;
              `RV64_ORI               : decode.fu_op = e_int_op_or;
              `RV64_ANDI              : decode.fu_op = e_int_op_and;
              default : illegal_instr = 1'b1;
            endcase

            decode.src1_sel   = e_src1_is_rs1;
            decode.src2_sel   = e_src2_is_imm;
          end
        `RV64_LUI_OP :
          begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.fu_op      = e_int_op_pass_src2;
            decode.src2_sel   = e_src2_is_imm;
          end
        `RV64_AUIPC_OP :
          begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.fu_op      = e_int_op_add;
            decode.src1_sel   = e_src1_is_pc;
            decode.src2_sel   = e_src2_is_imm;
          end
        `RV64_JAL_OP :
          begin
            decode.pipe_ctl_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.fu_op      = e_ctrl_op_jal;
            decode.baddr_sel  = e_baddr_is_pc;
          end
        `RV64_JALR_OP :
          begin
            decode.pipe_ctl_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            unique casez (instr)
              `RV64_JALR: decode.fu_op = e_ctrl_op_jalr;
              default : illegal_instr = 1'b1;
            endcase
            decode.baddr_sel  = e_baddr_is_rs1;
          end
        `RV64_BRANCH_OP :
          begin
            decode.pipe_ctl_v = 1'b1;
            unique casez (instr)
              `RV64_BEQ  : decode.fu_op = e_ctrl_op_beq;
              `RV64_BNE  : decode.fu_op = e_ctrl_op_bne;
              `RV64_BLT  : decode.fu_op = e_ctrl_op_blt;
              `RV64_BGE  : decode.fu_op = e_ctrl_op_bge;
              `RV64_BLTU : decode.fu_op = e_ctrl_op_bltu;
              `RV64_BGEU : decode.fu_op = e_ctrl_op_bgeu;
              default : illegal_instr = 1'b1;
            endcase
            decode.baddr_sel  = e_baddr_is_pc;
          end
        `RV64_LOAD_OP :
          begin
            decode.pipe_mem_early_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.dcache_r_v = 1'b1;
            decode.mem_v      = 1'b1;
            unique casez (instr)
              `RV64_LB : decode.fu_op = e_dcache_op_lb;
              `RV64_LH : decode.fu_op = e_dcache_op_lh;
              `RV64_LW : decode.fu_op = e_dcache_op_lw;
              `RV64_LBU: decode.fu_op = e_dcache_op_lbu;
              `RV64_LHU: decode.fu_op = e_dcache_op_lhu;
              `RV64_LWU: decode.fu_op = e_dcache_op_lwu;
              `RV64_LD : decode.fu_op = e_dcache_op_ld;
              default : illegal_instr = 1'b1;
            endcase
          end
        `RV64_FLOAD_OP :
          begin
            decode.pipe_mem_final_v = 1'b1;
            decode.frf_w_v    = 1'b1;
            decode.dcache_r_v = 1'b1;
            decode.mem_v      = 1'b1;
            decode.ops_v      = instr inside {`RV64_FL_W};

            illegal_instr = ~fpu_en_i;

            unique casez (instr)
              `RV64_FL_W: decode.fu_op = e_dcache_op_flw;
              `RV64_FL_D: decode.fu_op = e_dcache_op_fld;
              default: illegal_instr = 1'b1;
            endcase
          end
        `RV64_STORE_OP :
          begin
            decode.pipe_mem_early_v = 1'b1;
            decode.dcache_w_v = 1'b1;
            decode.mem_v      = 1'b1;
            unique casez (instr)
              `RV64_SB : decode.fu_op = e_dcache_op_sb;
              `RV64_SH : decode.fu_op = e_dcache_op_sh;
              `RV64_SW : decode.fu_op = e_dcache_op_sw;
              `RV64_SD : decode.fu_op = e_dcache_op_sd;
              default : illegal_instr = 1'b1;
            endcase
          end
        `RV64_FSTORE_OP :
          begin
            decode.pipe_mem_early_v = 1'b1;
            decode.dcache_w_v = 1'b1;
            decode.mem_v      = 1'b1;
            decode.ops_v      = instr inside {`RV64_FS_W};

            illegal_instr = ~fpu_en_i;

            unique casez (instr)
              `RV64_FS_W : decode.fu_op = e_dcache_op_fsw;
              `RV64_FS_D : decode.fu_op = e_dcache_op_fsd;
              default: illegal_instr = 1'b1;
            endcase
          end
        `RV64_MISC_MEM_OP :
          begin
            unique casez (instr)
              `RV64_FENCE   : begin end
              `RV64_FENCE_I :
                begin
                  decode.pipe_mem_early_v = 1'b1;
                  decode.fu_op            = e_dcache_op_fencei;
                end
              default : illegal_instr = 1'b1;
            endcase
          end
        `RV64_SYSTEM_OP :
          begin
            decode.pipe_sys_v = 1'b1;
            decode.csr_v      = 1'b1;
            unique casez (instr)
              `RV64_ECALL      : decode.fu_op = e_ecall;
              `RV64_EBREAK     : decode.fu_op = e_ebreak;
              `RV64_DRET       : decode.fu_op = e_dret;
              `RV64_MRET       : decode.fu_op = e_mret;
              `RV64_SRET       : decode.fu_op = e_sret;
              `RV64_WFI        : decode.fu_op = e_wfi;
              `RV64_SFENCE_VMA : decode.fu_op = e_sfence_vma;
              default:
                begin
                  decode.irf_w_v     = 1'b1;
                  // TODO: Should not write/read based on x0
                  decode.csr_w_v     = 1'b1;
                  decode.csr_r_v     = 1'b1;
                  unique casez (instr)
                    `RV64_CSRRW  : decode.fu_op = e_csrrw;
                    `RV64_CSRRWI : decode.fu_op = e_csrrwi;
                    `RV64_CSRRS  : decode.fu_op = e_csrrs;
                    `RV64_CSRRSI : decode.fu_op = e_csrrsi;
                    `RV64_CSRRC  : decode.fu_op = e_csrrc;
                    `RV64_CSRRCI : decode.fu_op = e_csrrci;
                    default : illegal_instr = 1'b1;
                  endcase
                end
            endcase
          end
        `RV64_FP_OP:
          begin
            illegal_instr = ~fpu_en_i;
            unique casez (instr)
              `RV64_FCVT_SD, `RV64_FCVT_DS:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FCVT_SD};
                  decode.fu_op        = e_aux_op_f2f;
                end
              `RV64_FCVT_WS, `RV64_FCVT_LS:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_WS};
                  decode.ops_v        = 1'b1;
                  decode.fu_op        = e_aux_op_f2i;
                end
              `RV64_FCVT_WUS, `RV64_FCVT_LUS:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_WUS};
                  decode.ops_v        = 1'b1;
                  decode.fu_op        = e_aux_op_f2iu;
                end
              `RV64_FCVT_SW, `RV64_FCVT_SL:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_SW};
                  decode.ops_v        = 1'b1;
                  decode.fu_op        = e_aux_op_i2f;
                end
              `RV64_FCVT_SWU, `RV64_FCVT_SLU:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_SWU};
                  decode.ops_v        = 1'b1;
                  decode.fu_op        = e_aux_op_iu2f;
                end
              `RV64_FCVT_WD, `RV64_FCVT_LD:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_WD};
                  decode.fu_op        = e_aux_op_f2i;
                end
              `RV64_FCVT_WUD, `RV64_FCVT_LUD:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_WUD};
                  decode.fu_op        = e_aux_op_f2iu;
                end
              `RV64_FCVT_DW, `RV64_FCVT_DL:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_DW};
                  decode.fu_op        = e_aux_op_i2f;
                end
              `RV64_FCVT_DWU, `RV64_FCVT_DLU:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FCVT_DWU};
                  decode.fu_op        = e_aux_op_iu2f;
                end
              `RV64_FMV_XW, `RV64_FMV_XD:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FMV_XW};
                  decode.ops_v        = instr inside {`RV64_FMV_XW};
                  decode.fu_op        = e_aux_op_fmvi;
                end
              `RV64_FMV_WX, `RV64_FMV_DX:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.opw_v        = instr inside {`RV64_FMV_WX};
                  decode.ops_v        = instr inside {`RV64_FMV_WX};
                  decode.fu_op        = e_aux_op_imvf;
                end
              `RV64_FSGNJ_S, `RV64_FSGNJ_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FSGNJ_S};
                  decode.fu_op        = e_aux_op_fsgnj;
                end
              `RV64_FSGNJN_S, `RV64_FSGNJN_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FSGNJN_S};
                  decode.fu_op        = e_aux_op_fsgnjn;
                end
              `RV64_FSGNJX_S, `RV64_FSGNJX_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FSGNJX_S};
                  decode.fu_op        = e_aux_op_fsgnjx;
                end
              `RV64_FMIN_S, `RV64_FMIN_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FMIN_S};
                  decode.fu_op        = e_aux_op_fmin;
                end
              `RV64_FMAX_S, `RV64_FMAX_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FMAX_S};
                  decode.fu_op        = e_aux_op_fmax;
                end
              `RV64_FEQ_S, `RV64_FEQ_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FEQ_S};
                  decode.fu_op        = e_aux_op_feq;
                end
              `RV64_FLT_S, `RV64_FLT_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FLT_S};
                  decode.fu_op        = e_aux_op_flt;
                end
              `RV64_FLE_S, `RV64_FLE_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FLE_S};
                  decode.fu_op        = e_aux_op_fle;
                end
              `RV64_FCLASS_S, `RV64_FCLASS_D:
                begin
                  decode.pipe_aux_v   = 1'b1;
                  decode.irf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FCLASS_S};
                  decode.fu_op        = e_aux_op_fclass;
                end
              `RV64_FADD_S, `RV64_FADD_D:
                begin
                  decode.pipe_fma_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FADD_S};
                  decode.fu_op        = e_fma_op_fadd;
                end
              `RV64_FSUB_S, `RV64_FSUB_D:
                begin
                  decode.pipe_fma_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FSUB_S};
                  decode.fu_op        = e_fma_op_fsub;
                end
              `RV64_FMUL_S, `RV64_FMUL_D:
                begin
                  decode.pipe_fma_v   = 1'b1;
                  decode.frf_w_v      = 1'b1;
                  decode.fflags_w_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FMUL_S};
                  decode.fu_op        = e_fma_op_fmul;
                end
              `RV64_FDIV_S, `RV64_FDIV_D:
                begin
                  decode.pipe_long_v  = 1'b1;
                  decode.late_fwb_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FDIV_S};
                  decode.fu_op        = e_fma_op_fdiv;
                end
              `RV64_FSQRT_S, `RV64_FSQRT_D:
                begin
                  decode.pipe_long_v  = 1'b1;
                  decode.late_fwb_v   = 1'b1;
                  decode.ops_v        = instr inside {`RV64_FSQRT_S};
                  decode.fu_op        = e_fma_op_fsqrt;
                end
              default: illegal_instr = 1'b1;
            endcase
          end


        `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
          begin
            decode.pipe_fma_v = 1'b1;
            decode.frf_w_v    = 1'b1;
            decode.fflags_w_v = 1'b1;
            decode.ops_v      = (instr.fmt == e_fmt_single);

            casez (instr.opcode)
              `RV64_FMADD_OP : decode.fu_op = e_fma_op_fmadd;
              `RV64_FMSUB_OP : decode.fu_op = e_fma_op_fmsub;
              `RV64_FNMSUB_OP: decode.fu_op = e_fma_op_fnmsub;
              `RV64_FNMADD_OP: decode.fu_op = e_fma_op_fnmadd;
              default: decode.fu_op = e_fma_op_fmadd;
            endcase

            illegal_instr = ~fpu_en_i;
          end

        `RV64_AMO_OP:
          begin
            decode.pipe_mem_early_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.dcache_r_v = ~(instr inside {`RV64_SCD, `RV64_SCW});
            decode.dcache_w_v = ~(instr inside {`RV64_LRD, `RV64_LRW});
            decode.mem_v      = 1'b1;
            // Note: could do a more efficent decoding here by having atomic be a flag
            //   And having the op simply taken from funct3
            unique casez (instr)
              `RV64_LRD      : decode.fu_op = e_dcache_op_lrd;
              `RV64_LRW      : decode.fu_op = e_dcache_op_lrw;
              `RV64_SCD      : decode.fu_op = e_dcache_op_scd;
              `RV64_SCW      : decode.fu_op = e_dcache_op_scw;
              `RV64_AMOSWAPD : decode.fu_op = e_dcache_op_amoswapd;
              `RV64_AMOSWAPW : decode.fu_op = e_dcache_op_amoswapw;
              `RV64_AMOADDD  : decode.fu_op = e_dcache_op_amoaddd;
              `RV64_AMOADDW  : decode.fu_op = e_dcache_op_amoaddw;
              `RV64_AMOXORD  : decode.fu_op = e_dcache_op_amoxord;
              `RV64_AMOXORW  : decode.fu_op = e_dcache_op_amoxorw;
              `RV64_AMOANDD  : decode.fu_op = e_dcache_op_amoandd;
              `RV64_AMOANDW  : decode.fu_op = e_dcache_op_amoandw;
              `RV64_AMOORD   : decode.fu_op = e_dcache_op_amoord;
              `RV64_AMOORW   : decode.fu_op = e_dcache_op_amoorw;
              `RV64_AMOMIND  : decode.fu_op = e_dcache_op_amomind;
              `RV64_AMOMINW  : decode.fu_op = e_dcache_op_amominw;
              `RV64_AMOMAXD  : decode.fu_op = e_dcache_op_amomaxd;
              `RV64_AMOMAXW  : decode.fu_op = e_dcache_op_amomaxw;
              `RV64_AMOMINUD : decode.fu_op = e_dcache_op_amominud;
              `RV64_AMOMINUW : decode.fu_op = e_dcache_op_amominuw;
              `RV64_AMOMAXUD : decode.fu_op = e_dcache_op_amomaxud;
              `RV64_AMOMAXUW : decode.fu_op = e_dcache_op_amomaxuw;
              default : illegal_instr = 1'b1;
            endcase

            // Detect AMO support level
            unique casez (instr)
              `RV64_LRD, `RV64_LRW, `RV64_SCD, `RV64_SCW:
                illegal_instr = (lr_sc_p == e_none);
              `RV64_AMOSWAPD, `RV64_AMOSWAPW:
                illegal_instr = (amo_swap_p == e_none);
              `RV64_AMOANDD, `RV64_AMOANDW
              ,`RV64_AMOORD, `RV64_AMOORW
              ,`RV64_AMOXORD, `RV64_AMOXORW:
                illegal_instr = (amo_fetch_logic_p == e_none);
              `RV64_AMOADDD, `RV64_AMOADDW
              ,`RV64_AMOMIND, `RV64_AMOMINW, `RV64_AMOMAXD, `RV64_AMOMAXW
              ,`RV64_AMOMINUD, `RV64_AMOMINUW, `RV64_AMOMAXUD, `RV64_AMOMAXUW:
                illegal_instr = (amo_fetch_arithmetic_p == e_none);
              default: begin end
            endcase
          end
        default : illegal_instr = 1'b1;
      endcase

      if (fe_exc_not_instr_i)
        begin
          decode = '0;
          decode.csr_v = 1'b1;
          casez (fe_exc_i)
            e_instr_access_fault: decode.instr_access_fault = 1'b1;
            e_instr_page_fault  : decode.instr_page_fault   = 1'b1;
            e_itlb_miss         : decode.itlb_miss          = 1'b1;
            e_icache_miss       : decode.icache_miss        = 1'b1;
          endcase
        end
      else if (illegal_instr)
        begin
          decode = '0;
          decode.illegal_instr = 1'b1;
        end

      // Immediate extraction
      unique casez (instr.opcode)
        `RV64_LUI_OP, `RV64_AUIPC_OP:
          imm = `rv64_signext_u_imm(instr);
        `RV64_JAL_OP:
          imm = `rv64_signext_j_imm(instr);
        `RV64_BRANCH_OP:
          imm = `rv64_signext_b_imm(instr);
        `RV64_STORE_OP, `RV64_FSTORE_OP:
          imm = `rv64_signext_s_imm(instr);
        `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_FLOAD_OP:
          imm = `rv64_signext_i_imm(instr);
        `RV64_SYSTEM_OP:
          imm = `rv64_signext_c_imm(instr);
        `RV64_AMO_OP:
          imm = '0;
        default: begin end
      endcase
    end

endmodule

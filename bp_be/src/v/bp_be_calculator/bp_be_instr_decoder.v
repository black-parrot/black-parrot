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
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
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
   );

  rv64_instr_rtype_s instr;
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
      decode.instr_v       = 1'b1;

      // Destination pipe
      decode.pipe_ctrl_v   = '0;
      decode.pipe_int_v    = '0;
      decode.pipe_mem_v    = '0;
      decode.pipe_mul_v    = '0;
      decode.pipe_fp_v     = '0;
      decode.pipe_long_v   = '0;

      // R/W signals
      decode.irf_w_v       = '0;
      decode.frf_w_v       = '0;
      decode.dcache_r_v    = '0;
      decode.dcache_w_v    = '0;
      decode.csr_r_v       = '0;
      decode.csr_w_v       = '0;

      // Metadata signals
      decode.mem_v         = '0;
      decode.csr_v         = '0;
      decode.serial_v      = '0;

      // Decode metadata
      decode.fp_not_int_v  = '0;
      decode.opw_v         = '0;

      // Decode control signals
      decode.fu_op         = bp_be_fu_op_s'(0);
      decode.src1_sel      = bp_be_src1_e'('0);
      decode.src2_sel      = bp_be_src2_e'('0);
      decode.baddr_sel     = bp_be_baddr_e'('0);
      decode.result_sel    = bp_be_result_e'('0);
      decode.offset_sel    = e_offset_is_imm;

      illegal_instr        = '0;

      unique casez (instr.opcode)
        `RV64_OP_OP, `RV64_OP_32_OP :
          begin
            if (instr inside {`RV64_MUL, `RV64_MULW})
              decode.pipe_mul_v = 1'b1;
            else if (instr inside {`RV64_DIV, `RV64_DIVU, `RV64_DIVW, `RV64_DIVUW
                                   ,`RV64_REM, `RV64_REMU, `RV64_REMW, `RV64_REMUW
                                   })
              decode.pipe_long_v = 1'b1;
            else
              decode.pipe_int_v = 1'b1;

            // The writeback for long latency ops comes out of band
            decode.irf_w_v    = ~decode.pipe_long_v;
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

              `RV64_MUL, `RV64_MULW   : decode.fu_op = e_mul_op_mul;
              `RV64_DIV, `RV64_DIVW   : decode.fu_op = e_mul_op_div;
              `RV64_DIVU, `RV64_DIVUW : decode.fu_op = e_mul_op_divu;
              `RV64_REM, `RV64_REMW   : decode.fu_op = e_mul_op_rem;
              `RV64_REMU, `RV64_REMUW : decode.fu_op = e_mul_op_remu;
              default : illegal_instr = 1'b1;
            endcase

            decode.src1_sel   = e_src1_is_rs1;
            decode.src2_sel   = e_src2_is_rs2;
            decode.result_sel = e_result_from_alu;
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
            decode.result_sel = e_result_from_alu;
          end
        `RV64_LUI_OP :
          begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.fu_op      = e_int_op_pass_src2;
            decode.src2_sel   = e_src2_is_imm;
            decode.result_sel = e_result_from_alu;
          end
        `RV64_AUIPC_OP :
          begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.fu_op      = e_int_op_add;
            decode.src1_sel   = e_src1_is_pc;
            decode.src2_sel   = e_src2_is_imm;
            decode.result_sel = e_result_from_alu;
          end
        `RV64_JAL_OP :
          begin
            decode.pipe_ctrl_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.fu_op      = e_ctrl_op_jal;
            decode.baddr_sel  = e_baddr_is_pc;
          end
        `RV64_JALR_OP :
          begin
            decode.pipe_ctrl_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            unique casez (instr)
              `RV64_JALR: decode.fu_op = e_ctrl_op_jalr;
              default : illegal_instr = 1'b1;
            endcase
            decode.baddr_sel  = e_baddr_is_rs1;
          end
        `RV64_BRANCH_OP :
          begin
            decode.pipe_ctrl_v = 1'b1;
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
            decode.pipe_mem_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.dcache_r_v = 1'b1;
            decode.mem_v      = 1'b1;
            unique casez (instr)
              `RV64_LB : decode.fu_op = e_dcache_opcode_lb;
              `RV64_LH : decode.fu_op = e_dcache_opcode_lh;
              `RV64_LW : decode.fu_op = e_dcache_opcode_lw;
              `RV64_LBU: decode.fu_op = e_dcache_opcode_lbu;
              `RV64_LHU: decode.fu_op = e_dcache_opcode_lhu;
              `RV64_LWU: decode.fu_op = e_dcache_opcode_lwu;
              `RV64_LD : decode.fu_op = e_dcache_opcode_ld;
              default : illegal_instr = 1'b1;
            endcase
          end
        `RV64_STORE_OP :
          begin
            decode.pipe_mem_v = 1'b1;
            decode.dcache_w_v = 1'b1;
            decode.mem_v      = 1'b1;
            unique casez (instr)
              `RV64_SB : decode.fu_op = e_dcache_opcode_sb;
              `RV64_SH : decode.fu_op = e_dcache_opcode_sh;
              `RV64_SW : decode.fu_op = e_dcache_opcode_sw;
              `RV64_SD : decode.fu_op = e_dcache_opcode_sd;
              default : illegal_instr = 1'b1;
            endcase
          end
        `RV64_MISC_MEM_OP :
          begin
            unique casez (instr)
              `RV64_FENCE   : begin end
              `RV64_FENCE_I :
                begin
                  decode.pipe_mem_v  = 1'b1;
                  decode.dcache_w_v  = 1'b1;
                  decode.serial_v    = 1'b1;
                  decode.fu_op       = e_dcache_opcode_fencei;
                end
              default : illegal_instr = 1'b1;
            endcase
          end
        `RV64_SYSTEM_OP :
          begin
            decode.pipe_sys_v = 1'b1;
            decode.csr_v      = 1'b1;
            decode.serial_v   = 1'b1;
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
        `RV64_AMO_OP:
          begin
            decode.pipe_mem_v = 1'b1;
            decode.irf_w_v    = 1'b1;
            decode.dcache_r_v = 1'b1;
            decode.dcache_w_v = 1'b1;
            decode.mem_v      = 1'b1;
            decode.offset_sel = e_offset_is_zero;
            // Note: could do a more efficent decoding here by having atomic be a flag
            //   And having the op simply taken from funct3
            unique casez (instr)
              `RV64_LRW:
                begin
                  if (lr_sc_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_lrw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_SCW:
                begin
                  if (lr_sc_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_scw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOSWAPW:
                begin
                  if (amo_swap_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoswapw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOADDW:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoaddw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOXORW:
                begin
                  if (amo_fetch_logic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoxorw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOANDW:
                begin
                  if (amo_fetch_logic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoandw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOORW:
                begin
                  if (amo_fetch_logic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoorw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMINW:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amominw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMAXW:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amomaxw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMINUW:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amominuw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMAXUW:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amomaxuw;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_LRD:
                begin
                  if (lr_sc_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_lrd;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_SCD:
                begin
                  if (lr_sc_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_scd;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOSWAPD:
                begin
                  if (amo_swap_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoswapd;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOADDD:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoaddd;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOXORD:
                begin
                  if (amo_fetch_logic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoxord;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOANDD:
                begin
                  if (amo_fetch_logic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoandd;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOORD:
                begin
                  if (amo_fetch_logic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amoord;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMIND:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amomind;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMAXD:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amomaxd;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMINUD:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amominud;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              `RV64_AMOMAXUD:
                begin
                  if (amo_fetch_arithmetic_p != e_none) begin
                    decode.fu_op = e_dcache_opcode_amomaxud;
                  end else begin
                    illegal_instr = 1'b1;
                  end
                end
              default : illegal_instr = 1'b1;
            endcase
          end
        default : illegal_instr = 1'b1;
      endcase

      if (fe_exc_not_instr_i)
        begin
          decode = '0;
          casez (fe_exc_i)
            e_instr_access_fault: decode.instr_access_fault = 1'b1;
            e_instr_page_fault  : decode.instr_page_fault   = 1'b1;
            e_itlb_miss         : decode.itlb_miss          = 1'b1;
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
        `RV64_STORE_OP:
          imm = `rv64_signext_s_imm(instr);
        `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP:
          imm = `rv64_signext_i_imm(instr);
        `RV64_SYSTEM_OP:
          imm = `rv64_signext_c_imm(instr);
        default: begin end
      endcase
    end

endmodule

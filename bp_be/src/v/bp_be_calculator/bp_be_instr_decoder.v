/**
 *
 * Name:
 *   bp_be_instr_decoder.v
 * 
 * Description:
 *   BlackParrot instruction decoder for translating RISC-V instructions into pipeline control
 *     signals. Currently supports most of rv64i with the exception of fences and csrs.
 *
 * Parameters:
 *
 * Inputs:
 *   instr_i          - The RISC-V instruction to decode
 *
 * Outputs:
 *   decode_o         - Control signals for the pipeline
 *   illegal_instr_o  - Flag to indicate that the input instruction is illegal
 *   
 * Keywords:
 *   calculator, rv64i, instruction, decode
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
 import bp_be_pkg::*;
 #(// Generated parameters
   localparam instr_width_lp = rv64_instr_width_gp
   , localparam decode_width_lp = `bp_be_decode_width
   )
  (input                             instr_v_i
   , input [instr_width_lp-1:0]      instr_i
   , input                           fe_exc_not_instr_i
   , input bp_fe_exception_code_e    fe_exc_i

   , output [decode_width_lp-1:0]    decode_o
   );

// Cast input and output ports 
rv64_instr_s   instr;
bp_be_decode_s decode;

assign instr           = instr_i;
assign decode_o        = decode;

logic illegal_instr;

// Decode logic 
always_comb 
  begin
    // Set decoded defaults
    // NOPs are set after bypassing for critical path reasons
    decode               = '0;
    decode.v             = 1'b1;
    decode.instr_v       = 1'b1;

    // Destination pipe
    decode.pipe_comp_v   = '0;
    decode.pipe_int_v    = '0;
    decode.pipe_mul_v    = '0;
    decode.pipe_mem_v    = '0;
    decode.pipe_fp_v     = '0;

    // R/W signals
    decode.irf_w_v       = '0;
    decode.frf_w_v       = '0;
    decode.dcache_r_v    = '0;
    decode.dcache_w_v    = '0;

    // Metadata signals
    decode.mem_v         = '0;
    decode.csr_v         = '0;

    // Fence signals
    decode.fencei_v      = '0;

    // Decode metadata
    decode.fp_not_int_v  = '0;
    decode.jmp_v         = '0;
    decode.br_v          = '0;
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
          decode.pipe_int_v = 1'b1;
          decode.irf_w_v    = 1'b1;
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
          decode.pipe_int_v = 1'b1;
          decode.irf_w_v    = 1'b1;
          decode.jmp_v      = 1'b1;
          decode.baddr_sel  = e_baddr_is_pc;
          decode.result_sel = e_result_from_pc_plus4;
        end
      `RV64_JALR_OP : 
        begin
          decode.pipe_int_v = 1'b1;
          decode.irf_w_v    = 1'b1;
          decode.jmp_v      = 1'b1;
          decode.baddr_sel  = e_baddr_is_rs1;
          decode.result_sel = e_result_from_pc_plus4;
        end
      `RV64_BRANCH_OP : 
        begin
          decode.pipe_int_v = 1'b1;
          decode.br_v       = 1'b1;
          unique casez (instr)
            `RV64_BEQ  : decode.fu_op = e_int_op_eq;
            `RV64_BNE  : decode.fu_op = e_int_op_ne;
            `RV64_BLT  : decode.fu_op = e_int_op_slt; 
            `RV64_BGE  : decode.fu_op = e_int_op_sge;
            `RV64_BLTU : decode.fu_op = e_int_op_sltu;
            `RV64_BGEU : decode.fu_op = e_int_op_sgeu;
            default : illegal_instr = 1'b1;
          endcase
          decode.src1_sel   = e_src1_is_rs1;
          decode.src2_sel   = e_src2_is_rs2;
          decode.baddr_sel  = e_baddr_is_pc;
          decode.result_sel = e_result_from_alu;
        end
      `RV64_LOAD_OP : 
        begin
          decode.pipe_mem_v = 1'b1;
          decode.irf_w_v    = 1'b1;
          decode.dcache_r_v = 1'b1;
          decode.mem_v      = 1'b1;
          unique casez (instr)
            `RV64_LB : decode.fu_op = e_lb;
            `RV64_LH : decode.fu_op = e_lh;
            `RV64_LW : decode.fu_op = e_lw;
            `RV64_LBU: decode.fu_op = e_lbu;
            `RV64_LHU: decode.fu_op = e_lhu;
            `RV64_LWU: decode.fu_op = e_lwu;
            `RV64_LD : decode.fu_op = e_ld;
            default : illegal_instr = 1'b1;
          endcase
        end
      `RV64_STORE_OP : 
        begin
          decode.pipe_mem_v = 1'b1;
          decode.dcache_w_v = 1'b1;
          decode.mem_v      = 1'b1;
          unique casez (instr)
            `RV64_SB : decode.fu_op = e_sb;
            `RV64_SH : decode.fu_op = e_sh;
            `RV64_SW : decode.fu_op = e_sw;
            `RV64_SD : decode.fu_op = e_sd;
            default : illegal_instr = 1'b1;
          endcase
        end
      `RV64_MISC_MEM_OP : 
        begin
          decode.pipe_comp_v = 1'b1;
          unique casez (instr)
            `RV64_FENCE   : begin end
            `RV64_FENCE_I : decode.fencei_v = 1'b1;
            default : illegal_instr = 1'b1;
          endcase
        end
      `RV64_SYSTEM_OP : 
        begin
          decode.pipe_mem_v = 1'b1;
          decode.csr_v = 1'b1;
          unique casez (instr)
            `RV64_ECALL      : decode.fu_op = e_ecall;
            `RV64_EBREAK     : decode.fu_op = e_ebreak;
            `RV64_MRET       : decode.fu_op = e_mret;
            `RV64_SRET       : decode.fu_op = e_sret;
            `RV64_WFI        : decode.fu_op = e_wfi;
            `RV64_SFENCE_VMA : decode.fu_op = e_sfence_vma;
            default: 
              begin
                decode.irf_w_v     = 1'b1;
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
            `RV64_LRW: decode.fu_op = e_lrw;
            `RV64_SCW: decode.fu_op = e_scw;
            `RV64_LRD: decode.fu_op = e_lrd;
            `RV64_SCD: decode.fu_op = e_scd;
            default : illegal_instr = 1'b1;
          endcase
        end
      default : illegal_instr = 1'b1;
    endcase

    if (fe_exc_not_instr_i)
      begin
        decode = '0;
        decode.v           = 1'b1;
        decode.pipe_mem_v  = 1'b1;
        decode.csr_v = (fe_exc_i != e_itlb_miss);
        decode.mem_v = (fe_exc_i == e_itlb_miss);
        casez (fe_exc_i)
          e_illegal_instr     : decode.fu_op = e_op_illegal_instr;
          e_instr_misaligned  : decode.fu_op = e_op_instr_misaligned;
          e_instr_access_fault: decode.fu_op = e_op_instr_access_fault;
          e_itlb_miss         : decode.fu_op = e_itlb_fill;
        endcase
      end
    else if (illegal_instr)
      begin
        decode = '0;
        decode.v           = 1'b1;
        decode.pipe_mem_v  = 1'b1;
        decode.csr_v = 1'b1;
        decode.fu_op       = e_op_illegal_instr;
      end
  end

endmodule : bp_be_instr_decoder

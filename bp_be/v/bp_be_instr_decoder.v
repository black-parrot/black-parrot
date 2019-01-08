/**
 *
 * bp_be_instr_decoder.v
 *
 */

`include "bsg_defines.v"

`include "bp_be_rv_defines.vh"
`include "bp_be_internal_if.vh"

module bp_be_instr_decoder 
 #(parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"

   ,localparam instr_width_lp=`bp_be_instr_width
   ,localparam decode_width_lp=`bp_be_decode_width
   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   )
  (input logic                          fe_nop_v_i
   ,input logic                         be_nop_v_i
   ,input logic                         me_nop_v_i
   ,input logic [instr_width_lp-1:0]    instr_i

   ,output logic [decode_width_lp-1:0]  decode_o
   ,output logic                        illegal_instr_o
   );

`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_be_instr_s instr;
bp_be_decode_s decode;

assign instr = instr_i;
assign decode_o = decode;

// Decode logic 
always_comb begin
    decode.fe_nop_v      = '0; 
    decode.be_nop_v      = '0; 
    decode.me_nop_v      = '0; 

    decode.pipe_comp_v   = '0;
    decode.pipe_int_v    = '0;
    decode.pipe_mul_v    = '0;
    decode.pipe_mem_v    = '0;
    decode.pipe_fp_v     = '0;
    decode.irf_w_v       = '0;
    decode.frf_w_v       = '0;
    decode.csr_w_v       = '0;
    decode.mhartid_r_v   = '0;
    decode.dcache_w_v    = '0;
    decode.dcache_r_v    = '0;
    decode.fp_not_int_v  = '0;
    decode.cache_miss_v  = '0;
    decode.exception_v   = '0;
    decode.ret_v         = '0;
    decode.amo_v         = '0;
    decode.llop_v        = '0;
    decode.jmp_v         = '0;
    decode.br_v          = '0;
    decode.op32_v        = '0;
    decode.toggle_v      = '0;

    decode.fu_op         = 'X;
    decode.rs1_addr      = instr.rs1_addr;
    decode.rs2_addr      = instr.rs2_addr;
    decode.rd_addr       = instr.rd_addr;

    decode.src1_sel      = bp_be_src1_e'('X);
    decode.src2_sel      = bp_be_src2_e'('X);
    decode.baddr_sel     = bp_be_baddr_e'('X);
    decode.result_sel    = bp_be_result_e'('X);

    illegal_instr_o = '0;

    unique casez(instr.opcode) 
        `RV64_OP_OP, `RV64_OP_32_OP: begin
            decode.irf_w_v = 1'b1;
            decode.op32_v = (instr.opcode == `RV64_OP_32_OP);
            casez(instr)
                `RV64_ADD, `RV64_ADDW: decode.fu_op = e_int_op_add;
                `RV64_SUB, `RV64_SUBW: decode.fu_op = e_int_op_sub;
                `RV64_SLL, `RV64_SLLW: decode.fu_op = e_int_op_sll; 
                `RV64_SRL, `RV64_SRLW: decode.fu_op = e_int_op_srl;
                `RV64_SRA, `RV64_SRAW: decode.fu_op = e_int_op_sra;
                `RV64_SLT            : decode.fu_op = e_int_op_slt; 
                `RV64_SLTU           : decode.fu_op = e_int_op_sltu;
                `RV64_XOR            : decode.fu_op = e_int_op_xor;
                `RV64_OR             : decode.fu_op = e_int_op_or;
                `RV64_AND            : decode.fu_op = e_int_op_and;
                default: illegal_instr_o = 1'b1;
            endcase

            decode.pipe_int_v = 1'b1;
            decode.src1_sel = e_src1_is_rs1;
            decode.src2_sel = e_src2_is_rs2;
            decode.result_sel = e_result_from_alu;
        end
        `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP: begin
            decode.irf_w_v = 1'b1;
            decode.op32_v = (instr.opcode == `RV64_OP_IMM_32_OP);
            casez(instr)
                `RV64_ADDI, `RV64_ADDIW: decode.fu_op = e_int_op_add;
                `RV64_SLLI, `RV64_SLLIW: decode.fu_op = e_int_op_sll;
                `RV64_SRLI, `RV64_SRLIW: decode.fu_op = e_int_op_srl;
                `RV64_SRAI, `RV64_SRAIW: decode.fu_op = e_int_op_sra;
                `RV64_SLTI             : decode.fu_op = e_int_op_slt;
                `RV64_SLTIU            : decode.fu_op = e_int_op_sltu;
                `RV64_XORI             : decode.fu_op = e_int_op_xor;
                `RV64_ORI              : decode.fu_op = e_int_op_or;
                `RV64_ANDI             : decode.fu_op = e_int_op_and;
                default: illegal_instr_o = 1'b1;
            endcase

            decode.pipe_int_v = 1'b1;
            decode.src1_sel = e_src1_is_rs1;
            decode.src2_sel = e_src2_is_imm;
            decode.result_sel = e_result_from_alu;
        end
        `RV64_LUI_OP: begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v = 1'b1;
            decode.fu_op = e_int_op_pass_src2;
            decode.src2_sel = e_src2_is_imm;
            decode.result_sel = e_result_from_alu;
        end
        `RV64_AUIPC_OP: begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v = 1'b1;
            decode.fu_op = e_int_op_add;
            decode.src1_sel = e_src1_is_pc;
            decode.src2_sel = e_src2_is_imm;
            decode.result_sel = e_result_from_alu;
        end
        `RV64_JAL_OP: begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v   = 1'b1;
            decode.jmp_v    = 1'b1;
            decode.baddr_sel = e_baddr_is_pc;
            decode.result_sel = e_result_from_pc_plus4;
        end
        `RV64_JALR_OP: begin
            decode.pipe_int_v = 1'b1;
            decode.irf_w_v = 1'b1;
            decode.jmp_v  = 1'b1;
            decode.baddr_sel = e_baddr_is_rs1;
            decode.result_sel = e_result_from_pc_plus4;
        end
        `RV64_BRANCH_OP: begin
            decode.pipe_int_v = 1'b1;
            decode.br_v = 1'b1;
            casez(instr)
                `RV64_BNE, `RV64_BGE, `RV64_BGEU : decode.toggle_v = 1'b1;
                default : decode.toggle_v = 1'b0;
            endcase
            casez(instr)
                `RV64_BEQ , `RV64_BNE  : decode.fu_op = e_int_op_eq;
                `RV64_BLT , `RV64_BGE  : decode.fu_op = e_int_op_slt;
                `RV64_BLTU, `RV64_BGEU : decode.fu_op = e_int_op_sltu;
                default : illegal_instr_o = 1'b1;
            endcase
            decode.src1_sel = e_src1_is_rs1;
            decode.src2_sel = e_src2_is_rs2;
            decode.baddr_sel = e_baddr_is_pc;
            decode.result_sel = e_result_from_alu;
        end
        `RV64_LOAD_OP: begin
            decode.pipe_mem_v = 1'b1;
            decode.irf_w_v = 1'b1;
            decode.dcache_r_v = 1'b1;
            casez(instr)
                `RV64_LB : decode.fu_op = e_lb;
                `RV64_LH : decode.fu_op = e_lh;
                `RV64_LW : decode.fu_op = e_lw;
                `RV64_LBU: decode.fu_op = e_lbu;
                `RV64_LHU: decode.fu_op = e_lhu;
                `RV64_LWU: decode.fu_op = e_lwu;
                `RV64_LD : decode.fu_op = e_ld;
                default: illegal_instr_o = 1'b1;
            endcase
        end
        `RV64_STORE_OP: begin
            decode.pipe_mem_v = 1'b1;
            decode.dcache_w_v = 1'b1;
            casez(instr)
                `RV64_SB : decode.fu_op = e_sb;
                `RV64_SH : decode.fu_op = e_sh;
                `RV64_SW : decode.fu_op = e_sw;
                `RV64_SD : decode.fu_op = e_sd;
                default: illegal_instr_o = 1'b1;
            endcase
        end
        `RV64_MISC_MEM_OP: begin
            /* TODO: Danger zone.  These are implemented as nops for now, but we have to leave 
             * them in to avoid problems with riscv-tests. We could modify riscv-tests, but
             * this seems like a cleaner approach for now. 
             */ 
            decode.pipe_int_v   = 1'b1;
        end
        `RV64_SYSTEM_OP: begin
            /* TODO: Extremely limited CSR support (just mhartid) */
            decode.pipe_int_v = 1'b1;
            case(instr[31:20])
                12'hf14: begin 
                    decode.irf_w_v     = 1'b1;
                    decode.mhartid_r_v = 1'b1;
                end
                default: decode.exception_v = 1'b1;
            endcase

        end

        default   : begin
            illegal_instr_o = 1'b1;
        end
    endcase

    if(fe_nop_v_i | be_nop_v_i | me_nop_v_i | illegal_instr_o) begin
        decode             = '0;
        decode.fe_nop_v    = fe_nop_v_i;
        decode.be_nop_v    = be_nop_v_i;
        decode.me_nop_v    = me_nop_v_i;
        decode.pipe_comp_v = 1'b1;
    end
end

endmodule : bp_be_instr_decoder


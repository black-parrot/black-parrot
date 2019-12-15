/**
 *
 * bp_common_rv_defines.v
 * Based off of: https://bitbucket.org/taylor-bsg/bsg_manycore/src/master
 *                                           /v/vanilla_bean/parameters.v
 * TODO: Make opcodes into an enum, same with CSR defines
 */

`ifndef BP_COMMON_RV_DEFINES_VH
`define BP_COMMON_RV_DEFINES_VH

/* RISCV definitions */
`define RV64_LUI_OP        7'b0110111
`define RV64_AUIPC_OP      7'b0010111
`define RV64_JAL_OP        7'b1101111
`define RV64_JALR_OP       7'b1100111
`define RV64_BRANCH_OP     7'b1100011
`define RV64_LOAD_OP       7'b0000011
`define RV64_STORE_OP      7'b0100011
`define RV64_OP_IMM_OP     7'b0010011
`define RV64_OP_OP         7'b0110011
`define RV64_MISC_MEM_OP   7'b0001111
`define RV64_SYSTEM_OP     7'b1110011
`define RV64_OP_IMM_32_OP  7'b0011011
`define RV64_OP_32_OP      7'b0111011
`define RV64_AMO_OP        7'b0101111
`define RV64_FLOAD_OP      7'b0000111
`define RV64_FSTORE_OP     7'b0100111
`define RV64_FP_OP         7'b1010011
`define RV64_FMADD_OP      7'b1000011
`define RV64_FMSUB_OP      7'b1000111
`define RV64_FNMSUB_OP     7'b1001011
`define RV64_FNMADD_OP     7'b1001111

// Some useful RV64 instruction macros
`define rv64_r_type(op, funct3, funct7) {``funct7``,{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define rv64_i_type(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define rv64_s_type(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define rv64_u_type(op)                 {{20{1'b?}},{5{1'b?}},``op``}
`define rv64_fma_type(op, pr2)          {{5{1'b?}},``pr2``,{5{1'b?}},{5{1'b?}},{3{3'b?}},{5{1'b?}},``op``}

// RV64 Immediate sign extension macros
`define rv64_signext_i_imm(instr) {{53{``instr``[31]}},``instr``[30:20]}
`define rv64_signext_s_imm(instr) {{53{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define rv64_signext_b_imm(instr) {{52{``instr``[31]}},``instr``[7],``instr``[30:25]  \
                                       ,``instr``[11:8], {1'b0}}
`define rv64_signext_u_imm(instr) {{32{``instr``[31]}},``instr``[31:12], {12{1'b0}}}
`define rv64_signext_j_imm(instr) {{44{``instr``[31]}},``instr``[19:12],``instr``[20] \
                                       ,``instr``[30:21], {1'b0}}
`define rv64_signext_c_imm(instr) {{59{1'b0}},``instr``[19:15]}

// I extension
`define RV64_LUI        `rv64_u_type(`RV64_LUI_OP)
`define RV64_AUIPC      `rv64_u_type(`RV64_AUIPC_OP)
`define RV64_JAL        `rv64_u_type(`RV64_JAL_OP)
`define RV64_JALR       `rv64_i_type(`RV64_JALR_OP,3'b000)
`define RV64_BEQ        `rv64_s_type(`RV64_BRANCH_OP,3'b000)
`define RV64_BNE        `rv64_s_type(`RV64_BRANCH_OP,3'b001)
`define RV64_BLT        `rv64_s_type(`RV64_BRANCH_OP,3'b100)
`define RV64_BGE        `rv64_s_type(`RV64_BRANCH_OP,3'b101)
`define RV64_BLTU       `rv64_s_type(`RV64_BRANCH_OP,3'b110)
`define RV64_BGEU       `rv64_s_type(`RV64_BRANCH_OP,3'b111)
`define RV64_LB         `rv64_i_type(`RV64_LOAD_OP,3'b000)
`define RV64_LH         `rv64_i_type(`RV64_LOAD_OP,3'b001)
`define RV64_LW         `rv64_i_type(`RV64_LOAD_OP,3'b010)
`define RV64_LD         `rv64_i_type(`RV64_LOAD_OP,3'b011)
`define RV64_LBU        `rv64_i_type(`RV64_LOAD_OP,3'b100)
`define RV64_LHU        `rv64_i_type(`RV64_LOAD_OP,3'b101)
`define RV64_LWU        `rv64_i_type(`RV64_LOAD_OP,3'b110)
`define RV64_SB         `rv64_s_type(`RV64_STORE_OP,3'b000)
`define RV64_SH         `rv64_s_type(`RV64_STORE_OP,3'b001)
`define RV64_SW         `rv64_s_type(`RV64_STORE_OP,3'b010)
`define RV64_SD         `rv64_s_type(`RV64_STORE_OP,3'b011)
`define RV64_ADDI       `rv64_i_type(`RV64_OP_IMM_OP,3'b000)
`define RV64_ADDIW      `rv64_i_type(`RV64_OP_IMM_32_OP,3'b000)
`define RV64_SLTI       `rv64_i_type(`RV64_OP_IMM_OP,3'b010)
`define RV64_SLTIU      `rv64_i_type(`RV64_OP_IMM_OP,3'b011)
`define RV64_XORI       `rv64_i_type(`RV64_OP_IMM_OP,3'b100)
`define RV64_ORI        `rv64_i_type(`RV64_OP_IMM_OP,3'b110)
`define RV64_ANDI       `rv64_i_type(`RV64_OP_IMM_OP,3'b111)
`define RV64_SLLI       `rv64_r_type(`RV64_OP_IMM_OP,3'b001,7'b000000?)
`define RV64_SLLIW      `rv64_r_type(`RV64_OP_IMM_32_OP,3'b001,7'b000000?)
`define RV64_SRLI       `rv64_r_type(`RV64_OP_IMM_OP,3'b101,7'b000000?)
`define RV64_SRLIW      `rv64_r_type(`RV64_OP_IMM_32_OP,3'b101,7'b000000?)
`define RV64_SRAI       `rv64_r_type(`RV64_OP_IMM_OP,3'b101,7'b010000?)
`define RV64_SRAIW      `rv64_r_type(`RV64_OP_IMM_32_OP,3'b101,7'b010000?)
`define RV64_ADD        `rv64_r_type(`RV64_OP_OP,3'b000,7'b0000000)
`define RV64_ADDW       `rv64_r_type(`RV64_OP_32_OP,3'b000,7'b0000000)
`define RV64_SUB        `rv64_r_type(`RV64_OP_OP,3'b000,7'b0100000)
`define RV64_SUBW       `rv64_r_type(`RV64_OP_32_OP,3'b000,7'b0100000)
`define RV64_SLL        `rv64_r_type(`RV64_OP_OP,3'b001,7'b0000000)
`define RV64_SLLW       `rv64_r_type(`RV64_OP_32_OP,3'b001,7'b0000000)
`define RV64_SLT        `rv64_r_type(`RV64_OP_OP,3'b010,7'b0000000)
`define RV64_SLTU       `rv64_r_type(`RV64_OP_OP,3'b011,7'b0000000)
`define RV64_XOR        `rv64_r_type(`RV64_OP_OP,3'b100,7'b0000000)
`define RV64_SRL        `rv64_r_type(`RV64_OP_OP,3'b101,7'b0000000)
`define RV64_SRLW       `rv64_r_type(`RV64_OP_32_OP,3'b101,7'b0000000)
`define RV64_SRA        `rv64_r_type(`RV64_OP_OP,3'b101,7'b0100000)
`define RV64_SRAW       `rv64_r_type(`RV64_OP_32_OP,3'b101,7'b0100000)
`define RV64_OR         `rv64_r_type(`RV64_OP_OP,3'b110,7'b0000000)
`define RV64_AND        `rv64_r_type(`RV64_OP_OP,3'b111,7'b0000000)
`define RV64_CSRRW      `rv64_i_type(`RV64_SYSTEM_OP,3'b001)
`define RV64_CSRRS      `rv64_i_type(`RV64_SYSTEM_OP,3'b010)
`define RV64_CSRRC      `rv64_i_type(`RV64_SYSTEM_OP,3'b011)
`define RV64_CSRRWI     `rv64_i_type(`RV64_SYSTEM_OP,3'b101)
`define RV64_CSRRSI     `rv64_i_type(`RV64_SYSTEM_OP,3'b110)
`define RV64_CSRRCI     `rv64_i_type(`RV64_SYSTEM_OP,3'b111)
`define RV64_ECALL      32'b0000_0000_0000_0000_0000_0000_0111_0011
`define RV64_EBREAK     32'b0000_0000_0001_0000_0000_0000_0111_0011
`define RV64_URET       32'b0000_0000_0010_0000_0000_0000_0111_0011
`define RV64_SRET       32'b0001_0000_0010_0000_0000_0000_0111_0011
`define RV64_MRET       32'b0011_0000_0010_0000_0000_0000_0111_0011
`define RV64_DRET       32'b0111_1011_0010_0000_0000_0000_0111_0011
`define RV64_WFI        32'b0001_0000_0101_0000_0000_0000_0111_0011
`define RV64_SFENCE_VMA 32'b0001_001?_????_????_?000_0000_0111_0011
`define RV64_FENCE_I    32'b0000_0000_0000_0000_0001_0000_0000_1111
`define RV64_FENCE      32'b????_????_????_????_?000_????_?000_1111

// A extension
`define RV64_LRW        32'b0001_0??0_0000_????_?010_????_?010_1111
`define RV64_SCW        32'b0001_1???_????_????_?010_????_?010_1111
`define RV64_LRD        32'b0001_0??0_0000_????_?011_????_?010_1111
`define RV64_SCD        32'b0001_1???_????_????_?011_????_?010_1111

// M extension
`define RV64_MUL        `rv64_r_type(`RV64_OP_OP,3'b000,7'b0000001)
`define RV64_MULH       `rv64_r_type(`RV64_OP_OP,3'b001,7'b0000001)
`define RV64_MULHSU     `rv64_r_type(`RV64_OP_OP,3'b010,7'b0000001)
`define RV64_MULHU      `rv64_r_type(`RV64_OP_OP,3'b011,7'b0000001)
`define RV64_DIV        `rv64_r_type(`RV64_OP_OP,3'b100,7'b0000001)
`define RV64_DIVU       `rv64_r_type(`RV64_OP_OP,3'b101,7'b0000001)
`define RV64_REM        `rv64_r_type(`RV64_OP_OP,3'b110,7'b0000001)
`define RV64_REMU       `rv64_r_type(`RV64_OP_OP,3'b111,7'b0000001)

`define RV64_MULW       `rv64_r_type(`RV64_OP_32_OP,3'b000,7'b0000001)
`define RV64_DIVW       `rv64_r_type(`RV64_OP_32_OP,3'b100,7'b0000001)
`define RV64_DIVUW      `rv64_r_type(`RV64_OP_32_OP,3'b101,7'b0000001)
`define RV64_REMW       `rv64_r_type(`RV64_OP_32_OP,3'b110,7'b0000001)
`define RV64_REMUW      `rv64_r_type(`RV64_OP_32_OP,3'b111,7'b0000001)

// F extension
`define RV64_FL_W       `rv64_i_type(`RV64_FLOAD_OP,3'b010)
`define RV64_FS_W       `rv64_i_type(`RV64_FSTORE_OP,3'b010)
`define RV64_FMADD_S    `rv64_fma_type(`RV64_FMADD_OP,2'b00)
`define RV64_FMSUB_S    `rv64_fma_type(`RV64_FMSUB_OP,2'b00)
`define RV64_FNMSUB_S   `rv64_fma_type(`RV64_FNMSUB_OP,2'b00)
`define RV64_FNMADD_S   `rv64_fma_type(`RV64_FNMADD_OP,2'b00)
`define RV64_FADD_S     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0000000)
`define RV64_FSUB_S     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0000100)
`define RV64_FMUL_S     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0001000)// Not implemented
// Not implemented
// `define RV64_FDIV_S
// `define RV64_FSQRT_S
`define RV64_FSGNJ_S    `rv64_r_type(`RV64_FP_OP,3'b000,7'b0010000)
`define RV64_FSGNJN_S   `rv64_r_type(`RV64_FP_OP,3'b001,7'b0010000)
`define RV64_FSGNJX_S   `rv64_r_type(`RV64_FP_OP,3'b010,7'b0010000)
`define RV64_FMIN_S     `rv64_r_type(`RV64_FP_OP,3'b000,7'b0010100)
`define RV64_FMAX_S     `rv64_r_type(`RV64_FP_OP,3'b001,7'b0010100)
`define RV64_FCVT_WS    32'b1100000_00000_?????_???_?????_1010011
`define RV64_FCVT_WUS   32'b1100000_00001_?????_???_?????_1010011
`define RV64_FMV_XW     32'b1110000_00000_?????_000_?????_1010011
`define RV64_FEQ_S      `rv64_r_type(`RV64_FP_OP,3'b010,7'b1010000)
`define RV64_FLT_S      `rv64_r_type(`RV64_FP_OP,3'b001,7'b1010000)
`define RV64_FLE_S      `rv64_r_type(`RV64_FP_OP,3'b000,7'b1010000)
`define RV64_FCLASS_S   32'b1110000_00000_?????_001_?????_1010011
`define RV64_FCVT_SW    32'b1101000_00000_?????_???_?????_1010011
`define RV64_FCVT_SWU   32'b1101000_00001_?????_???_?????_1010011
`define RV64_FMV_WX     32'b1111000_00000_?????_000_?????_1010011
`define RV64_FCVT_LS    32'b1100000_00010_?????_???_?????_1010011
`define RV64_FCVT_LUS   32'b1100000_00011_?????_???_?????_1010011
`define RV64_FCVT_SL    32'b1101000_00010_?????_???_?????_1010011
`define RV64_FCVT_SLU   32'b1101000_00011_?????_???_?????_1010011

// D extension
`define RV64_FL_D       `rv64_i_type(`RV64_FLOAD_OP,3'b011)
`define RV64_FS_D       `rv64_i_type(`RV64_FSTORE_OP,3'b11)
`define RV64_FMADD_D    `rv64_fma_type(`RV64_FMADD_OP,2'b01)
`define RV64_FMSUB_D    `rv64_fma_type(`RV64_FMSUB_OP,2'b01)
`define RV64_FNMSUB_D   `rv64_fma_type(`RV64_FNMSUB_OP,2'b01)
`define RV64_FNMADD_D   `rv64_fma_type(`RV64_FNMADD_OP,2'b01)
`define RV64_FADD_D     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0000001)
`define RV64_FSUB_D     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0000101)
`define RV64_FMUL_D     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0001001)
// Not implemented
// `define RV64_FDIV_D
// `define RV64_FSQRT_D
`define RV64_FSGNJ_D    `rv64_r_type(`RV64_FP_OP,3'b000,7'b0010001)
`define RV64_FSGNJN_D   `rv64_r_type(`RV64_FP_OP,3'b001,7'b0010001)
`define RV64_FSGNJX_D   `rv64_r_type(`RV64_FP_OP,3'b010,7'b0010001)
`define RV64_FMIN_D     `rv64_r_type(`RV64_FP_OP,3'b000,7'b0010101)
`define RV64_FMAX_D     `rv64_r_type(`RV64_FP_OP,3'b001,7'b0010101)
`define RV64_FCVT_SD    32'b0100000_00001_?????_???_?????_1010011
`define RV64_FCVT_DS    32'b0100001_00000_?????_???_?????_1010011
`define RV64_FMV_DX     32'b1111001_00000_?????_000_?????_1010011
`define RV64_FEQ_D      `rv64_r_type(`RV64_FP_OP,3'b010,7'b1010001)
`define RV64_FLT_D      `rv64_r_type(`RV64_FP_OP,3'b001,7'b1010001)
`define RV64_FLE_D      `rv64_r_type(`RV64_FP_OP,3'b000,7'b1010001)
`define RV64_FCLASS_D   32'b1110001_00000_?????_001_?????_1010011
`define RV64_FCVT_WD    32'b1100001_00000_?????_???_?????_1010011
`define RV64_FCVT_WUD   32'b1100001_00001_?????_???_?????_1010011
`define RV64_FCVT_DW    32'b1101001_00000_?????_???_?????_1010011
`define RV64_FCVT_DWU   32'b1101001_00001_?????_???_?????_1010011
`define RV64_FCVT_LD    32'b1100001_00010_?????_???_?????_1010011
`define RV64_FCVT_LUD   32'b1100001_00011_?????_???_?????_1010011
`define RV64_FMV_XD     32'b1110001_00000_?????_000_?????_1010011
`define RV64_FCVT_DL    32'b1101001_00010_?????_???_?????_1010011
`define RV64_FCVT_DLU   32'b1101001_00011_?????_???_?????_1010011
`define RV64_FCVT_DX    32'b1111001_00000_?????_000_?????_1010011

`endif


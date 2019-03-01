/**
 *
 * bp_be_rv_defines.v
 * Based off of: https://bitbucket.org/taylor-bsg/bsg_manycore/src/master
 *                                           /v/vanilla_bean/parameters.v
 * TODO: Make opcodes into an enum
 */

`ifndef BP_BE_RV_DEFINES_VH
`define BP_BE_RV_DEFINES_VH

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

// Some useful RV64 instruction macros
`define rv64_r_type(op, funct3, funct7) {``funct7``,{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define rv64_i_type(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define rv64_s_type(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define rv64_u_type(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// RV64 Immediate sign extension macros
`define rv64_signext_i_imm(instr) {{53{``instr``[31]}},``instr``[30:20]}
`define rv64_signext_s_imm(instr) {{53{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define rv64_signext_b_imm(instr) {{52{``instr``[31]}},``instr``[7],``instr``[30:25]  \
                                       ,``instr``[11:8], {1'b0}}
`define rv64_signext_u_imm(instr) {{32{``instr``[31]}},``instr``[31:12], {12{1'b0}}}
`define rv64_signext_j_imm(instr) {{44{``instr``[31]}},``instr``[19:12],``instr``[20] \
                                       ,``instr``[30:21], {1'b0}}

`define RV64_LUI       `rv64_u_type(`RV64_LUI_OP)
`define RV64_AUIPC     `rv64_u_type(`RV64_AUIPC_OP)
`define RV64_JAL       `rv64_u_type(`RV64_JAL_OP)
`define RV64_JALR      `rv64_i_type(`RV64_JALR_OP,3'b000)
`define RV64_BEQ       `rv64_s_type(`RV64_BRANCH_OP,3'b000)
`define RV64_BNE       `rv64_s_type(`RV64_BRANCH_OP,3'b001)
`define RV64_BLT       `rv64_s_type(`RV64_BRANCH_OP,3'b100)
`define RV64_BGE       `rv64_s_type(`RV64_BRANCH_OP,3'b101)
`define RV64_BLTU      `rv64_s_type(`RV64_BRANCH_OP,3'b110)
`define RV64_BGEU      `rv64_s_type(`RV64_BRANCH_OP,3'b111)
`define RV64_LB        `rv64_i_type(`RV64_LOAD_OP,3'b000)
`define RV64_LH        `rv64_i_type(`RV64_LOAD_OP,3'b001)
`define RV64_LW        `rv64_i_type(`RV64_LOAD_OP,3'b010)
`define RV64_LD        `rv64_i_type(`RV64_LOAD_OP,3'b011)
`define RV64_LBU       `rv64_i_type(`RV64_LOAD_OP,3'b100)
`define RV64_LHU       `rv64_i_type(`RV64_LOAD_OP,3'b101)
`define RV64_LWU       `rv64_i_type(`RV64_LOAD_OP,3'b110)
`define RV64_SB        `rv64_s_type(`RV64_STORE_OP,3'b000)
`define RV64_SH        `rv64_s_type(`RV64_STORE_OP,3'b001)
`define RV64_SW        `rv64_s_type(`RV64_STORE_OP,3'b010)
`define RV64_SD        `rv64_s_type(`RV64_STORE_OP,3'b011)
`define RV64_ADDI      `rv64_i_type(`RV64_OP_IMM_OP,3'b000)
`define RV64_ADDIW     `rv64_i_type(`RV64_OP_IMM_32_OP,3'b000)
`define RV64_SLTI      `rv64_i_type(`RV64_OP_IMM_OP,3'b010)
`define RV64_SLTIU     `rv64_i_type(`RV64_OP_IMM_OP,3'b011)
`define RV64_XORI      `rv64_i_type(`RV64_OP_IMM_OP,3'b100)
`define RV64_ORI       `rv64_i_type(`RV64_OP_IMM_OP,3'b110)
`define RV64_ANDI      `rv64_i_type(`RV64_OP_IMM_OP,3'b111)
`define RV64_SLLI      `rv64_r_type(`RV64_OP_IMM_OP,3'b001,7'b000000?)
`define RV64_SLLIW     `rv64_r_type(`RV64_OP_IMM_32_OP,3'b001,7'b000000?)
`define RV64_SRLI      `rv64_r_type(`RV64_OP_IMM_OP,3'b101,7'b000000?)
`define RV64_SRLIW     `rv64_r_type(`RV64_OP_IMM_32_OP,3'b101,7'b000000?)
`define RV64_SRAI      `rv64_r_type(`RV64_OP_IMM_OP,3'b101,7'b010000?)
`define RV64_SRAIW     `rv64_r_type(`RV64_OP_IMM_32_OP,3'b101,7'b010000?)
`define RV64_ADD       `rv64_r_type(`RV64_OP_OP,3'b000,7'b0000000)
`define RV64_ADDW      `rv64_r_type(`RV64_OP_32_OP,3'b000,7'b0000000)
`define RV64_SUB       `rv64_r_type(`RV64_OP_OP,3'b000,7'b0100000)
`define RV64_SUBW      `rv64_r_type(`RV64_OP_32_OP,3'b000,7'b0100000)
`define RV64_SLL       `rv64_r_type(`RV64_OP_OP,3'b001,7'b0000000)
`define RV64_SLLW      `rv64_r_type(`RV64_OP_32_OP,3'b001,7'b0000000)
`define RV64_SLT       `rv64_r_type(`RV64_OP_OP,3'b010,7'b0000000)
`define RV64_SLTU      `rv64_r_type(`RV64_OP_OP,3'b011,7'b0000000)
`define RV64_XOR       `rv64_r_type(`RV64_OP_OP,3'b100,7'b0000000)
`define RV64_SRL       `rv64_r_type(`RV64_OP_OP,3'b101,7'b0000000)
`define RV64_SRLW      `rv64_r_type(`RV64_OP_32_OP,3'b101,7'b0000000)
`define RV64_SRA       `rv64_r_type(`RV64_OP_OP,3'b101,7'b0100000)
`define RV64_SRAW      `rv64_r_type(`RV64_OP_32_OP,3'b101,7'b0100000)
`define RV64_OR        `rv64_r_type(`RV64_OP_OP,3'b110,7'b0000000)
`define RV64_AND       `rv64_r_type(`RV64_OP_OP,3'b111,7'b0000000)

`define rv64_nop_instr 32'b0000000_00000_00000_000_00000_0010011

`define RV64_MCYCLE_CSR_ADDR   12'hc00
`define RV64_MTIME_CSR_ADDR    12'hc01
`define RV64_MINSTRET_CSR_ADDR 12'hc02
`define RV64_MHARTID_CSR_ADDR  12'hf14
`define RV64_MTVEC_CSR_ADDR    12'h305

`endif

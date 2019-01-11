/**
 *
 * bp_be_rv_defines.v
 * Based off of: https://bitbucket.org/taylor-bsg/bsg_manycore/src/master
 *                                           /v/vanilla_bean/parameters.v
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
`define RV64_Rtype(op, funct3, funct7) {``funct7``,{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV64_Itype(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV64_Stype(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV64_Utype(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// RV64 Immediate sign extension macros
`define RV64_signext_Iimm(instr) {{53{``instr``[31]}},``instr``[30:20]}
`define RV64_signext_Simm(instr) {{53{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define RV64_signext_Bimm(instr) {{52{``instr``[31]}},``instr``[7],``instr``[30:25]  \
                                     ,``instr``[11:8], {1'b0}}
`define RV64_signext_Uimm(instr) {{32{``instr``[31]}},``instr``[31:12], {12{1'b0}}}
`define RV64_signext_Jimm(instr) {{44{``instr``[31]}},``instr``[19:12],``instr``[20] \
                                     ,``instr``[30:21], {1'b0}}

`define RV64_LUI       `RV64_Utype(`RV64_LUI_OP)
`define RV64_AUIPC     `RV64_Utype(`RV64_AUIPC_OP)
`define RV64_JAL       `RV64_Utype(`RV64_JAL_OP)
`define RV64_JALR      `RV64_Itype(`RV64_JALR_OP,3'b000)
`define RV64_BEQ       `RV64_Stype(`RV64_BRANCH_OP,3'b000)
`define RV64_BNE       `RV64_Stype(`RV64_BRANCH_OP,3'b001)
`define RV64_BLT       `RV64_Stype(`RV64_BRANCH_OP,3'b100)
`define RV64_BGE       `RV64_Stype(`RV64_BRANCH_OP,3'b101)
`define RV64_BLTU      `RV64_Stype(`RV64_BRANCH_OP,3'b110)
`define RV64_BGEU      `RV64_Stype(`RV64_BRANCH_OP,3'b111)
`define RV64_LB        `RV64_Itype(`RV64_LOAD_OP,3'b000)
`define RV64_LH        `RV64_Itype(`RV64_LOAD_OP,3'b001)
`define RV64_LW        `RV64_Itype(`RV64_LOAD_OP,3'b010)
`define RV64_LD        `RV64_Itype(`RV64_LOAD_OP,3'b011)
`define RV64_LBU       `RV64_Itype(`RV64_LOAD_OP,3'b100)
`define RV64_LHU       `RV64_Itype(`RV64_LOAD_OP,3'b101)
`define RV64_LWU       `RV64_Itype(`RV64_LOAD_OP,3'b110)
`define RV64_SB        `RV64_Stype(`RV64_STORE_OP,3'b000)
`define RV64_SH        `RV64_Stype(`RV64_STORE_OP,3'b001)
`define RV64_SW        `RV64_Stype(`RV64_STORE_OP,3'b010)
`define RV64_SD        `RV64_Stype(`RV64_STORE_OP,3'b011)
`define RV64_ADDI      `RV64_Itype(`RV64_OP_IMM_OP,3'b000)
`define RV64_ADDIW     `RV64_Itype(`RV64_OP_IMM_32_OP,3'b000)
`define RV64_SLTI      `RV64_Itype(`RV64_OP_IMM_OP,3'b010)
`define RV64_SLTIU     `RV64_Itype(`RV64_OP_IMM_OP,3'b011)
`define RV64_XORI      `RV64_Itype(`RV64_OP_IMM_OP,3'b100)
`define RV64_ORI       `RV64_Itype(`RV64_OP_IMM_OP,3'b110)
`define RV64_ANDI      `RV64_Itype(`RV64_OP_IMM_OP,3'b111)
`define RV64_SLLI      `RV64_Rtype(`RV64_OP_IMM_OP,3'b001,7'b000000?)
`define RV64_SLLIW     `RV64_Rtype(`RV64_OP_IMM_32_OP,3'b001,7'b000000?)
`define RV64_SRLI      `RV64_Rtype(`RV64_OP_IMM_OP,3'b101,7'b000000?)
`define RV64_SRLIW     `RV64_Rtype(`RV64_OP_IMM_32_OP,3'b101,7'b000000?)
`define RV64_SRAI      `RV64_Rtype(`RV64_OP_IMM_OP,3'b101,7'b010000?)
`define RV64_SRAIW     `RV64_Rtype(`RV64_OP_IMM_32_OP,3'b101,7'b010000?)
`define RV64_ADD       `RV64_Rtype(`RV64_OP_OP,3'b000,7'b0000000)
`define RV64_ADDW      `RV64_Rtype(`RV64_OP_32_OP,3'b000,7'b0000000)
`define RV64_SUB       `RV64_Rtype(`RV64_OP_OP,3'b000,7'b0100000)
`define RV64_SUBW      `RV64_Rtype(`RV64_OP_32_OP,3'b000,7'b0100000)
`define RV64_SLL       `RV64_Rtype(`RV64_OP_OP,3'b001,7'b0000000)
`define RV64_SLLW      `RV64_Rtype(`RV64_OP_32_OP,3'b001,7'b0000000)
`define RV64_SLT       `RV64_Rtype(`RV64_OP_OP,3'b010,7'b0000000)
`define RV64_SLTU      `RV64_Rtype(`RV64_OP_OP,3'b011,7'b0000000)
`define RV64_XOR       `RV64_Rtype(`RV64_OP_OP,3'b100,7'b0000000)
`define RV64_SRL       `RV64_Rtype(`RV64_OP_OP,3'b101,7'b0000000)
`define RV64_SRLW      `RV64_Rtype(`RV64_OP_32_OP,3'b101,7'b0000000)
`define RV64_SRA       `RV64_Rtype(`RV64_OP_OP,3'b101,7'b0100000)
`define RV64_SRAW      `RV64_Rtype(`RV64_OP_32_OP,3'b101,7'b0100000)
`define RV64_OR        `RV64_Rtype(`RV64_OP_OP,3'b110,7'b0000000)
`define RV64_AND       `RV64_Rtype(`RV64_OP_OP,3'b111,7'b0000000)

`define RV64_nop_instr 32'b0000000_00000_00000_000_00000_0010011

localparam RV64_irf_els_gp        = 32;
localparam RV64_frf_els_gp        = 32;
localparam RV64_instr_width_gp    = 32;
localparam RV64_eaddr_width_gp    = 64;
localparam RV64_byte_width_gp     = 8;
localparam RV64_hword_width_gp    = 16;
localparam RV64_word_width_gp     = 32;
localparam RV64_dword_width_gp    = 64;
localparam RV64_reg_data_width_gp = 64;
localparam RV64_reg_addr_width_gp = 5;
localparam RV64_shamt_width_gp    = 6;
localparam RV64_opcode_width_gp   = 7;
localparam RV64_funct3_width_gp   = 3;
localparam RV64_funct7_width_gp   = 7;

/* TODO: I should live somewhere else */
localparam bp_pc_entry_point_gp   = 32'h80000248;

`endif

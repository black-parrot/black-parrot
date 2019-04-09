/**
 *
 * bp_be_rv_defines.v
 * Based off of: https://bitbucket.org/taylor-bsg/bsg_manycore/src/master
 *                                           /v/vanilla_bean/parameters.v
 * TODO: Make opcodes into an enum, same with CSR defines
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
`define RV64_CSRRW     `rv64_i_type(`RV64_SYSTEM_OP,3'b001)
`define RV64_CSRRS     `rv64_i_type(`RV64_SYSTEM_OP,3'b010)
`define RV64_CSRRC     `rv64_i_type(`RV64_SYSTEM_OP,3'b011)
`define RV64_CSRRWI    `rv64_i_type(`RV64_SYSTEM_OP,3'b101)
`define RV64_CSRRSI    `rv64_i_type(`RV64_SYSTEM_OP,3'b110)
`define RV64_CSRRCI    `rv64_i_type(`RV64_SYSTEM_OP,3'b111)

`define RV64_FUNCT12_MRET 12'b0011_0000_0010

`define rv64_nop_instr 32'b0000000_00000_00000_000_00000_0010011

`define RV64_PRIV_M_MODE 2'b11
`define RV64_PRIV_S_MODE 2'b01
`define RV64_PRIV_U_MODE 2'b00

`define RV64_MVENDORID_CSR_ADDR  12'hf11
`define RV64_MARCHID_CSR_ADDR    12'hf12
`define RV64_MIMPID_CSR_ADDR     12'hf12
`define RV64_MHARTID_CSR_ADDR    12'hf14

`define RV64_MSTATUS_CSR_ADDR    12'h300
`define RV64_MISA_CSR_ADDR       12'h301
`define RV64_MEDELEG_CSR_ADDR    12'h302
`define RV64_MIDELEG_CSR_ADDR    12'h303
`define RV64_MIE_CSR_ADDR        12'h304
`define RV64_MTVEC_CSR_ADDR      12'h305
`define RV64_MCOUNTEREN_CSR_ADDR 12'h306

`define RV64_MSCRATCH_CSR_ADDR   12'h340
`define RV64_MEPC_CSR_ADDR       12'h341
`define RV64_MCAUSE_CSR_ADDR     12'h342
`define RV64_MTVAL_CSR_ADDR      12'h343
`define RV64_MIP_CSR_ADDR        12'h344

`define RV64_PMPCFG0_CSR_ADDR    12'h3a0
`define RV64_PMPCFG2_CSR_ADDR    12'h3a2
`define RV64_PMPADDR0_CSR_ADDR   12'h3b0
`define RV64_PMPADDR1_CSR_ADDR   12'h3b1
`define RV64_PMPADDR2_CSR_ADDR   12'h3b2
`define RV64_PMPADDR3_CSR_ADDR   12'h3b3
`define RV64_PMPADDR4_CSR_ADDR   12'h3b4
`define RV64_PMPADDR5_CSR_ADDR   12'h3b5
`define RV64_PMPADDR6_CSR_ADDR   12'h3b6
`define RV64_PMPADDR7_CSR_ADDR   12'h3b7
`define RV64_PMPADDR8_CSR_ADDR   12'h3b8
`define RV64_PMPADDR9_CSR_ADDR   12'h3b9
`define RV64_PMPADDR10_CSR_ADDR  12'h3ba
`define RV64_PMPADDR11_CSR_ADDR  12'h3bb
`define RV64_PMPADDR12_CSR_ADDR  12'h3bc
`define RV64_PMPADDR13_CSR_ADDR  12'h3bd
`define RV64_PMPADDR14_CSR_ADDR  12'h3be
`define RV64_PMPADDR15_CSR_ADDR  12'h3bf

`define RV64_MCYCLE_CSR_ADDR        12'hb00
`define RV64_MINSTRET_CSR_ADDR      12'hb02
`define RV64_MHPMCOUNTER3_CSR_ADDR  12'hb03
`define RV64_MHPMCOUNTER4_CSR_ADDR  12'hb04
`define RV64_MHPMCOUNTER5_CSR_ADDR  12'hb05
`define RV64_MHPMCOUNTER6_CSR_ADDR  12'hb06
`define RV64_MHPMCOUNTER7_CSR_ADDR  12'hb07
`define RV64_MHPMCOUNTER8_CSR_ADDR  12'hb08
`define RV64_MHPMCOUNTER9_CSR_ADDR  12'hb09
`define RV64_MHPMCOUNTER10_CSR_ADDR 12'hb0a
`define RV64_MHPMCOUNTER11_CSR_ADDR 12'hb0b
`define RV64_MHPMCOUNTER12_CSR_ADDR 12'hb0c
`define RV64_MHPMCOUNTER13_CSR_ADDR 12'hb0d
`define RV64_MHPMCOUNTER14_CSR_ADDR 12'hb0e
`define RV64_MHPMCOUNTER15_CSR_ADDR 12'hb0f
`define RV64_MHPMCOUNTER16_CSR_ADDR 12'hb10
`define RV64_MHPMCOUNTER17_CSR_ADDR 12'hb11
`define RV64_MHPMCOUNTER18_CSR_ADDR 12'hb12
`define RV64_MHPMCOUNTER19_CSR_ADDR 12'hb13
`define RV64_MHPMCOUNTER20_CSR_ADDR 12'hb14
`define RV64_MHPMCOUNTER21_CSR_ADDR 12'hb15
`define RV64_MHPMCOUNTER22_CSR_ADDR 12'hb16
`define RV64_MHPMCOUNTER23_CSR_ADDR 12'hb17
`define RV64_MHPMCOUNTER24_CSR_ADDR 12'hb18
`define RV64_MHPMCOUNTER25_CSR_ADDR 12'hb19
`define RV64_MHPMCOUNTER26_CSR_ADDR 12'hb1a
`define RV64_MHPMCOUNTER27_CSR_ADDR 12'hb1b
`define RV64_MHPMCOUNTER28_CSR_ADDR 12'hb1c
`define RV64_MHPMCOUNTER29_CSR_ADDR 12'hb1d
`define RV64_MHPMCOUNTER30_CSR_ADDR 12'hb1e
`define RV64_MHPMCOUNTER31_CSR_ADDR 12'hb2f

`define RV64_MHPMEVENT3_CSR_ADDR  12'b323
`define RV64_MHPMEVENT4_CSR_ADDR  12'b324
`define RV64_MHPMEVENT5_CSR_ADDR  12'b325
`define RV64_MHPMEVENT6_CSR_ADDR  12'b326
`define RV64_MHPMEVENT7_CSR_ADDR  12'b327
`define RV64_MHPMEVENT8_CSR_ADDR  12'b328
`define RV64_MHPMEVENT9_CSR_ADDR  12'b329
`define RV64_MHPMEVENT10_CSR_ADDR 12'b32a
`define RV64_MHPMEVENT11_CSR_ADDR 12'b32b
`define RV64_MHPMEVENT12_CSR_ADDR 12'b32c
`define RV64_MHPMEVENT13_CSR_ADDR 12'b32d
`define RV64_MHPMEVENT14_CSR_ADDR 12'b32e
`define RV64_MHPMEVENT15_CSR_ADDR 12'b32f
`define RV64_MHPMEVENT16_CSR_ADDR 12'b330
`define RV64_MHPMEVENT17_CSR_ADDR 12'b331
`define RV64_MHPMEVENT18_CSR_ADDR 12'b332
`define RV64_MHPMEVENT19_CSR_ADDR 12'b333
`define RV64_MHPMEVENT20_CSR_ADDR 12'b334
`define RV64_MHPMEVENT21_CSR_ADDR 12'b335
`define RV64_MHPMEVENT22_CSR_ADDR 12'b336
`define RV64_MHPMEVENT23_CSR_ADDR 12'b337
`define RV64_MHPMEVENT24_CSR_ADDR 12'b338
`define RV64_MHPMEVENT25_CSR_ADDR 12'b339
`define RV64_MHPMEVENT26_CSR_ADDR 12'b33a
`define RV64_MHPMEVENT27_CSR_ADDR 12'b33b
`define RV64_MHPMEVENT28_CSR_ADDR 12'b33c
`define RV64_MHPMEVENT29_CSR_ADDR 12'b33d
`define RV64_MHPMEVENT30_CSR_ADDR 12'b33e
`define RV64_MHPMEVENT31_CSR_ADDR 12'b33f

`endif


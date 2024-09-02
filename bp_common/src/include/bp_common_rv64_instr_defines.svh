/**
 *
 * bp_common_rv64_instr_defines.svh
 * Based off of: https://bitbucket.org/taylor-bsg/bsg_manycore/src/master/v/vanilla_bean/parameters.v
 */

`ifndef BP_COMMON_RV64_INSTR_DEFINES_SVH
`define BP_COMMON_RV64_INSTR_DEFINES_SVH

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
  `define rv64_b_type(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
  `define rv64_u_type(op)                 {{20{1'b?}},{5{1'b?}},``op``}
  `define rv64_fma_type(op, pr2)          {{5{1'b?}},``pr2``,{5{1'b?}},{5{1'b?}},{3{3'b?}},{5{1'b?}},``op``}

  // RV64 Immediate sign extension macros
  `define rv64_signext_i_imm(instr) {{53{``instr``[31]}},``instr``[30:20]}
  `define rv64_signext_s_imm(instr) {{53{``instr``[31]}},``instr[30:25],``instr``[11:7]}
  `define rv64_signext_b_imm(instr) {{52{``instr``[31]}},``instr``[7],``instr``[30:25],``instr``[11:8], {1'b0}}
  `define rv64_signext_u_imm(instr) {{32{``instr``[31]}},``instr``[31:12], {12{1'b0}}}
  `define rv64_signext_j_imm(instr) {{44{``instr``[31]}},``instr``[19:12],``instr``[20],``instr``[30:21], {1'b0}}
  `define rv64_signext_c_imm(instr) {{59{1'b0}},``instr``[19:15]}

  // Compressed quadrants
  `define RV64_C0_OP  2'b00
  `define RV64_C1_OP  2'b01
  `define RV64_C2_OP  2'b10
  `define RV64_32B_OP 2'b11

  `define rv64_signext_cj_imm(instr) {{53{``instr``[12]}},``instr``[8],``instr``[10:9],``instr``[6],``instr``[7],``instr``[2],``instr``[11],``instr``[5:3],1'b0}
  `define rv64_signext_cb_imm(instr) {{53{``instr``[12]}},``instr``[6:5],``instr``[2],``instr``[11:10],``instr``[4:3],1'b0}

  `define RV64_C0_INSTR   {14'b????_????_????_??,`RV64_C0_OP}
  `define RV64_C1_INSTR   {14'b????_????_????_??,`RV64_C1_OP}
  `define RV64_C2_INSTR   {14'b????_????_????_??,`RV64_C2_OP}
  `define RV64_32B_INSTR  {30'b????_????_????_??,`RV32_32B_OP}

  // I extension
  `define RV64_LUI        `rv64_u_type(`RV64_LUI_OP)
  `define RV64_AUIPC      `rv64_u_type(`RV64_AUIPC_OP)
  `define RV64_JAL        `rv64_u_type(`RV64_JAL_OP)
  `define RV64_JALR       `rv64_i_type(`RV64_JALR_OP,3'b000)
  `define RV64_BRANCH     `rv64_s_type(`RV64_BRANCH_OP,3'b???)
  `define RV64_BEQ        `rv64_s_type(`RV64_BRANCH_OP,3'b000)
  `define RV64_BNE        `rv64_s_type(`RV64_BRANCH_OP,3'b001)
  `define RV64_BLT        `rv64_s_type(`RV64_BRANCH_OP,3'b100)
  `define RV64_BGE        `rv64_s_type(`RV64_BRANCH_OP,3'b101)
  `define RV64_BLTU       `rv64_s_type(`RV64_BRANCH_OP,3'b110)
  `define RV64_BGEU       `rv64_s_type(`RV64_BRANCH_OP,3'b111)
  `define RV64_LB         `rv64_i_type(`RV64_LOAD_OP,3'b000)
  `define RV64_LH         `rv64_i_type(`RV64_LOAD_OP,3'b001)
  `define RV64_LW         `rv64_i_type(`RV64_LOAD_OP,3'b010)
  `define RV64_LOAD       `rv64_i_type(`RV64_LOAD_OP,3'b???)
  `define RV64_LD         `rv64_i_type(`RV64_LOAD_OP,3'b011)
  `define RV64_LBU        `rv64_i_type(`RV64_LOAD_OP,3'b100)
  `define RV64_LHU        `rv64_i_type(`RV64_LOAD_OP,3'b101)
  `define RV64_LWU        `rv64_i_type(`RV64_LOAD_OP,3'b110)
  `define RV64_STORE      `rv64_s_type(`RV64_STORE_OP,3'b???)
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
  `define RV64_FENCE_I    32'b????_????_????_????_?001_????_?000_1111
  `define RV64_FENCE      32'b????_????_????_????_?000_????_?000_1111

  // CMOs
  `define RV64_CBO_INVAL      32'b000000000000_?????_010_00000_0001111
  `define RV64_CBO_CLEAN      32'b000000000001_?????_010_00000_0001111
  `define RV64_CBO_FLUSH      32'b000000000010_?????_010_00000_0001111
  `define RV64_CBO_ZERO       32'b000000000100_?????_010_00000_0001111
  `define RV64_CMO_PREFETCHI  32'b???????_00000_?????_110_00000_0010011
  `define RV64_CMO_PREFETCHR  32'b???????_00001_?????_110_00000_0010011
  `define RV64_CMO_PREFETCHW  32'b???????_00011_?????_110_00000_0010011

  // CMO Custom -- Don't count on these staying the same!!
  `define RV64_CMO_INVAL_ALL  32'b000000000000_?????_111_00000_0001111
  `define RV64_CMO_CLEAN_ALL  32'b000000000001_?????_111_00000_0001111
  `define RV64_CMO_FLUSH_ALL  32'b000000000010_?????_111_00000_0001111

  // A extension
  `define RV64_LRW        32'b0001_0??0_0000_????_?010_????_?010_1111
  `define RV64_SCW        32'b0001_1???_????_????_?010_????_?010_1111
  `define RV64_AMOSWAPW   32'b0000_1???_????_????_?010_????_?010_1111
  `define RV64_AMOADDW    32'b0000_0???_????_????_?010_????_?010_1111
  `define RV64_AMOXORW    32'b0010_0???_????_????_?010_????_?010_1111
  `define RV64_AMOANDW    32'b0110_0???_????_????_?010_????_?010_1111
  `define RV64_AMOORW     32'b0100_0???_????_????_?010_????_?010_1111
  `define RV64_AMOMINW    32'b1000_0???_????_????_?010_????_?010_1111
  `define RV64_AMOMAXW    32'b1010_0???_????_????_?010_????_?010_1111
  `define RV64_AMOMINUW   32'b1100_0???_????_????_?010_????_?010_1111
  `define RV64_AMOMAXUW   32'b1110_0???_????_????_?010_????_?010_1111
  `define RV64_LRD        32'b0001_0??0_0000_????_?011_????_?010_1111
  `define RV64_SCD        32'b0001_1???_????_????_?011_????_?010_1111
  `define RV64_AMOSWAPD   32'b0000_1???_????_????_?011_????_?010_1111
  `define RV64_AMOADDD    32'b0000_0???_????_????_?011_????_?010_1111
  `define RV64_AMOXORD    32'b0010_0???_????_????_?011_????_?010_1111
  `define RV64_AMOANDD    32'b0110_0???_????_????_?011_????_?010_1111
  `define RV64_AMOORD     32'b0100_0???_????_????_?011_????_?010_1111
  `define RV64_AMOMIND    32'b1000_0???_????_????_?011_????_?010_1111
  `define RV64_AMOMAXD    32'b1010_0???_????_????_?011_????_?010_1111
  `define RV64_AMOMINUD   32'b1100_0???_????_????_?011_????_?010_1111
  `define RV64_AMOMAXUD   32'b1110_0???_????_????_?011_????_?010_1111

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
  `define RV64_FMUL_S     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0001000)
  `define RV64_FDIV_S     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0001100)
  `define RV64_FSQRT_S    32'b0101100_00000_?????_???_?????_1010011
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
  `define RV64_FDIV_D     `rv64_r_type(`RV64_FP_OP,3'b???,7'b0001101)
  `define RV64_FSQRT_D    32'b0101101_00000_?????_???_?????_1010011
  `define RV64_FSGNJ_D    `rv64_r_type(`RV64_FP_OP,3'b000,7'b0010001)
  `define RV64_FSGNJN_D   `rv64_r_type(`RV64_FP_OP,3'b001,7'b0010001)
  `define RV64_FSGNJX_D   `rv64_r_type(`RV64_FP_OP,3'b010,7'b0010001)
  `define RV64_FMIN_D     `rv64_r_type(`RV64_FP_OP,3'b000,7'b0010101)
  `define RV64_FMAX_D     `rv64_r_type(`RV64_FP_OP,3'b001,7'b0010101)
  `define RV64_FCVT_SD    32'b0100000_00001_?????_???_?????_1010011
  `define RV64_FCVT_DS    32'b0100001_00000_?????_???_?????_1010011
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
  `define RV64_FMV_DX     32'b1111001_00000_?????_000_?????_1010011

  // C extension
  // Instruction expansions
  `define rv64_r_type_exp(op, rd, funct3, rs1, rs2, funct7) {``funct7``,``rs2``,``rs1``,``funct3``,``rd``,``op``}
  `define rv64_i_type_exp(op, rd, funct3, rs1, imm) {``imm``[11:0],``rs1``,``funct3``,``rd``,``op``}
  `define rv64_s_type_exp(op, funct3, rs1, rs2, imm) {``imm``[11:5],``rs2``,``rs1``,``funct3``,``imm``[4:0],``op``}
  `define rv64_u_type_exp(op, rd, imm) {``imm``[31:12],``rd``,``op``}
  `define rv64_b_type_exp(op, funct3, rs1, rs2, imm) {``imm``[12],``imm``[10:5],``rs2``,``rs1``,``funct3``,``imm``[4:1],``imm``[11],``op``}
  `define rv64_j_type_exp(op, rd, imm) {``imm``[20],``imm``[10:1],``imm``[11],``imm``[19:12],``rd``,``op``}

  // Instruction types
  `define rv64_cr_type(op, funct4) {``funct4``,{5{1'b?}},{5{1'b?}},``op``}
  `define rv64_ci_type(op, funct3) {``funct3``,{1{1'b?}},{5{1'b?}},{5{1'b?}},``op``}
  `define rv64_css_type(op, funct3) {``funct3``,{6{1'b?}},{5{1'b?}},``op``}
  `define rv64_ciw_type(op, funct3) {``funct3``,{8{1'b?}},{3{1'b?}},``op``}
  `define rv64_cl_type(op, funct3) {``funct3``,{3{1'b?}},{3{1'b?}},{2{1'b?}},{3{1'b?}},``op``}
  `define rv64_cs_type(op, funct3) {``funct3``,{3{1'b?}},{3{1'b?}},{2{1'b?}},{3{1'b?}},``op``}
  `define rv64_ca_type(op, funct6, funct2) {``funct6``,{3{1'b?}},``funct2``,{3{1'b?}},``op``}
  `define rv64_cb_type(op, funct3) {``funct3``,{3{1'b?}},{3{1'b?}},{5{1'b?}},``op``}
  `define rv64_cb2_type(op, funct3, funct2) {``funct3``,{1{1'b?}},``funct2``,{3{1'b?}},{5{1'b?}},``op``}
  `define rv64_cj_type(op, funct3) {``funct3``,{11{1'b?}},``op``}

  `define RV64_CLWSP      `rv64_ci_type(`RV64_C2_OP,3'b010)
  `define RV64_CLDSP      `rv64_ci_type(`RV64_C2_OP,3'b011)
  `define RV64_CSWSP      `rv64_css_type(`RV64_C2_OP,3'b110)
  `define RV64_CSDSP      `rv64_css_type(`RV64_C2_OP,3'b111)
  `define RV64_CLW        `rv64_cl_type(`RV64_C0_OP,3'b010)
  `define RV64_CLD        `rv64_cl_type(`RV64_C0_OP,3'b011)
  `define RV64_CSW        `rv64_cs_type(`RV64_C0_OP,3'b110)
  `define RV64_CSD        `rv64_cs_type(`RV64_C0_OP,3'b111)
  `define RV64_CJ         `rv64_cj_type(`RV64_C1_OP,3'b101)
  `define RV64_CJR        16'b1000_????_?000_0010
  `define RV64_CJALR      16'b1001_????_?000_0010
  `define RV64_CBEQZ      `rv64_cb_type(`RV64_C1_OP,3'b110)
  `define RV64_CBNEZ      `rv64_cb_type(`RV64_C1_OP,3'b111)
  `define RV64_CLI        `rv64_ci_type(`RV64_C1_OP,3'b010)
  `define RV64_CLUI       `rv64_ci_type(`RV64_C1_OP,3'b011)

  `define RV64_CADDI      `rv64_ci_type(`RV64_C1_OP,3'b000)
  `define RV64_CADDIW     `rv64_ci_type(`RV64_C1_OP,3'b001)
  `define RV64_CADDI16SP  16'b011?_0001_0???_??01

  `define RV64_CADDI4SPN  `rv64_ciw_type(`RV64_C0_OP,3'b000)
  `define RV64_CSLLI      `rv64_ci_type(`RV64_C2_OP,3'b000)
  `define RV64_CSRLI      `rv64_cb2_type(`RV64_C1_OP,3'b100,2'b00)
  `define RV64_CSRAI      `rv64_cb2_type(`RV64_C1_OP,3'b100,2'b01)
  `define RV64_CANDI      `rv64_cb2_type(`RV64_C1_OP,3'b100,2'b10)
  `define RV64_CMV        `rv64_cr_type(`RV64_C2_OP,4'b1000)
  `define RV64_CADD       `rv64_cr_type(`RV64_C2_OP,4'b1001)
  `define RV64_CAND       `rv64_ca_type(`RV64_C1_OP,6'b100011,2'b11)
  `define RV64_COR        `rv64_ca_type(`RV64_C1_OP,6'b100011,2'b10)
  `define RV64_CXOR       `rv64_ca_type(`RV64_C1_OP,6'b100011,2'b01)
  `define RV64_CSUB       `rv64_ca_type(`RV64_C1_OP,6'b100011,2'b00)
  `define RV64_CADDW      `rv64_ca_type(`RV64_C1_OP,6'b100111,2'b01)
  `define RV64_CSUBW      `rv64_ca_type(`RV64_C1_OP,6'b100111,2'b00)
  `define RV64_CILL       16'b0000_0000_0000_0000
  `define RV64_CNOP       16'b0000_0000_0000_0001
  `define RV64_CEBREAK    16'b1001_0000_0000_0010

  `define RV64_CFLD       `rv64_cs_type(`RV64_C0_OP,3'b001)
  `define RV64_CFSD       `rv64_cs_type(`RV64_C0_OP,3'b101)
  `define RV64_CFLWSP     `rv64_css_type(`RV64_C2_OP,3'b011)
  `define RV64_CFLDSP     `rv64_css_type(`RV64_C2_OP,3'b001)
  `define RV64_CFSWSP     `rv64_cl_type(`RV64_C2_OP,3'b111)
  `define RV64_CFSDSP     `rv64_cl_type(`RV64_C2_OP,3'b101)

  // Bitmanip
  // expansions
  `define rv64_fi_type(op, funct3, funct12) {``funct12``,{5{1'b?}},``funct3``,{5{1'b?}},``op``}

  // Zba
  `define RV64_ADDUW      `rv64_r_type(`RV64_OP_32_OP,3'b000,7'b0000100)
  `define RV64_SH1ADD     `rv64_r_type(`RV64_OP_OP,3'b010,7'b0010000)
  `define RV64_SH1ADDUW   `rv64_r_type(`RV64_OP_32_OP,3'b010,7'b0010000)
  `define RV64_SH2ADD     `rv64_r_type(`RV64_OP_OP,3'b100,7'b0010000)
  `define RV64_SH2ADDUW   `rv64_r_type(`RV64_OP_32_OP,3'b100,7'b0010000)
  `define RV64_SH3ADD     `rv64_r_type(`RV64_OP_OP,3'b110,7'b0010000)
  `define RV64_SH3ADDUW   `rv64_r_type(`RV64_OP_32_OP,3'b110,7'b0010000)
  `define RV64_SLLIUW     `rv64_fi_type(`RV64_OP_IMM_32_OP,3'b001,12'b000010??????)

  // Zbb
  `define RV64_ANDN       `rv64_r_type(`RV64_OP_OP,3'b111,7'b0100000)
  `define RV64_CLZ        `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b0110000_00000)
  `define RV64_CLZW       `rv64_fi_type(`RV64_OP_IMM_32_OP,3'b001,12'b0110000_00000)
  `define RV64_CPOP       `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b0110000_00010)
  `define RV64_CPOPW      `rv64_fi_type(`RV64_OP_IMM_32_OP,3'b001,12'b0110000_00010)
  `define RV64_CTZ        `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b0110000_00001)
  `define RV64_CTZW       `rv64_fi_type(`RV64_OP_IMM_32_OP,3'b001,12'b0110000_00001)
  `define RV64_MAX        `rv64_r_type(`RV64_OP_OP,3'b110,7'b0000101)
  `define RV64_MAXU       `rv64_r_type(`RV64_OP_OP,3'b111,7'b0000101)
  `define RV64_MIN        `rv64_r_type(`RV64_OP_OP,3'b100,7'b0000101)
  `define RV64_MINU       `rv64_r_type(`RV64_OP_OP,3'b101,7'b0000101)
  `define RV64_ORCB       `rv64_fi_type(`RV64_OP_IMM_OP,3'b101,12'b0010100_00111)
  `define RV64_ORN        `rv64_r_type(`RV64_OP_OP,3'b110,7'b0100000)
  `define RV64_REV8       `rv64_fi_type(`RV64_OP_IMM_OP,3'b101,12'b011010111000)
  `define RV64_ROL        `rv64_r_type(`RV64_OP_OP,3'b001,7'b0110000)
  `define RV64_ROLW       `rv64_r_type(`RV64_OP_32_OP,3'b001,7'b0110000)
  `define RV64_ROR        `rv64_r_type(`RV64_OP_OP,3'b101,7'b0110000)
  `define RV64_RORI       `rv64_fi_type(`RV64_OP_IMM_OP,3'b101,12'b011000_??????)
  `define RV64_RORIW      `rv64_fi_type(`RV64_OP_IMM_32_OP,3'b101,12'b0110000_?????)
  `define RV64_RORW       `rv64_r_type(`RV64_OP_32_OP,3'b101,7'b0110000)
  `define RV64_SEXTB      `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b0110000_00100)
  `define RV64_SEXTH      `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b0110000_00101)
  `define RV64_XNOR       `rv64_r_type(`RV64_OP_OP,3'b100,7'b0100000)
  `define RV64_ZEXTH      `rv64_r_type(`RV64_OP_32_OP,3'b100,7'b0000100)

  // Zbc
  `define RV64_CLMUL      `rv64_r_type(`RV64_OP_OP,3'b001,7'b0000101)
  `define RV64_CLMULH     `rv64_r_type(`RV64_OP_OP,3'b011,7'b0000101)
  `define RV64_CLMULR     `rv64_r_type(`RV64_OP_OP,3'b010,7'b0000101)

  // Zbs
  `define RV64_BCLR       `rv64_r_type(`RV64_OP_OP,3'b001,7'b0100100)
  `define RV64_BCLRI      `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b010010_??????)
  `define RV64_BEXT       `rv64_r_type(`RV64_OP_OP,3'b101,7'b0100100)
  `define RV64_BEXTI      `rv64_fi_type(`RV64_OP_IMM_OP,3'b101,12'b010010_??????)
  `define RV64_BINV       `rv64_r_type(`RV64_OP_OP,3'b001,7'b0110100)
  `define RV64_BINVI      `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b011010_??????)
  `define RV64_BSET       `rv64_r_type(`RV64_OP_OP,3'b001,7'b0010100)
  `define RV64_BSETI      `rv64_fi_type(`RV64_OP_IMM_OP,3'b001,12'b001010_??????)

  // Fusion candidates
  //`define RV64_ADD        `rv64_r_type(`RV64_OP_OP,3'b000,7'b0000000)
  `define RV64_LI         {{12'b????????????},{5'b00000},{3'b000},{5'b?????},{7'b0010011}}
  `define RV64_MV         {{12'b000000000000},{5'b?????},{3'b000},{5'b?????},{7'b0010011}}
  `define RV64_RET        {{12'b000000000000},{5'b?????},{3'b000},{5'b00000},{7'b1100111}}
  //`define RV64_BRANCH     `rv64_s_type(`RV64_BRANCH_OP,3'b???)
  //`define RV64_LUI        `rv64_u_type(`RV64_LUI_OP)
  //`define RV64_AUIPC      `rv64_u_type(`RV64_AUIPC_OP)

`endif


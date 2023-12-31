
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_expander
 import bp_common_pkg::*;
 import bp_be_pkg::*;
  (input [cinstr_width_gp-1:0]         cinstr_i

   , output logic [instr_width_gp-1:0] instr_o
   );

  logic [rv64_reg_addr_width_gp-1:0] rs1, rs2, rd;
  logic [dword_width_gp-1:0] imm;
  wire [11:0] zero_imm = '0;

  localparam rv64_zero_addr_gp = 5'd0;
  localparam rv64_link_addr_gp = 5'd1;
  localparam rv64_sp_addr_gp = 5'd2;

  rv64_cinstr_s cinstr;
  assign cinstr = cinstr_i;

  always_comb
    begin
      instr_o = cinstr_i;

      // Different per quadrant
      casez (cinstr_i)
        `RV64_C2_INSTR, `RV64_CADDI, `RV64_CADDIW, `RV64_CLI, `RV64_CADDI16SP, `RV64_CLUI:
          begin
            rs1 = cinstr_i[11:7];
            rs2 = cinstr_i[6:2];
            rd  = cinstr_i[11:7];
          end
        `RV64_C1_INSTR:
          begin
            rs1 = {2'b01, cinstr_i[9:7]};
            rs2 = {2'b01, cinstr_i[4:2]};
            rd  = {2'b01, cinstr_i[9:7]};
          end
        // `RV64_C0_INSTR:
        default:
          begin
            rs1 = {2'b01, cinstr_i[9:7]};
            rs2 = {2'b01, cinstr_i[4:2]};
            rd  = {2'b01, cinstr_i[4:2]};
          end
      endcase

      casez (cinstr_i)
        `RV64_CADDI16SP:
          imm = dword_width_gp'($signed({cinstr_i[12], cinstr_i[4:3], cinstr_i[5], cinstr_i[2], cinstr_i[6], 4'b0000}));
        `RV64_CADDI4SPN:
          imm = dword_width_gp'($unsigned({cinstr_i[10:7], cinstr_i[12:11], cinstr_i[5], cinstr_i[6], 2'b00}));
        `RV64_CLWSP:
          imm = dword_width_gp'($unsigned({cinstr_i[3:2], cinstr_i[12], cinstr_i[6:4], 2'b00}));
        `RV64_CFLDSP, `RV64_CLDSP:
          imm = dword_width_gp'($unsigned({cinstr_i[4:2], cinstr_i[12], cinstr_i[6:5], 3'b000}));
        `RV64_CSWSP:
          imm = dword_width_gp'($unsigned({cinstr_i[8:7], cinstr_i[12:9], 2'b00}));
        `RV64_CFSDSP, `RV64_CSDSP:
          imm = dword_width_gp'($unsigned({cinstr_i[9:7], cinstr_i[12:10], 3'b000}));
        `RV64_CLW, `RV64_CSW:
          imm = dword_width_gp'($unsigned({cinstr_i[5], cinstr_i[12:10], cinstr_i[6], 2'b00}));
        `RV64_CFLD, `RV64_CLD, `RV64_CFSD, `RV64_CSD:
          imm = dword_width_gp'($unsigned({cinstr_i[6:5], cinstr_i[12:10], 3'b000}));
        `RV64_CJ:
          imm = dword_width_gp'($signed({cinstr_i[12], cinstr_i[8], cinstr_i[10:9], cinstr_i[6] ,cinstr_i[7], cinstr_i[2], cinstr_i[11], cinstr_i[5:3], 1'b0}));
        `RV64_CBEQZ, `RV64_CBNEZ:
          imm = dword_width_gp'($signed({cinstr_i[12], cinstr_i[6:5], cinstr_i[2], cinstr_i[11:10], cinstr_i[4:3], 1'b0}));
        `RV64_CLUI:
          imm = dword_width_gp'($signed({cinstr_i[12], cinstr_i[6:2], 12'b0}));
        `RV64_CNOP, `RV64_CADDI, `RV64_CADDIW, `RV64_CLI, `RV64_CANDI:
          imm = dword_width_gp'($signed({cinstr_i[12], cinstr_i[6:2]}));
        `RV64_CSLLI, `RV64_CSRLI:
          imm = dword_width_gp'($unsigned({6'b000000, cinstr_i[12], cinstr_i[6:2]}));
        `RV64_CSRAI:
          imm = dword_width_gp'($unsigned({6'b010000, cinstr_i[12], cinstr_i[6:2]}));
        default: imm = '0;
      endcase

      casez (cinstr_i)
        // C.ILL -> 0000_0000_0000_0000
        `RV64_CILL: instr_o = '0;
        // C.ADDI4SPN -> addi rd', x2, nzuimm[9:2]
        `RV64_CADDI4SPN: instr_o =
            `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b000, rv64_sp_addr_gp, imm);
        // C.ADDI16SP -> addi x2, x2, nzimm[9:4]
        `RV64_CADDI16SP: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rv64_sp_addr_gp, 3'b000, rv64_sp_addr_gp, imm);
        // C.EBREAK   -> ebreak
        `RV64_CEBREAK: instr_o = `RV64_EBREAK;
        // C.LWSP     -> lw rd, offset[7:2] (x2)
        `RV64_CLWSP: instr_o =
          `rv64_i_type_exp(`RV64_LOAD_OP, rd, 3'b010, rv64_sp_addr_gp, imm);
        // C.LDSP     -> ld rd, offset[8:3] (x2)
        `RV64_CLDSP: instr_o =
          `rv64_i_type_exp(`RV64_LOAD_OP, rd, 3'b011, rv64_sp_addr_gp, imm);
        // C.SWSP     -> sw rs2, offset[7:2] (x2)
        `RV64_CSWSP: instr_o =
          `rv64_s_type_exp(`RV64_STORE_OP, 3'b010, rv64_sp_addr_gp, rs2, imm);
        // C.SDSP     -> sd rs2, offset[8:3] (x2)
        `RV64_CSDSP: instr_o =
          `rv64_s_type_exp(`RV64_STORE_OP, 3'b011, rv64_sp_addr_gp, rs2, imm);
        // C.FLDSP -> fld rd, offset(x2)
        `RV64_CFLDSP: instr_o =
          `rv64_i_type_exp(`RV64_FLOAD_OP, rd, 3'b011, rv64_sp_addr_gp, imm);
        // C.FSDSP -> fsd rs2, offset(x2)
        `RV64_CFSDSP: instr_o =
          `rv64_s_type_exp(`RV64_FSTORE_OP, 3'b011, rv64_sp_addr_gp, rs2, imm);
        // C.LW       -> lw rd', offset[6:2] (rs1')
        `RV64_CLW: instr_o =
          `rv64_i_type_exp(`RV64_LOAD_OP, rd, 3'b010, rs1, imm);
        // C.LD       -> ld rd', offset[7:3] (rs1')
        `RV64_CLD: instr_o =
          `rv64_i_type_exp(`RV64_LOAD_OP, rd, 3'b011, rs1, imm);
        // C.SW       -> sw rs2', offset[6:2] (rs1')
        `RV64_CSW: instr_o =
          `rv64_s_type_exp(`RV64_STORE_OP, 3'b010, rs1, rs2, imm);
        // C.SD       -> sd rs2', offset[7:3] (rs1')
        `RV64_CSD: instr_o =
          `rv64_s_type_exp(`RV64_STORE_OP, 3'b011, rs1, rs2, imm);
        // C.FLD -> fld rd', offset(rs1')
        `RV64_CFLD: instr_o =
          `rv64_i_type_exp(`RV64_FLOAD_OP, rd, 3'b011, rs1, imm);
        // C.FSD -> fsd rs2', offset(rs1')
        `RV64_CFSD: instr_o =
          `rv64_s_type_exp(`RV64_FSTORE_OP, 3'b011, rs1, rs2, imm);
        // C.J        -> jal x0, offset[11:1]
        `RV64_CJ: instr_o =
          `rv64_j_type_exp(`RV64_JAL_OP, rv64_zero_addr_gp, imm);
        // C.JR       -> jalr x0, 0(rs1)
        `RV64_CJR: instr_o =
          `rv64_i_type_exp(`RV64_JALR_OP, rv64_zero_addr_gp, 3'b000, rs1, zero_imm);
        // C.JALR     -> jalr x1, 0(rs1)
        `RV64_CJALR: instr_o =
          `rv64_i_type_exp(`RV64_JALR_OP, rv64_link_addr_gp, 3'b000, rs1, zero_imm);
        // C.BEQZ     -> beq rs1', x0, offset[8:1]
        `RV64_CBEQZ: instr_o =
          `rv64_b_type_exp(`RV64_BRANCH_OP, 3'b000, rs1, rv64_zero_addr_gp, imm);
        // C.BNEZ     -> bne rs1', x0, offset[8:1]
        `RV64_CBNEZ: instr_o =
          `rv64_b_type_exp(`RV64_BRANCH_OP, 3'b001, rs1, rv64_zero_addr_gp, imm);
        // C.LI       -> addi rd, x0, imm[5:0]
        `RV64_CLI: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b000, rv64_zero_addr_gp, imm);
        // C.LUI      -> lui rd, nzimm[17:12]
        `RV64_CLUI: instr_o =
          `rv64_u_type_exp(`RV64_LUI_OP, rd, imm);
        // C.NOP      -> addi x0, x0, 0
        `RV64_CNOP: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rv64_zero_addr_gp, 3'b000, rv64_zero_addr_gp, zero_imm);
        // C.ADDI     -> addi rd, rd, nzimm[5:0]
        `RV64_CADDI: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b000, rd, imm);
        // C.ADDIW    -> addiw rd, rd, imm[5:0]
        `RV64_CADDIW: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_32_OP, rd, 3'b000, rd, imm);
        // C.SLLI     -> slli rd, rd, shamt[5:0]
        `RV64_CSLLI: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b001, rd, imm);
        // C.SRLI     -> srli rd', rd', shamt[5:0]
        `RV64_CSRLI: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b101, rd, imm);
        // C.SRAI     -> srai rd', rd', shamt[5:0]
        `RV64_CSRAI: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b101, rd, imm);
        // C.ANDI     -> andi rd', rd', imm[5:0]
        `RV64_CANDI: instr_o =
          `rv64_i_type_exp(`RV64_OP_IMM_OP, rd, 3'b111, rd, imm);
        // C.MV       -> add rd, x0, rs2
        `RV64_CMV: instr_o =
          `rv64_r_type_exp(`RV64_OP_OP, rd, 3'b000, rv64_zero_addr_gp, rs2, 7'b0);
        // C.ADD      -> add rd, rd, rs2
        `RV64_CADD: instr_o =
          `rv64_r_type_exp(`RV64_OP_OP, rd, 3'b000, rd, rs2, 7'b0);
        // C.AND      -> and rd', rd', rs2'
        `RV64_CAND: instr_o =
          `rv64_r_type_exp(`RV64_OP_OP, rd, 3'b111, rd, rs2, 7'b0);
        // C.OR       -> or rd', rd', rs2'
        `RV64_COR: instr_o =
          `rv64_r_type_exp(`RV64_OP_OP, rd, 3'b110, rd, rs2, 7'b0);
        // C.XOR      -> xor rd', rd', rs2'
        `RV64_CXOR: instr_o =
          `rv64_r_type_exp(`RV64_OP_OP, rd, 3'b100, rd, rs2, 7'b0);
        // C.SUB      -> sub rd', rd', rs2'
        `RV64_CSUB: instr_o =
          `rv64_r_type_exp(`RV64_OP_OP, rd, 3'b000, rd, rs2, 7'b010_0000);
        // C.ADDW     -> addw rd', rd', rs2'
        `RV64_CADDW: instr_o =
          `rv64_r_type_exp(`RV64_OP_32_OP, rd, 3'b000, rd, rs2, 7'b0);
        // C.SUBW     -> subw rd', rd', rs2'
        `RV64_CSUBW: instr_o =
          `rv64_r_type_exp(`RV64_OP_32_OP, rd, 3'b000, rd, rs2, 7'b010_0000);
        default: begin end
      endcase

      // Check for reserved encodings
      casez (cinstr_i)
        `RV64_CLWSP, `RV64_CLDSP: instr_o = ~|cinstr_i[11:7] ? '0 : instr_o;
        `RV64_CLUI, `RV64_CADDI16SP, `RV64_CADDI4SPN
                                : instr_o = ~|imm ? '0 : instr_o;
        default: begin end
      endcase
    end

endmodule


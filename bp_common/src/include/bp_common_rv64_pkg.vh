
package bp_common_rv64_pkg;

  `include "bp_common_rv64_defines.vh"
  `include "bp_common_csr_defines.vh"

  localparam rv64_rf_els_gp         = 32;
  localparam rv64_instr_width_gp    = 32;
  localparam rv64_eaddr_width_gp    = 64;
  localparam rv64_byte_width_gp     = 8;
  localparam rv64_hword_width_gp    = 16;
  localparam rv64_word_width_gp     = 32;
  localparam rv64_dword_width_gp    = 64;
  localparam rv64_reg_data_width_gp = 64;
  localparam rv64_reg_addr_width_gp = 5;
  localparam rv64_shamt_width_gp    = 6;
  localparam rv64_shamtw_width_gp   = 5;
  localparam rv64_opcode_width_gp   = 7;
  localparam rv64_funct3_width_gp   = 3;
  localparam rv64_funct7_width_gp   = 7;
  localparam rv64_csr_addr_width_gp = 12;
  localparam rv64_imm20_width_gp    = 20;
  localparam rv64_imm12_width_gp    = 12;
  localparam rv64_imm11to5_width_gp = 7;
  localparam rv64_imm4to0_width_gp  = 5;
  localparam rv64_priv_width_gp     = 2;

  typedef struct packed
  {
    logic [rv64_funct7_width_gp-1:0]   funct7;
    logic [rv64_reg_addr_width_gp-1:0] rs2_addr;
    logic [rv64_reg_addr_width_gp-1:0] rs1_addr;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
  }  rv64_instr_rtype_s;

  typedef struct packed
  {
    logic [rv64_imm12_width_gp-1:0]    imm12;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
  }  rv64_instr_itype_s;

  typedef struct packed
  {
    logic [rv64_imm11to5_width_gp-1:0] imm11to5;
    logic [rv64_reg_addr_width_gp-1:0] rs2;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [rv64_imm4to0_width_gp-1:0]  imm4to0;
  }  rv64_instr_stype_s;

  typedef struct packed 
  {
    logic [rv64_imm20_width_gp-1:0]    imm20;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
  }  rv64_instr_utype_s;

  typedef struct packed
  {
    union packed
    {
      rv64_instr_rtype_s rtype;
      rv64_instr_itype_s itype;
      rv64_instr_stype_s stype;
      rv64_instr_utype_s utype;
    }  fields;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_s;

endpackage


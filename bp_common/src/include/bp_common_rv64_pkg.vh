
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
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_rtype_s;

  typedef struct packed
  {
    logic [rv64_reg_addr_width_gp-1:0] rs3_addr;
    logic [1:0]                        fmt;
    logic [rv64_reg_addr_width_gp-1:0] rs2_addr;
    logic [rv64_reg_addr_width_gp-1:0] rs1_addr;
    logic [2:0]                        rm;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_fmatype_s;

  typedef struct packed
  {
    logic [rv64_funct7_width_gp-1:0]   funct7;
    logic [rv64_reg_addr_width_gp-1:0] rs2_addr;
    logic [rv64_reg_addr_width_gp-1:0] rs1_addr;
    logic [2:0]                        rm;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_ftype_s;

  typedef struct packed
  {
    logic [rv64_imm12_width_gp-1:0]    imm12;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_itype_s;

  typedef struct packed
  {
    logic [rv64_imm11to5_width_gp-1:0] imm11to5;
    logic [rv64_reg_addr_width_gp-1:0] rs2;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [rv64_imm4to0_width_gp-1:0]  imm4to0;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_stype_s;

  typedef struct packed 
  {
    logic [rv64_imm20_width_gp-1:0]    imm20;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_utype_s;

  typedef struct packed
  {
    union packed
    {
      rv64_instr_rtype_s    rtype;
      rv64_instr_fmatype_s  fmatype;
      rv64_instr_ftype_s    ftype;
      rv64_instr_itype_s    itype;
      rv64_instr_stype_s    stype;
      rv64_instr_utype_s    utype;
    }  t;
  }  rv64_instr_s;

  typedef struct packed
  {
    // RISC-V exceptions
    logic store_page_fault;
    logic reserved2;
    logic load_page_fault;
    logic instr_page_fault;
    logic ecall_m_mode;
    logic reserved1;
    logic ecall_s_mode;
    logic ecall_u_mode;
    logic store_access_fault;
    logic store_misaligned;
    logic load_access_fault;
    logic load_misaligned;
    logic breakpoint;
    logic illegal_instr;
    logic instr_access_fault;
    logic instr_misaligned;
  }  rv64_exception_dec_s;

  typedef enum logic [2:0]
  {
    e_rne   = 3'b000
    ,e_rtz  = 3'b001
    ,e_rdn  = 3'b010
    ,e_rup  = 3'b011
    ,e_rmm  = 3'b100
    // 3'b101, 3'b110 reserved
    ,e_dyn  = 3'b111
  } rv64_frm_e;

  typedef enum logic
  {
    e_fmt_single  = 1'b0
    ,e_fmt_double = 1'b1
  } rv64_fmt_e;

  typedef struct packed
  {
    // Invalid operation
    logic nv;
    // Divide by zero
    logic dz;
    // Overflow
    logic of;
    // Underflow
    logic uf;
    // Inexact
    logic nx;
  }  rv64_fflags_s;

  typedef struct packed
  {
    // Invalid operation
    logic nv;
    // Overflow
    logic of;
    // Inexact
    logic nx;
  }  rv64_iflags_s;

  typedef struct packed
  {
    logic [53:0] padding;
    logic        q_nan;
    logic        s_nan;
    logic        p_inf;
    logic        p_norm;
    logic        p_sub;
    logic        p_zero;
    logic        n_zero;
    logic        n_sub;
    logic        n_norm;
    logic        n_inf;
  }  rv64_fclass_s;

endpackage


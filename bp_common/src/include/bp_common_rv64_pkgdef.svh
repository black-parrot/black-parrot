`ifndef BP_COMMON_RV64_PKGDEF_SVH
`define BP_COMMON_RV64_PKGDEF_SVH

  // TODO: Bring into aviary
  localparam fetch_width_gp          = 32;
  localparam fetch_cinstr_gp         = fetch_width_gp>>4;
  localparam fetch_bytes_gp          = fetch_width_gp>>3;

  localparam dword_width_gp          = 64;
  localparam word_width_gp           = 32;
  localparam half_width_gp           = 16;
  localparam byte_width_gp           = 8;
  localparam cinstr_width_gp         = 16;
  localparam instr_width_gp          = 32;
  localparam csr_addr_width_gp       = 12;
  localparam reg_addr_width_gp       = 5;
  localparam page_offset_width_gp    = 12;

  localparam rv64_rf_els_gp          = 32;
  localparam rv64_instr_width_gp     = 32;
  localparam rv64_eaddr_width_gp     = 64;
  localparam rv64_byte_width_gp      = 8;
  localparam rv64_hword_width_gp     = 16;
  localparam rv64_word_width_gp      = 32;
  localparam rv64_dword_width_gp     = 64;
  localparam rv64_reg_data_width_gp  = 64;
  localparam rv64_reg_addr_width_gp  = 5;
  localparam rv64_creg_addr_width_gp = 3;
  localparam rv64_shamt_width_gp     = 6;
  localparam rv64_shamtw_width_gp    = 5;
  localparam rv64_opcode_width_gp    = 7;
  localparam rv64_copcode_width_gp   = 2;
  localparam rv64_funct2_width_gp    = 2;
  localparam rv64_funct3_width_gp    = 3;
  localparam rv64_funct4_width_gp    = 4;
  localparam rv64_funct6_width_gp    = 6;
  localparam rv64_funct7_width_gp    = 7;
  localparam rv64_csr_addr_width_gp  = 12;
  localparam rv64_priv_width_gp      = 2;

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
    logic [11:0]                       imm12;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_itype_s;

  typedef struct packed
  {
    logic [11:5]                       imm11to5;
    logic [rv64_reg_addr_width_gp-1:0] rs2;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [4:0]                        imm4to0;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_stype_s;

  typedef struct packed
  {
    logic [19:0]                       imm20;
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_utype_s;

  typedef struct packed
  {
    logic                              imm12;
    logic [10:5]                       imm10to5;
    logic [rv64_reg_addr_width_gp-1:0] rs2;
    logic [rv64_reg_addr_width_gp-1:0] rs1;
    logic [rv64_funct3_width_gp-1:0]   funct3;
    logic [4:1]                        imm4to1;
    logic                              imm11;
    logic [rv64_opcode_width_gp-1:0]   opcode;
  }  rv64_instr_btype_s;

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
      rv64_instr_btype_s    btype;
    }  t;
  }  rv64_instr_s;

  typedef struct packed
  {
    logic [rv64_funct4_width_gp-1:0]    funct4;
    logic [rv64_reg_addr_width_gp-1:0]  rdrs1_addr;
    logic [rv64_reg_addr_width_gp-1:0]  rs2_addr;
    logic [rv64_copcode_width_gp-1:0]   opcode;
  }  rv64_instr_crtype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]    funct3;
    logic [5:5]                         imm5;
    logic [rv64_reg_addr_width_gp-1:0]  rdrs1_addr;
    logic [4:0]                         imm4to0;
    logic [rv64_copcode_width_gp-1:0]   opcode;
  }  rv64_instr_citype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]    funct3;
    logic [5:0]                         imm6;
    logic [rv64_reg_addr_width_gp-1:0]  rs2_addr;
    logic [rv64_copcode_width_gp-1:0]   opcode;
  }  rv64_instr_csstype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]     funct3;
    logic [7:0]                          imm8;
    logic [rv64_creg_addr_width_gp-1:0]  rdp_addr;
    logic [rv64_copcode_width_gp-1:0]    opcode;
  }  rv64_instr_ciwtype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]     funct3;
    logic [4:2]                          imm4to2;
    logic [rv64_creg_addr_width_gp-1:0]  rs1p_addr;
    logic [1:0]                          imm1to0;
    logic [rv64_creg_addr_width_gp-1:0]  rdp_addr;
    logic [rv64_copcode_width_gp-1:0]    opcode;
  }  rv64_instr_cltype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]     funct3;
    logic [4:2]                          imm4to2;
    logic [rv64_creg_addr_width_gp-1:0]  rs1p_addr;
    logic [1:0]                          imm1to0;
    logic [rv64_creg_addr_width_gp-1:0]  rs2p_addr;
    logic [rv64_copcode_width_gp-1:0]    opcode;
  }  rv64_instr_cstype_s;

  typedef struct packed
  {
    logic [rv64_funct6_width_gp-1:0]     funct6;
    logic [rv64_creg_addr_width_gp-1:0]  rdrs1p_addr;
    logic [rv64_funct2_width_gp-1:0]     funct2;
    logic [rv64_creg_addr_width_gp-1:0]  rs2p_addr;
    logic [rv64_copcode_width_gp-1:0]    opcode;
  }  rv64_instr_catype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]     funct3;
    logic [7:5]                          offset7to5;
    logic [rv64_creg_addr_width_gp-1:0]  rdrs1p_addr;
    logic [4:0]                          offset4to0;
    logic [rv64_copcode_width_gp-1:0]    opcode;
  }  rv64_instr_cbtype_s;

  typedef struct packed
  {
    logic [rv64_funct3_width_gp-1:0]  funct3;
    logic [10:0]                      target;
    logic [rv64_copcode_width_gp-1:0] opcode;
  }  rv64_instr_cjtype_s;

  typedef struct packed
  {
    union packed
    {
      rv64_instr_crtype_s  crtype;
      rv64_instr_citype_s  citype;
      rv64_instr_csstype_s csstype;
      rv64_instr_ciwtype_s ciwtype;
      rv64_instr_cltype_s  cltype;
      rv64_instr_cstype_s  cstype;
      rv64_instr_catype_s  catype;
      rv64_instr_cbtype_s  cbtype;
      rv64_instr_cjtype_s  cjtype;
    }  t;
  }  rv64_cinstr_s;

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

  /*
   * RV64 specifies a 64b effective address and 32b instruction.
   * BlackParrot supports SV39 virtual memory, which specifies 39b virtual / 56b physical address.
   * Effective addresses must have bits 39-63 match bit 38
   *   or a page fault exception will occur during translation.
   * Currently, we only support a very limited number of parameter configurations.
   * Thought: We could have a `define surrounding core instantiations of each parameter and then
   * when they import this package, `declare the if structs. No more casting!
   */

  localparam sv39_pte_width_gp          = 64;
  localparam sv39_levels_gp             = 3;
  localparam sv39_vaddr_width_gp        = 39;
  localparam sv39_paddr_width_gp        = 56;
  localparam sv39_ppn_width_gp          = 44;
  localparam sv39_page_idx_width_gp     = 9;
  localparam sv39_page_offset_width_gp  = 12;
  localparam sv39_page_size_in_bytes_gp = 1 << sv39_page_offset_width_gp;
  localparam sv39_pte_size_in_bytes_gp  = 8;

  typedef struct packed
  {
    logic [sv39_pte_width_gp-10-sv39_ppn_width_gp-1:0] reserved;
    logic [sv39_ppn_width_gp-1:0] ppn;
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
  }  sv39_pte_s;

`endif


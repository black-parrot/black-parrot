/*
 * bp_common_pkg.sv
 *
 * Contains the interface structures used for communicating between FE, BE, ME in BlackParrot.
 * Additionally contains global parameters used to configure the system. In the future, when
 *   multiple configurations are supported, these global parameters will belong to groups
 *   e.g. SV39, VM-disabled, ...
 *
 */

package bp_common_pkg;

  `include "bsg_defines.v"
  `include "bp_common_defines.svh"
  `include "bp_common_core_if.svh"
  `include "bp_common_bedrock_if.svh"
  `include "bp_common_cache_engine_if.svh"
  `include "bp_common_rv64_defines.svh"
  `include "bp_common_csr_defines.svh"

  /*
   * RV64 specifies a 64b effective address and 32b instruction.
   * BlackParrot supports SV39 virtual memory, which specifies 39b virtual / 56b physical address.
   * Effective addresses must have bits 39-63 match bit 38
   *   or a page fault exception will occur during translation.
   * Currently, we only support a very limited number of parameter configurations.
   * Thought: We could have a `define surrounding core instantiations of each parameter and then
   * when they import this package, `declare the if structs. No more casting!
   */

  localparam bp_sv39_page_table_depth_gp = 3;
  localparam bp_sv39_pte_width_gp = 64;
  localparam bp_sv39_vaddr_width_gp = 39;
  localparam bp_sv39_paddr_width_gp = 56;
  localparam bp_sv39_ppn_width_gp = 44;
  localparam bp_page_size_in_bytes_gp = 4096;

  typedef struct packed
  {
    logic [bp_sv39_pte_width_gp-10-bp_sv39_ppn_width_gp-1:0] reserved;
    logic [bp_sv39_ppn_width_gp-1:0] ppn;
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
  }  bp_sv39_pte_s;

  localparam dword_width_p       = 64;
  localparam word_width_p        = 32;
  localparam half_width_p        = 16;
  localparam byte_width_p        = 8;
  localparam instr_width_p       = 32;
  localparam csr_addr_width_p    = 12;
  localparam reg_addr_width_p    = 5;
  localparam page_offset_width_p = 12;

  localparam boot_dev_gp  = 0;
  localparam host_dev_gp  = 1;
  localparam cfg_dev_gp   = 2;
  localparam clint_dev_gp = 3;
  localparam cache_dev_gp = 4;

                             // 0x00_0(nnnN)(D)(A_AAAA)
  localparam boot_dev_base_addr_gp     = 32'h0000_0000;
  localparam host_dev_base_addr_gp     = 32'h0010_0000;
  localparam cfg_dev_base_addr_gp      = 32'h0020_0000;
  localparam clint_dev_base_addr_gp    = 32'h0030_0000;
  localparam cache_dev_base_addr_gp    = 32'h0040_0000;

  localparam mipi_reg_base_addr_gp     = 32'h0030_0000;
  localparam mtimecmp_reg_base_addr_gp = 32'h0030_4000;
  localparam mtime_reg_addr_gp         = 32'h0030_bff8;
  localparam plic_reg_base_addr_gp     = 32'h0030_b000;

  localparam cache_tagfl_base_addr_gp  = 20'h0_0000;

  localparam bootrom_base_addr_gp      = 40'h00_0001_0000;
  localparam dram_base_addr_gp         = 40'h00_8000_0000;
  localparam coproc_base_addr_gp       = 40'h10_0000_0000;
  localparam global_base_addr_gp       = 40'h20_0000_0000;

  // TODO: This is out of date.  The actual map shouldn't matter much, but we should decide...
  // The overall memory map of the config link is:
  //   16'h0000 - 16'h001f: chip level config
  //   16'h0020 - 16'h003f: fe config
  //   16'h0040 - 16'h005f: be config
  //   16'h0060 - 16'h007f: me config
  //   16'h0080 - 16'h00ff: reserved
  //   16'h8000 - 16'h8fff: cce ucode

  localparam bp_cfg_base_addr_gp          = 'h0200_0000;
  localparam bp_cfg_reg_reset_gp          = 'h0001;
  localparam bp_cfg_reg_freeze_gp         = 'h0002;
  localparam bp_cfg_reg_core_id_gp        = 'h0005;
  localparam bp_cfg_reg_did_gp            = 'h0006;
  localparam bp_cfg_reg_cord_gp           = 'h0007;
  localparam bp_cfg_reg_host_did_gp       = 'h0008;
  localparam bp_cfg_reg_domain_mask_gp    = 'h0009;
  localparam bp_cfg_reg_sac_mask_gp       = 'h000a;
  localparam bp_cfg_reg_icache_id_gp      = 'h0021;
  localparam bp_cfg_reg_icache_mode_gp    = 'h0022;
  localparam bp_cfg_reg_dcache_id_gp      = 'h0042;
  localparam bp_cfg_reg_dcache_mode_gp    = 'h0043;
  localparam bp_cfg_reg_cce_id_gp         = 'h0080;
  localparam bp_cfg_reg_cce_mode_gp       = 'h0081;
  localparam bp_cfg_reg_num_lce_gp        = 'h0082;
  localparam bp_cfg_mem_base_cce_ucode_gp = 'h8000;

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

  `include "bp_common_aviary_pkgdef.svh"

endpackage


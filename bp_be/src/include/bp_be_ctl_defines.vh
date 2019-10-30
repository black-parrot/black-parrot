`ifndef BP_BE_CTL_DEFINES_VH
`define BP_BE_CTL_DEFINES_VH

/* int_fu_op [2:0] is equivalent to funct3 in the RV instruction.
 * int_fu_op [3] is an alternate version of that operation.
 */
typedef enum bit [3:0]
{
  e_int_op_add        = 4'b0000
  ,e_int_op_sub       = 4'b1000
  ,e_int_op_sll       = 4'b0001
  ,e_int_op_slt       = 4'b0010
  ,e_int_op_sge       = 4'b1010
  ,e_int_op_sltu      = 4'b0011
  ,e_int_op_sgeu      = 4'b1011
  ,e_int_op_xor       = 4'b0100
  ,e_int_op_eq        = 4'b1100
  ,e_int_op_srl       = 4'b0101
  ,e_int_op_sra       = 4'b1101
  ,e_int_op_or        = 4'b0110
  ,e_int_op_ne        = 4'b1110
  ,e_int_op_and       = 4'b0111
  ,e_int_op_pass_src2 = 4'b1111
} bp_be_int_fu_op_e;

typedef enum bit [3:0]
{
  e_lb     = 4'b0000
  ,e_lh    = 4'b0001
  ,e_lw    = 4'b0010
  ,e_ld    = 4'b0011
  ,e_lbu   = 4'b0100
  ,e_lhu   = 4'b0101
  ,e_lwu   = 4'b0110

  ,e_sb    = 4'b1000
  ,e_sh    = 4'b1001
  ,e_sw    = 4'b1010
  ,e_sd    = 4'b1011

  ,e_lrw   = 4'b0111
  ,e_scw   = 4'b1100

  ,e_lrd   = 4'b1101
  ,e_scd   = 4'b1110

  ,e_itlb_fill = 4'b1111
} bp_be_mmu_fu_op_e;

typedef enum bit [3:0]
{
  e_csrrw   = 4'b0001
  ,e_csrrs  = 4'b0010
  ,e_csrrc  = 4'b0011
  ,e_csrrwi = 4'b0101
  ,e_csrrsi = 4'b0110
  ,e_csrrci = 4'b0111

  ,e_mret   = 4'b1011
  ,e_sret   = 4'b1001

  // TODO: Think more carefully about these encodings
  ,e_ecall      = 4'b1110
  ,e_wfi        = 4'b1100
  ,e_ebreak     = 4'b1111

  ,e_sfence_vma = 4'b1101

  // We treat FE exceptions as CSR ops
  ,e_op_take_interrupt     = 4'b1000
  ,e_op_illegal_instr      = 4'b0000
  ,e_op_instr_access_fault = 4'b0100
  ,e_op_instr_misaligned   = 4'b1010
} bp_be_csr_fu_op_e;

typedef struct packed
{
  union packed
  {
    bp_be_int_fu_op_e int_fu_op;
    bp_be_mmu_fu_op_e mmu_fu_op;
    bp_be_csr_fu_op_e csr_fu_op;
  }  fu_op;
}  bp_be_fu_op_s;

typedef enum bit
{
  e_src1_is_rs1 = 1'b0
  ,e_src1_is_pc = 1'b1
} bp_be_src1_e;

typedef enum bit
{
  e_src2_is_rs2  = 1'b0
  ,e_src2_is_imm = 1'b1
} bp_be_src2_e;

typedef enum bit
{
  e_baddr_is_pc   = 1'b0
  ,e_baddr_is_rs1 = 1'b1
} bp_be_baddr_e;

typedef enum bit
{
  e_offset_is_imm   = 1'b0
  ,e_offset_is_zero = 1'b1
} bp_be_offset_e;

typedef enum bit
{
  e_result_from_alu       = 1'b0
  ,e_result_from_pc_plus4 = 1'b1
} bp_be_result_e;

typedef struct packed
{
  logic                             queue_v;
  logic                             instr_v;

  logic                             pipe_comp_v;
  logic                             pipe_int_v;
  logic                             pipe_mul_v;
  logic                             pipe_mem_v;
  logic                             pipe_fp_v;

  logic                             irf_w_v;
  logic                             frf_w_v;
  logic                             mem_v;
  logic                             dcache_r_v;
  logic                             dcache_w_v;
  logic                             csr_w_v;
  logic                             csr_r_v;
  logic                             csr_v;
  logic                             fencei_v;
  logic                             fp_not_int_v;
  logic                             jmp_v;
  logic                             br_v;
  logic                             opw_v;

  bp_be_fu_op_s                     fu_op;

  bp_be_src1_e                      src1_sel;
  bp_be_src2_e                      src2_sel;
  bp_be_baddr_e                     baddr_sel;
  bp_be_offset_e                    offset_sel;
  bp_be_result_e                    result_sel;
}  bp_be_decode_s;

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
  logic store_fault;
  logic store_misaligned;
  logic load_fault;
  logic load_misaligned;
  logic breakpoint;
  logic illegal_instr;
  logic instr_fault;
  logic instr_misaligned;
}  bp_be_ecode_dec_s;

`define bp_be_ecode_dec_width \
  ($bits(bp_be_ecode_dec_s))

typedef struct packed
{
  // BE exceptional conditions
  logic fe_nop_v;
  logic be_nop_v;
  logic me_nop_v;
  logic poison_v;
  logic roll_v;
}  bp_be_exception_s;

`define bp_be_fu_op_width                                                                          \
  (`BSG_MAX($bits(bp_be_int_fu_op_e), `BSG_MAX($bits(bp_be_mmu_fu_op_e), $bits(bp_be_csr_fu_op_e))))

`define bp_be_decode_width                                                                         \
  ($bits(bp_be_decode_s))

`define bp_be_exception_width                                                                      \
  ($bits(bp_be_exception_s))

`endif


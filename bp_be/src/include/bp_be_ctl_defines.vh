`ifndef BP_BE_CTL_DEFINES_VH
`define BP_BE_CTL_DEFINES_VH

/* int_fu_op [2:0] is equivalent to funct3 in the RV instruction.
 * int_fu_op [3] is an alternate version of that operation.
 */
typedef enum bit [4:0]
{
  e_int_op_add        = 5'b00000
  ,e_int_op_sub       = 5'b01000
  ,e_int_op_sll       = 5'b00001
  ,e_int_op_slt       = 5'b00010
  ,e_int_op_sge       = 5'b01010
  ,e_int_op_sltu      = 5'b00011
  ,e_int_op_sgeu      = 5'b01011
  ,e_int_op_xor       = 5'b00100
  ,e_int_op_eq        = 5'b01100
  ,e_int_op_srl       = 5'b00101
  ,e_int_op_sra       = 5'b01101
  ,e_int_op_or        = 5'b00110
  ,e_int_op_ne        = 5'b01110
  ,e_int_op_and       = 5'b00111
  ,e_int_op_pass_src2 = 5'b01111
} bp_be_int_fu_op_e;

typedef enum bit [4:0]
{
  e_lb     = 5'b00000
  ,e_lh    = 5'b00001
  ,e_lw    = 5'b00010
  ,e_ld    = 5'b00011
  ,e_lbu   = 5'b00100
  ,e_lhu   = 5'b00101
  ,e_lwu   = 5'b00110

  ,e_sb    = 5'b01000
  ,e_sh    = 5'b01001
  ,e_sw    = 5'b01010
  ,e_sd    = 5'b01011

  ,e_lrw   = 5'b00111
  ,e_scw   = 5'b01100

  ,e_lrd   = 5'b01101
  ,e_scd   = 5'b01110

  ,e_ptw_i = 5'b10000
  ,e_ptw_l = 5'b10001
  ,e_ptw_s = 5'b10010

  ,e_fence   = 5'b10011
  ,e_fence_i = 5'b10100

  ,e_mmu_nop = 5'b11111
} bp_be_mmu_fu_op_e;

typedef enum bit [4:0]
{
  e_csrrw   = 5'b00001
  ,e_csrrs  = 5'b00010
  ,e_csrrc  = 5'b00011
  ,e_csrrwi = 5'b00101
  ,e_csrrsi = 5'b00110
  ,e_csrrci = 5'b00111

  ,e_mret   = 5'b01011
  ,e_sret   = 5'b01001
  ,e_uret   = 5'b01000

  ,e_sfence_vma = 5'b01100

  ,e_csr_nop    = 5'b11111
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
  logic                             instr_v;

  logic                             pipe_comp_v;
  logic                             pipe_int_v;
  logic                             pipe_mul_v;
  logic                             pipe_mem_v;
  logic                             pipe_fp_v;

  logic                             irf_w_v;
  logic                             frf_w_v;
  logic                             csr_instr_v;
  logic                             ifence_v;
  logic                             fence_v;
  logic                             dcache_w_v;
  logic                             dcache_r_v;
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
  logic fe_exc_v;
  logic fe_nop_v;
  logic be_nop_v;
  logic me_nop_v;
  logic poison_v;
  logic roll_v;

  logic csr_instr_v;
  logic ifence_v;
  logic itlb_fill_v;  

  logic instr_misaligned_v;
  logic instr_access_fault_v;
  logic illegal_instr_v;
}  bp_be_exception_s;

`define bp_be_fu_op_width                                                                          \
  (`BSG_MAX($bits(bp_be_int_fu_op_e), `BSG_MAX($bits(bp_be_mmu_fu_op_e), $bits(bp_be_csr_fu_op_e))))

`define bp_be_decode_width                                                                         \
  ($bits(bp_be_decode_s))

`define bp_be_exception_width                                                                      \
  ($bits(bp_be_exception_s))

`endif


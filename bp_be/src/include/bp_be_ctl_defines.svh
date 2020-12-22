`ifndef BP_BE_CTL_DEFINES_VH
`define BP_BE_CTL_DEFINES_VH

  typedef enum logic [5:0]
  {
    e_ctrl_op_beq       = 6'b000000
    ,e_ctrl_op_bne      = 6'b000001
    ,e_ctrl_op_blt      = 6'b000010
    ,e_ctrl_op_bltu     = 6'b000011
    ,e_ctrl_op_bge      = 6'b000100
    ,e_ctrl_op_bgeu     = 6'b000101
    ,e_ctrl_op_jal      = 6'b000110
    ,e_ctrl_op_jalr     = 6'b000111
  } bp_be_ctrl_fu_op_e;
  
  typedef enum logic [5:0]
  {
    e_int_op_add        = 6'b000000
    ,e_int_op_sub       = 6'b001000
    ,e_int_op_sll       = 6'b000001
    ,e_int_op_slt       = 6'b000010
    ,e_int_op_sge       = 6'b001010
    ,e_int_op_sltu      = 6'b000011
    ,e_int_op_sgeu      = 6'b001011
    ,e_int_op_xor       = 6'b000100
    ,e_int_op_eq        = 6'b001100
    ,e_int_op_srl       = 6'b000101
    ,e_int_op_sra       = 6'b001101
    ,e_int_op_or        = 6'b000110
    ,e_int_op_ne        = 6'b001110
    ,e_int_op_and       = 6'b000111
    ,e_int_op_pass_src2 = 6'b001111
  } bp_be_int_fu_op_e;
  
  typedef enum logic [5:0]
  {
    // Movement instructions
    e_aux_op_f2f        = 6'b000000
    ,e_aux_op_f2i       = 6'b000001
    ,e_aux_op_i2f       = 6'b000010
    ,e_aux_op_f2iu      = 6'b000011
    ,e_aux_op_iu2f      = 6'b000100
    ,e_aux_op_imvf      = 6'b000101
    ,e_aux_op_fmvi      = 6'b000110
    ,e_aux_op_fsgnj     = 6'b000111
    ,e_aux_op_fsgnjn    = 6'b001000
    ,e_aux_op_fsgnjx    = 6'b001001
  
    // FCMP instructions
    ,e_aux_op_feq       = 6'b001010
    ,e_aux_op_flt       = 6'b001011
    ,e_aux_op_fle       = 6'b001100
    ,e_aux_op_fmax      = 6'b001101
    ,e_aux_op_fmin      = 6'b001110
    ,e_aux_op_fclass    = 6'b001111
  } bp_be_aux_fu_op_e;
  
  typedef enum logic [5:0]
  {
    e_dcache_op_lb        = 6'b000000
    ,e_dcache_op_lh       = 6'b000001
    ,e_dcache_op_lw       = 6'b000010
    ,e_dcache_op_ld       = 6'b000011
    ,e_dcache_op_lbu      = 6'b000100
    ,e_dcache_op_lhu      = 6'b000101
    ,e_dcache_op_lwu      = 6'b000110
  
    ,e_dcache_op_sb       = 6'b001000
    ,e_dcache_op_sh       = 6'b001001
    ,e_dcache_op_sw       = 6'b001010
    ,e_dcache_op_sd       = 6'b001011
  
    ,e_dcache_op_lrw      = 6'b000111
    ,e_dcache_op_scw      = 6'b001100
  
    ,e_dcache_op_lrd      = 6'b001101
    ,e_dcache_op_scd      = 6'b001110
  
    ,e_dcache_op_flw      = 6'b100010
    ,e_dcache_op_fld      = 6'b100011
  
    ,e_dcache_op_fsw      = 6'b100100
    ,e_dcache_op_fsd      = 6'b100101
  
    ,e_dcache_op_amoswapw = 6'b010000
    ,e_dcache_op_amoaddw  = 6'b010001
    ,e_dcache_op_amoxorw  = 6'b010010
    ,e_dcache_op_amoandw  = 6'b010011
    ,e_dcache_op_amoorw   = 6'b010100
    ,e_dcache_op_amominw  = 6'b010101
    ,e_dcache_op_amomaxw  = 6'b010110
    ,e_dcache_op_amominuw = 6'b010111
    ,e_dcache_op_amomaxuw = 6'b011000
  
    ,e_dcache_op_amoswapd = 6'b011001
    ,e_dcache_op_amoaddd  = 6'b011010
    ,e_dcache_op_amoxord  = 6'b011011
    ,e_dcache_op_amoandd  = 6'b011100
    ,e_dcache_op_amoord   = 6'b011101
    ,e_dcache_op_amomind  = 6'b011110
    ,e_dcache_op_amomaxd  = 6'b011111
    ,e_dcache_op_amominud = 6'b100000
    ,e_dcache_op_amomaxud = 6'b100001
  
    ,e_dcache_op_fencei   = 6'b111111
  } bp_be_dcache_fu_op_e;
  
  typedef enum logic [5:0]
  {
    e_csrrw   = 6'b000001
    ,e_csrrs  = 6'b000010
    ,e_csrrc  = 6'b000011
    ,e_csrrwi = 6'b000100
    ,e_csrrsi = 6'b000101
    ,e_csrrci = 6'b000110
  
    ,e_dret       = 6'b010011
    ,e_mret       = 6'b001000
    ,e_sret       = 6'b001001
    ,e_sfence_vma = 6'b001011
    ,e_wfi        = 6'b001100
    ,e_ebreak     = 6'b010100
    ,e_ecall      = 6'b011011
  } bp_be_csr_fu_op_e;
  
  typedef enum logic [5:0]
  {
    e_fma_op_fadd    = 6'b000000
    ,e_fma_op_fsub   = 6'b000001
    ,e_fma_op_fmul   = 6'b000010
    ,e_fma_op_fmadd  = 6'b000011
    ,e_fma_op_fmsub  = 6'b000100
    ,e_fma_op_fnmsub = 6'b000101
    ,e_fma_op_fnmadd = 6'b000110
    ,e_fma_op_imul   = 6'b000111
    ,e_fma_op_fdiv   = 6'b001000
    ,e_fma_op_fsqrt  = 6'b001001
  } bp_be_fma_fu_op_e;
  
  typedef enum logic [5:0]
  {
    e_mul_op_mul        = 6'b000000
    ,e_mul_op_div       = 6'b000001
    ,e_mul_op_divu      = 6'b000010
    ,e_mul_op_rem       = 6'b000011
    ,e_mul_op_remu      = 6'b000100
  } bp_be_mul_fu_op_e;
  
  typedef struct packed
  {
    union packed
    {
      bp_be_ctrl_fu_op_e     ctrl_fu_op;
      bp_be_aux_fu_op_e      aux_fu_op;
      bp_be_int_fu_op_e      int_fu_op;
      bp_be_dcache_fu_op_e   dcache_op;
      bp_be_csr_fu_op_e      csr_fu_op;
      bp_be_fma_fu_op_e      fma_fu_op;
      bp_be_mul_fu_op_e      mul_fu_op;
    }  fu_op;
  }  bp_be_fu_op_s;
  
  typedef enum logic
  {
    e_src1_is_rs1 = 1'b0
    ,e_src1_is_pc = 1'b1
  } bp_be_src1_e;
  
  typedef enum logic
  {
    e_src2_is_rs2  = 1'b0
    ,e_src2_is_imm = 1'b1
  } bp_be_src2_e;
  
  typedef enum logic
  {
    e_baddr_is_pc   = 1'b0
    ,e_baddr_is_rs1 = 1'b1
  } bp_be_baddr_e;
  
  typedef enum logic
  {
    e_offset_is_imm   = 1'b0
    ,e_offset_is_zero = 1'b1
  } bp_be_offset_e;
  
  typedef enum logic
  {
    e_result_from_alu       = 1'b0
    ,e_result_from_pc_plus4 = 1'b1
  } bp_be_result_e;
  
  typedef struct packed
  {
    logic                             v;
  
    logic                             pipe_ctl_v;
    logic                             pipe_int_v;
    logic                             pipe_mem_early_v;
    logic                             pipe_aux_v;
    logic                             pipe_mem_final_v;
    logic                             pipe_sys_v;
    logic                             pipe_mul_v;
    logic                             pipe_fma_v;
    logic                             pipe_long_v;
  
    logic                             irf_w_v;
    logic                             frf_w_v;
    logic                             fflags_w_v;
    logic                             dcache_r_v;
    logic                             dcache_w_v;
    logic                             late_iwb_v;
    logic                             late_fwb_v;
    logic                             fencei_v;
    logic                             csr_w_v;
    logic                             csr_r_v;
    logic                             csr_v;
    logic                             mem_v;
    logic                             opw_v;
    logic                             ops_v;
  
    bp_be_fu_op_s                     fu_op;
  
    bp_be_src1_e                      src1_sel;
    bp_be_src2_e                      src2_sel;
    bp_be_baddr_e                     baddr_sel;
  
    logic                             itlb_miss;
    logic                             icache_miss;
    logic                             instr_access_fault;
    logic                             instr_page_fault;
    logic                             illegal_instr;
    logic                             ebreak;
    logic                             ecall;
  }  bp_be_decode_s;
  
  typedef struct packed
  {
    // RISC-V exceptions
    logic store_page_fault;
    logic load_page_fault;
    logic instr_page_fault;
    logic ecall;
    logic store_access_fault;
    logic store_misaligned;
    logic load_access_fault;
    logic load_misaligned;
    logic ebreak;
    logic illegal_instr;
    logic instr_access_fault;
    logic instr_misaligned;
  
    // BP "exceptions"
    logic itlb_miss;
    logic icache_miss;
    logic dtlb_miss;
    logic dcache_miss;
    logic fencei_v;
  }  bp_be_exception_s;
  
  typedef struct packed
  {
    logic nop_v;
    logic poison_v;
    logic roll_v;
  
    bp_be_exception_s exc;
  }  bp_be_exc_stage_s;

`define bp_be_fu_op_width                                                                          \
  (`BSG_MAX($bits(bp_be_int_fu_op_e), `BSG_MAX($bits(bp_be_dcache_fu_op_e), $bits(bp_be_csr_fu_op_e))))

`define bp_be_decode_width                                                                         \
  ($bits(bp_be_decode_s))

`define bp_be_exception_width                                                                      \
  ($bits(bp_be_exception_s))

`define bp_be_exc_stage_width                                                                      \
  ($bits(bp_be_exc_stage_s))

`endif


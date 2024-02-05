
`ifndef BP_BE_CTL_PKGDEF_SVH
`define BP_BE_CTL_PKGDEF_SVH

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
    ,e_int_op_pass_one  = 6'b111110
    ,e_int_op_pass_zero = 6'b111111
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

    ,e_dcache_op_ptw      = 6'b111000

    ,e_dcache_op_bzero    = 6'b110000
    ,e_dcache_op_bclean   = 6'b110001
    ,e_dcache_op_binval   = 6'b110010
    ,e_dcache_op_bflush   = 6'b110100
    ,e_dcache_op_clean    = 6'b111110
    ,e_dcache_op_inval    = 6'b111101
    ,e_dcache_op_flush    = 6'b111111
  } bp_be_dcache_fu_op_e;

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
  } bp_be_fma_fu_op_e;

  typedef enum logic [5:0]
  {
    e_long_op_div     = 6'b000001
    ,e_long_op_divu   = 6'b000010
    ,e_long_op_rem    = 6'b000011
    ,e_long_op_remu   = 6'b000100
    ,e_long_op_mulh   = 6'b000101
    ,e_long_op_mulhsu = 6'b000110
    ,e_long_op_mulhu  = 6'b000111
    ,e_long_op_fdiv   = 6'b001000
    ,e_long_op_fsqrt  = 6'b001001
  } bp_be_long_fu_op_e;

  typedef struct packed
  {
    union packed
    {
      bp_be_int_fu_op_e      int_fu_op;
      bp_be_aux_fu_op_e      aux_fu_op;
      bp_be_dcache_fu_op_e   dcache_fu_op;
      bp_be_fma_fu_op_e      fma_fu_op;
      bp_be_long_fu_op_e     long_fu_op;
    }  t;
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

  typedef struct packed
  {
    logic                              compressed;

    logic                              pipe_int_v;
    logic                              pipe_mem_early_v;
    logic                              pipe_aux_v;
    logic                              pipe_mem_final_v;
    logic                              pipe_sys_v;
    logic                              pipe_mul_v;
    logic                              pipe_fma_v;
    logic                              pipe_long_v;

    logic                              irs1_r_v;
    logic                              irs2_r_v;
    logic                              frs1_r_v;
    logic                              frs2_r_v;
    logic                              frs3_r_v;
    logic                              irf_w_v;
    logic                              frf_w_v;
    logic                              branch_v;
    logic                              jump_v;
    logic                              fence_v;
    logic                              dcache_r_v;
    logic                              dcache_w_v;
    logic                              dcache_cbo_v;
    logic                              dcache_mmu_v;
    logic                              csr_w_v;
    logic                              csr_r_v;
    logic                              mem_v;
    logic                              score_v;
    logic                              spec_w_v;

    logic                              fp_raw;
    logic                              rs1_unsigned;
    logic                              rs2_unsigned;

    bp_be_fu_op_s                      fu_op;
    logic [$bits(bp_be_fp_tag_e)-1:0]  fp_tag;
    logic [$bits(bp_be_int_tag_e)-1:0] int_tag;

    logic [$bits(bp_be_src1_e)-1:0]    src1_sel;
    logic [$bits(bp_be_src2_e)-1:0]    src2_sel;
    logic [$bits(bp_be_baddr_e)-1:0]   baddr_sel;
  }  bp_be_decode_s;

  typedef struct packed
  {
    // True exceptions
    logic store_page_fault;
    logic load_page_fault;
    logic instr_page_fault;
    logic ecall_m;
    logic ecall_s;
    logic ecall_u;
    logic store_access_fault;
    logic store_misaligned;
    logic load_access_fault;
    logic load_misaligned;
    logic ebreak;
    logic illegal_instr;
    logic instr_access_fault;
    logic instr_misaligned;

    // BP "exceptions"
    logic resume;
    logic itlb_miss;
    logic icache_miss;
    logic dcache_replay;
    logic dtlb_load_miss;
    logic dtlb_store_miss;
    logic itlb_fill;
    logic dtlb_fill;
    logic _interrupt;
    logic cmd_full;
    logic mispredict;
  }  bp_be_exception_s;

  typedef struct packed
  {
    logic dcache_miss;
    logic fencei;
    logic sfence_vma;
    logic dbreak;
    logic dret;
    logic mret;
    logic sret;
    logic wfi;
    logic csrw;
  }  bp_be_special_s;

  typedef struct packed
  {
    logic v;
    logic queue_v;
    logic partial_v;
    logic ispec_v;
    logic nspec_v;

    bp_be_exception_s exc;
    bp_be_special_s   spec;
  }  bp_be_exc_stage_s;

`endif


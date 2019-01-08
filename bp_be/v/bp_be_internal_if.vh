/**
 *
 * bp_be_internal_if.v
 *
 */

`ifndef BP_BE_INTERNAL_IF_VH
`define BP_BE_INTERNAL_IF_VH

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"

`include "bp_be_rv_defines.vh"

import bp_common_pkg::*;

/* TODO: I should live somewhere else? */
localparam bp_be_itag_width_gp    = 32;

/*
 * Clients need only use this macro to declare all parameterized structs for FE<->BE interface.
 */
`define declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    `declare_bp_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p);                                    \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        union packed                                                                               \
        {                                                                                          \
            bp_be_int_fu_op_e int_fu_op;                                                           \
            bp_be_mem_fu_op_e mem_fu_op;                                                           \
        } fu_op;                                                                                   \
    } bp_be_fu_op_s;                                                                               \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic                               pipe_comp_v;                                           \
        logic                               pipe_int_v;                                            \
        logic                               pipe_mul_v;                                            \
        logic                               pipe_mem_v;                                            \
        logic                               pipe_fp_v;                                             \
                                                                                                   \
        logic                               fe_nop_v;                                              \
        logic                               be_nop_v;                                              \
        logic                               me_nop_v;                                              \
        logic                               irf_w_v;                                               \
        logic                               frf_w_v;                                               \
        logic                               csr_w_v;                                               \
        logic                               mhartid_r_v;                                           \
        logic                               dcache_w_v;                                            \
        logic                               dcache_r_v;                                            \
        logic                               fp_not_int_v;                                          \
        logic                               cache_miss_v;                                          \
        logic                               exception_v;                                           \
        logic                               ret_v;                                                 \
        logic                               amo_v;                                                 \
        logic                               llop_v;                                                \
        logic                               jmp_v;                                                 \
        logic                               br_v;                                                  \
        logic                               op32_v;                                                \
        logic                               toggle_v;                                              \
                                                                                                   \
        bp_be_fu_op_s                       fu_op;                                                 \
        logic [RV64_reg_addr_width_gp-1:0]  rs1_addr;                                              \
        logic [RV64_reg_addr_width_gp-1:0]  rs2_addr;                                              \
        logic [RV64_reg_addr_width_gp-1:0]  rd_addr;                                               \
                                                                                                   \
        bp_be_src1_e                        src1_sel;                                              \
        bp_be_src2_e                        src2_sel;                                              \
        bp_be_baddr_e                       baddr_sel;                                             \
        bp_be_result_e                      result_sel;                                            \
    } bp_be_decode_s;                                                                              \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic [bp_be_itag_width_gp-1:0]          itag;                                             \
        logic [RV64_eaddr_width_gp-1:0]          pc;                                               \
        logic                                    fe_exception_not_instr;                           \
        bp_fe_exception_code_e                   fe_exception_code;                                \
        logic [branch_metadata_fwd_width_p-1:0]  branch_metadata_fwd;                              \
    } bp_be_instr_metadata_s;                                                                      \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        bp_be_instr_metadata_s             instr_metadata;                                         \
        logic [RV64_instr_width_gp-1:0]    instr;                                                  \
        logic                              irs1_v;                                                 \
        logic                              irs2_v;                                                 \
        logic                              frs1_v;                                                 \
        logic                              frs2_v;                                                 \
        logic [RV64_reg_addr_width_gp-1:0] rs1_addr;                                               \
        logic [RV64_reg_addr_width_gp-1:0] rs2_addr;                                               \
        logic [RV64_reg_data_width_gp-1:0] imm;                                                    \
    } bp_be_fe_adapter_issue_s;                                                                    \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic                                   isd_v;                                             \
        logic [RV64_eaddr_width_gp-1:0]         npc_expected;                                      \
        logic [branch_metadata_fwd_width_p-1:0] branch_metadata_fwd;                               \
        logic                                   incorrect_npc;                                     \
        logic                                   br_or_jmp_v;                                       \
    } bp_be_chk_npc_status_s;                                                                      \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic [RV64_reg_data_width_gp-1:0] rs1;                                                    \
        logic [RV64_reg_data_width_gp-1:0] rs2;                                                    \
        logic [RV64_reg_data_width_gp-1:0] imm;                                                    \
    } bp_be_instr_operands_s;                                                                      \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        bp_be_instr_metadata_s          instr_metadata;                                            \
        logic [RV64_instr_width_gp-1:0] instr;                                                     \
        bp_be_instr_operands_s          instr_operands;                                            \
        bp_be_decode_s                  decode;                                                    \
    } bp_be_pipe_stage_reg_s;                                                                      \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic                              int_iwb_v;                                              \
        logic                              mul_iwb_v;                                              \
        logic                              mem_iwb_v;                                              \
        logic                              mem_fwb_v;                                              \
        logic                              fp_fwb_v;                                               \
                                                                                                   \
        logic [RV64_reg_addr_width_gp-1:0] rd_addr;                                                \
    } bp_be_haz_status_s;                                                                          \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic                                   isd_v;                                             \
        logic [RV64_eaddr_width_gp-1:0]         isd_pc;                                            \
        logic                                   isd_irs1_v;                                        \
        logic                                   isd_frs1_v;                                        \
        logic [RV64_reg_addr_width_gp-1:0]      isd_rs1_addr;                                      \
        logic                                   isd_irs2_v;                                        \
        logic                                   isd_frs2_v;                                        \
        logic [RV64_reg_addr_width_gp-1:0]      isd_rs2_addr;                                      \
                                                                                                   \
        logic                                   int1_v;                                            \
        logic [RV64_eaddr_width_gp-1:0]         int1_br_tgt;                                       \
        logic [branch_metadata_fwd_width_p-1:0] int1_branch_metadata_fwd;                          \
        logic                                   int1_br_or_jmp_v;                                  \
                                                                                                   \
        logic                                   ex1_v;                                             \
                                                                                                   \
        bp_be_haz_status_s[4:0]                 haz;                                               \
                                                                                                   \
        logic                                   mem3_v;                                            \
        logic [RV64_eaddr_width_gp-1:0]         mem3_pc;                                           \
        logic                                   mem3_cache_miss_v;                                 \
        logic                                   mem3_exception_v;                                  \
        logic                                   mem3_ret_v;                                        \
                                                                                                   \
        logic                                   instr_ckpt_v;                                      \
    } bp_be_calc_status_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic [RV64_reg_data_width_gp-1:0] result;                                                 \
        logic [RV64_eaddr_width_gp-1:0]    br_tgt;                                                 \
    } bp_be_calc_result_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        bp_be_fu_op_s                      mem_op;                                                 \
        logic [RV64_eaddr_width_gp-1:0]    addr;                                                   \
        logic [RV64_reg_data_width_gp-1:0] data;                                                   \
    } bp_be_mmu_cmd_s;                                                                             \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic psn_v;                                                                               \
        logic roll_v;                                                                              \
        logic illegal_instr_v;                                                                     \
        logic tlb_miss_v;                                                                          \
        logic load_fault_v;                                                                        \
        logic store_fault_v;                                                                       \
        logic cache_miss_v;                                                                        \
    } bp_be_exception_s;                                                                           \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic [RV64_reg_data_width_gp-1:0] data;                                                   \
        bp_be_exception_s                  exception;                                              \
    } bp_be_mmu_resp_s;                                                                            \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
        logic [RV64_funct7_width_gp-1:0]   funct7;                                                 \
        logic [RV64_reg_addr_width_gp-1:0] rs2_addr;                                               \
        logic [RV64_reg_addr_width_gp-1:0] rs1_addr;                                               \
        logic [RV64_funct3_width_gp-1:0]   funct3;                                                 \
        logic [RV64_reg_addr_width_gp-1:0] rd_addr;                                                \
        logic [RV64_opcode_width_gp-1:0]   opcode;                                                 \
    } bp_be_instr_s;

/* int_fu_op [2:0] is equivalent to funct3 in the RV instruction.
 * int_fu_op [3] is an alternate version of that operation.
 */
typedef enum bit[3:0]
{
    e_int_op_add        = 4'b0_000
    ,e_int_op_sub       = 4'b1_000
    ,e_int_op_sll       = 4'b0_001
    ,e_int_op_slt       = 4'b0_010
    ,e_int_op_sltu      = 4'b0_011
    ,e_int_op_xor       = 4'b0_100
    ,e_int_op_eq        = 4'b1_100
    ,e_int_op_srl       = 4'b0_101
    ,e_int_op_sra       = 4'b1_101
    ,e_int_op_or        = 4'b0_110
    ,e_int_op_and       = 4'b0_111
    ,e_int_op_pass_src2 = 4'b1_111
} bp_be_int_fu_op_e;

typedef enum bit[3:0]
{
    e_lb   = 4'b0_000
    ,e_lh  = 4'b0_001
    ,e_lw  = 4'b0_010
    ,e_lbu = 4'b0_100
    ,e_lhu = 4'b0_101
    ,e_lwu = 4'b0_110
    ,e_ld  = 4'b0_011

    ,e_sb  = 4'b1_100
    ,e_sh  = 4'b1_101
    ,e_sw  = 4'b1_110
    ,e_sd  = 4'b1_011
} bp_be_mem_fu_op_e;

typedef enum bit[2:0]
{
    e_pipe_comp  = 3'b000
    ,e_pipe_int  = 3'b001
    ,e_pipe_mul  = 3'b010
    ,e_pipe_mem  = 3'b011
    ,e_pipe_fp   = 3'b100
    ,e_pipe_idiv = 3'b101
    ,e_pipe_fdiv = 3'b110
} bp_be_pipe_e;

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
    e_result_from_alu       = 1'b0
    ,e_result_from_pc_plus4 = 1'b1
} bp_be_result_e;

/* This is a placeholders, full exception enumeration is TBD */
typedef enum bit[1:0]
{
    e_load_fault  = 2'b01
    ,e_store_fault = 2'b10
    ,e_tlb_miss    = 2'b11
} bp_exception_code_e;

/* Declare width macros so that clients can use structs in ports before struct declaration */
`define bp_be_fu_op_width                                                                          \
    (`BSG_MAX($bits(bp_be_int_fu_op_e),$bits(bp_be_mem_fu_op_e)))

`define bp_be_decode_width                                                                         \
    (24*1+`bp_be_fu_op_width+3*RV64_reg_addr_width_gp+$bits(bp_be_src1_e)                          \
     +$bits(bp_be_src2_e)+$bits(bp_be_baddr_e)+$bits(bp_be_result_e))

`define bp_be_instr_metadata_width(branch_metadata_fwd_width_p)                                    \
    (bp_be_itag_width_gp+RV64_eaddr_width_gp+1+$bits(bp_fe_exception_code_e)                       \
     +branch_metadata_fwd_width_p)

`define bp_be_fe_adapter_issue_width(branch_metadata_fwd_width_p)                                  \
    (`bp_be_instr_metadata_width(branch_metadata_fwd_width_p)+RV64_instr_width_gp                  \
     +4*1+2*RV64_reg_addr_width_gp+RV64_reg_data_width_gp)

`define bp_be_chk_npc_status_width(branch_metadata_fwd_width_p)                                    \
    (1+RV64_eaddr_width_gp+branch_metadata_fwd_width_p+2*1)

`define bp_be_instr_operands_width                                                                 \
    (3*RV64_reg_data_width_gp)

`define bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)                                    \
    (`bp_be_instr_metadata_width(branch_metadata_fwd_width_p)+RV64_instr_width_gp                  \
     +`bp_be_instr_operands_width+`bp_be_decode_width)

`define bp_be_haz_status_width                                                                     \
    (5*1+RV64_reg_addr_width_gp)

`define bp_be_calc_status_width(branch_metadata_fwd_width_p)                                       \
    (1+RV64_eaddr_width_gp+2*1+RV64_reg_addr_width_gp+2*1+RV64_reg_addr_width_gp+1                 \
     +RV64_eaddr_width_gp+branch_metadata_fwd_width_p+2*1                                          \
     +5*`bp_be_haz_status_width+1+RV64_eaddr_width_gp+4*1)

`define bp_be_calc_result_width(branch_metadata_fwd_width_p)                                       \
    (2*RV64_reg_data_width_gp)

`define bp_be_exception_width                                                                      \
    (7*1)

`define bp_be_mmu_cmd_width                                                                        \
    (`bp_be_fu_op_width+RV64_eaddr_width_gp+RV64_reg_data_width_gp)

`define bp_be_mmu_resp_width                                                                       \
    (RV64_reg_data_width_gp+`bp_be_exception_width)

`define bp_be_instr_width                                                                          \
    (RV64_funct7_width_gp+RV64_reg_addr_width_gp+RV64_reg_addr_width_gp+RV64_funct3_width_gp       \
     +RV64_reg_addr_width_gp+RV64_opcode_width_gp)

`endif

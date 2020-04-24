/*
 * bp_cce_inst.h
 *
 * This file defines the CCE microcode instruction struct and the various fields within in.
 *
 */


#ifndef BP_CCE_INST_H
#define BP_CCE_INST_H

#include "bp_common_me_if.h"

/*
 * Instruction width definitions
 */

// Instructions are 32-bits wide with 2 bits of attached metadata
// cce_instr_width_p should be equal to 34, and used when passing instruction+metadata
#define bp_cce_inst_data_width 32
#define bp_cce_inst_metadata_width 2
#define bp_cce_inst_op_width 3
#define bp_cce_inst_minor_op_width 4

// Microcode RAM address width
// 9 bits allows up to 512 instructions
// this must be greater or equal to cce_pc_width_p in bp_common_aviary_pkg
#define bp_cce_inst_addr_width 9

// Immediate field widths
#define bp_cce_inst_imm1_width 1
#define bp_cce_inst_imm2_width 2
#define bp_cce_inst_imm4_width 4
#define bp_cce_inst_imm8_width 8
#define bp_cce_inst_imm16_width 16

/*
 * General Purpose Registers
 *
 * Note: number of GPRs must be less than or equal to the number that can be
 * represented in the GPR operand enum. Currently, the maximum is 16 GPRs, but only
 * 8 are actually implemented and used.
 */

#define bp_cce_inst_num_gpr 8
// Note: this is hard-coded so it can be used in part-select / bit-slicing expressions
#define bp_cce_inst_gpr_sel_width 3
//`BSG_SAFE_CLOG2(`bp_cce_inst_num_gpr)
#define bp_cce_inst_gpr_width 64

/*
 * Major Op Codes
 */

typedef enum {
  e_op_alu                               = 0x0    // ALU operation
  ,e_op_branch                           = 0x1    // Branch (control flow) operation
  ,e_op_reg_data                         = 0x2    // Register data movement operation
  ,e_op_mem                              = 0x3    // Memory data operation (not implemented)
  ,e_op_flag                             = 0x4
  ,e_op_dir                              = 0x5
  ,e_op_queue                            = 0x6
  ,e_op_unused                           = 0x7
} bp_cce_inst_op_e;

/*
 * Minor Op Codes
 */

// Minor ALU Op Codes
typedef enum {
  e_add_op                               = 0x0   // Add
  ,e_sub_op                              = 0x1   // Subtract
  ,e_lsh_op                              = 0x2   // Left Shift
  ,e_rsh_op                              = 0x3   // Right Shift
  ,e_and_op                              = 0x4   // Bit-wise AND
  ,e_or_op                               = 0x5   // Bit-wise OR
  ,e_xor_op                              = 0x6   // Bit-wise XOR
  ,e_neg_op                              = 0x7   // Bit-wise negation (unary)
  ,e_addi_op                             = 0x8   // Add immediate
  ,e_nop_op                              = 0x8   // Null Operation (r0 = r0 + 0)
  ,e_inc_op                              = 0x8   // Increment register by 1
  ,e_subi_op                             = 0x9   // Subtract immediate
  ,e_dec_op                              = 0x9   // Decrement register by 1
  ,e_lshi_op                             = 0xA   // Left Shift immediate
  ,e_rshi_op                             = 0xB   // Right Shift immediate
  ,e_not_op                              = 0xF   // Logical Not

// Minor Branch Op Codes
  ,e_beq_op                              = 0x0   // Branch if A == B
  ,e_bi_op                               = 0x0   // Unconditional Branch, or Branch if A == A
  ,e_bne_op                              = 0x1   // Branch if A != B
  ,e_blt_op                              = 0x2   // Branch if A < B
  ,e_bgt_op                              = 0x2   // Branch if A > B, or B < A
  ,e_ble_op                              = 0x3   // Branch if A <= B
  ,e_bge_op                              = 0x3   // Branch if A >= B, or B <= A

  ,e_bs_op                               = 0x4   // Branch if special == GPR
  ,e_bss_op                              = 0x5   // Branch if special == special

  ,e_beqi_op                             = 0x8   // Branch if A == immediate
  ,e_bz_op                               = 0x8   // Branch if A == 0
  ,e_bneqi_op                            = 0x9   // Branch if A != immediate
  ,e_bnz_op                              = 0x9   // Branch if A != 0

  ,e_bsi_op                              = 0xC   // Branch if special == immediate

// Minor Register Data Movement Op Codes
  ,e_mov_op                              = 0x0   // Move GPR to GPR
  ,e_movsg_op                            = 0x1   // Move Special Register to GPR
  ,e_movgs_op                            = 0x2   // Move GPR to Special Register
  ,e_ld_flags_op                         = 0x2   // MSHR.flags = GPR[0+:num_flags]
  ,e_movfg_op                            = 0x3   // Move Flag to GPR[0]
  ,e_movgf_op                            = 0x4   // Move GPR[0] to Flag
  ,e_movpg_op                            = 0x5   // Move Param to GPR
  ,e_movgp_op                            = 0x6   // Move GPR to Param
  ,e_movi_op                             = 0x8   // Move Immediate to GPR
  ,e_movis_op                            = 0x9   // Move Immediate to Special Register
  ,e_ld_flags_i_op                       = 0x9   // MSHR.flags = imm[0+:num_flags]
  ,e_clf_op                              = 0x9   // MSHR.flags = 0
  ,e_movip_op                            = 0xA   // Move Immediate to Param Register
  ,e_clm_op                              = 0xF   // Clear MSHR register

// Minor Memory Op Codes
// Note: these are not implemented in the CCE by default. In software, the e_m* operations
// operate on global memory (i.e., physical/main memory in the system). There is a bit
// in the instruction encoding to indicate local (i.e., CCE scratchpad) or global memory
// operation.
  ,e_ldb_op                              = 0x0   // Load byte from memory
  ,e_ldh_op                              = 0x1   // Load half-word from memory
  ,e_ldw_op                              = 0x2   // Load word from memory
  ,e_ldd_op                              = 0x3   // Load double-word from memory
  ,e_stb_op                              = 0x4   // Store byte to memory
  ,e_sth_op                              = 0x5   // Store half-word to memory
  ,e_stw_op                              = 0x6   // Store word to memory
  ,e_std_op                              = 0x7   // Store double-word to memory

// Minor Flag Op Codes
  ,e_sf_op                               = 0x0   // Move imm[0] = 1 to flag
  ,e_sfz_op                              = 0x0   // Move imm[0] = 0 to flag
  ,e_andf_op                             = 0x1   // Logical AND two flags to GPR
  ,e_orf_op                              = 0x2   // Logical OR two flags to GPR
  ,e_nandf_op                            = 0x3   // Logical AND two flags to GPR
  ,e_norf_op                             = 0x4   // Logical OR two flags to GPR
  ,e_notf_op                             = 0x5   // Logical not of flag

  ,e_bf_op                               = 0x8   // Branch if (MSHR.Flags & mask) == mask
  ,e_bfz_op                              = 0x9   // Branch if (MSHR.Flags & mask) == 0
  ,e_bfnz_op                             = 0xA   // Branch if (MSHR.Flags & mask) != 0
  ,e_bfnot_op                            = 0xB   // Branch if (MSHR.Flags & mask) != mask

// Minor Directory Op Codes
  ,e_rdp_op                              = 0x0   // Read Pending Bit
  ,e_rdw_op                              = 0x1   // Read Directory Way Group
  ,e_rde_op                              = 0x2   // Read Directory Entry
  ,e_wdp_op                              = 0x4   // Write Pending Bit
  ,e_clp_op                              = 0x5   // Clear Pending Bit
  ,e_clr_op                              = 0x6   // Clear Directory Row
  ,e_wde_op                              = 0x7   // Write Directory Entry
  ,e_wds_op                              = 0x8   // Write Directory Entry State
  ,e_gad_op                              = 0x9   // Generate Auxiliary Data

// Minor Queue Op Codes
// 1. poph does not dequeue data or memory, but captures the standard header fields into the MSHR,
//    and also captures the message type into the specified GPR.
// 2. popd dequeues a single 64-bit data packet into a single GPR. The user must first have at
//    at least done a poph to determine that data was available and so ucode can use msg_size
//    field in MSHR to determine how many packets to dequeue.
// 3. popq dequeues only the header. We assume that all data has been popped off
//    either by popd commands, or by the message unit auto-forward mechanism, or by issuing
//    a pushq command that consumes the data (e.g., an explicit pushq memCmd that consumes an
//    lceResp containing writeback data). No state is written from the message to the CCE.

  ,e_wfq_op                              = 0x0   // Wait for Queue Valid
  ,e_pushq_op                            = 0x1   // Push Queue
  ,e_pushqc_op                           = 0x1   // Push Queue Custom Message
  ,e_popq_op                             = 0x2   // Pop Queue - dequeue the header
  ,e_poph_op                             = 0x3   // Pop Header From Queue - does not pop message
  // TODO: popd not yet fully supported - will be supported after serdes changes
  ,e_popd_op                             = 0x4   // Pop Data From Queue
  ,e_specq_op                            = 0x5   // Write or read speculative access bits
  ,e_inv_op                              = 0x8   // Send all Invalidations based on sharers vector
} bp_cce_inst_minor_op_e;

/*
 * Speculative Bits Unit Operation
 */
typedef enum {
  e_spec_set                             = 0x0 // Set spec bit to 1
  ,e_spec_unset                          = 0x1 // Set spec bit to 0
  ,e_spec_squash                         = 0x2 // Set squash bit to 1, clear spec bit
  ,e_spec_fwd_mod                        = 0x3 // Set fwd_mod bit to 1, clear spec bit, set state to state
  ,e_spec_rd_spec                        = 0x8 // Read spec bit to sf
} bp_cce_inst_spec_op_e;

#define bp_cce_inst_spec_op_width 4

/*
 * Operand Selects
 */

#define bp_cce_inst_opd_width 4

typedef enum {
// GPR's can be source or destination
  e_opd_r0                               = 0x0
  ,e_opd_r1                              = 0x1
  ,e_opd_r2                              = 0x2
  ,e_opd_r3                              = 0x3
  ,e_opd_r4                              = 0x4
  ,e_opd_r5                              = 0x5
  ,e_opd_r6                              = 0x6
  ,e_opd_r7                              = 0x7

  ,e_opd_rqf                             = 0x0
  ,e_opd_ucf                             = 0x1
  ,e_opd_nerf                            = 0x2
  ,e_opd_nwbf                            = 0x3
  ,e_opd_pf                              = 0x4
  ,e_opd_sf                              = 0x5 // also not used, when would it be?
  // Basic flags from GAD
  // cached dirty == cmf | cof
  // cached maybe dirty == cmf | cof | cef
  // cached owned (transfer) == cef | cmf | cof | cff
  // cached == csf | cef | cmf | cof | cff
  // not cached == not(any c*f flag)
  // invalidate = rqf & csf
  ,e_opd_csf                             = 0x6
  ,e_opd_cef                             = 0x7
  ,e_opd_cmf                             = 0x8
  ,e_opd_cof                             = 0x9
  ,e_opd_cff                             = 0xA
  // special flags from GAD
  ,e_opd_rf                              = 0xB // requesting LCE needs replacement
  ,e_opd_uf                              = 0xC // rqf & (rsf | rof | rff)
  // 1101 - unused
  // 1110 - unused
  // 1111 - unused

  ,e_opd_req_lce                         = 0x0 // MSHR.lce_id
  ,e_opd_req_addr                        = 0x1 // MSHR.paddr
  ,e_opd_req_way                         = 0x2 // MSHR.way_id
  ,e_opd_lru_addr                        = 0x3 // MSHR.lru_paddr
  ,e_opd_lru_way                         = 0x4 // MSHR.lru_way_id
  ,e_opd_owner_lce                       = 0x5 // MSHR.owner_lce_id
  ,e_opd_owner_way                       = 0x6 // MSHR.owner_way_id
  ,e_opd_next_coh_state                  = 0x7 // MSHR.next_coh_state
  ,e_opd_flags                           = 0x8 // MSHR.flags
  ,e_opd_msg_size                        = 0x9 // MSHR.msg_size
  ,e_opd_lru_coh_state                   = 0xA // MSHR.lru_coh_state

  // only used as a source
  ,e_opd_flags_and_mask                  = 0xC // MSHR.flags & imm[0+:num_flags]

  // sharers vectors require src_b to provide GPR rX containing index to use
  // These can only be used as source a, not as source b or destinations
  ,e_opd_sharers_hit                     = 0xD // sharers_hits[rX]
  ,e_opd_sharers_way                     = 0xE // sharers_ways[rX]
  ,e_opd_sharers_state                   = 0xF // sharers_states[rX]

  // These four parameters can only be sources
  ,e_opd_cce_id                          = 0x0 // ID of this CCE
  ,e_opd_num_lce                         = 0x1 // total number of LCE in system
  ,e_opd_num_cce                         = 0x2 // total number of CCE in system
  ,e_opd_num_wg                          = 0x3 // Number of WG managed by this CCE
  // The following can be source or destination
  ,e_opd_auto_fwd_msg                    = 0x4 // Message auto-forward control
  ,e_opd_coh_state_default               = 0x5 // Default for MSHR.next_coh_state

  ,e_opd_mem_resp_v                      = 0x0
  ,e_opd_lce_resp_v                      = 0x1
  ,e_opd_pending_v                       = 0x2
  ,e_opd_lce_req_v                       = 0x3
  ,e_opd_lce_resp_type                   = 0x4
  ,e_opd_mem_resp_type                   = 0x5
  ,e_opd_lce_resp_data                   = 0x6
  ,e_opd_mem_resp_data                   = 0x7
  ,e_opd_lce_req_data                    = 0x8

} bp_cce_inst_opd_e;

#define bp_cce_inst_opd_special_width 4
#define bp_cce_inst_opd_params_width 4
#define bp_cce_inst_opd_queue_width 4

// Control Flag one hot encoding
typedef enum {
  e_flag_rqf                    = 1 // request type flag
  ,e_flag_ucf                   = 2 // uncached request flag
  ,e_flag_nerf                  = 4 // non-exclusive request flag
  ,e_flag_nwbf                  = 8 // null writeback flag
  ,e_flag_pf                    = 16 // pending flag
  ,e_flag_sf                    = 32 // speculative flag
  ,e_flag_csf                   = 64 // cached S by other flag
  ,e_flag_cef                   = 128 // cached E by other flag
  ,e_flag_cmf                   = 256 // cached M by other flag
  ,e_flag_cof                   = 512 // cached O by other flag
  ,e_flag_cff                   = 1024 // cached F by other flag
  ,e_flag_rf                    = 2048 // replacement flag
  ,e_flag_uf                    = 4096 // upgrade flag
} bp_cce_inst_flag_onehot_e;

#define bp_cce_inst_num_flags 16

/*
 * MUX Controls
 *
 * These are used to pick where an address, LCE ID, or way ID are sourced from for
 * various instructions, including message and directory operations.
 */

// Address
typedef enum {
  e_mux_sel_addr_r0                      = 0x0
  ,e_mux_sel_addr_r1                     = 0x1
  ,e_mux_sel_addr_r2                     = 0x2
  ,e_mux_sel_addr_r3                     = 0x3
  ,e_mux_sel_addr_r4                     = 0x4
  ,e_mux_sel_addr_r5                     = 0x5
  ,e_mux_sel_addr_r6                     = 0x6
  ,e_mux_sel_addr_r7                     = 0x7
  ,e_mux_sel_addr_mshr_req               = 0x8
  ,e_mux_sel_addr_mshr_lru               = 0x9
  ,e_mux_sel_addr_lce_req                = 0xA
  ,e_mux_sel_addr_lce_resp               = 0xB
  ,e_mux_sel_addr_mem_resp               = 0xC
  ,e_mux_sel_addr_pending                = 0xD
  ,e_mux_sel_addr_0                      = 0xF // constant 0
} bp_cce_inst_mux_sel_addr_e;

#define bp_cce_inst_mux_sel_addr_width 4

// LCE ID
typedef enum {
  e_mux_sel_lce_r0                       = 0x0
  ,e_mux_sel_lce_r1                      = 0x1
  ,e_mux_sel_lce_r2                      = 0x2
  ,e_mux_sel_lce_r3                      = 0x3
  ,e_mux_sel_lce_r4                      = 0x4
  ,e_mux_sel_lce_r5                      = 0x5
  ,e_mux_sel_lce_r6                      = 0x6
  ,e_mux_sel_lce_r7                      = 0x7
  ,e_mux_sel_lce_mshr_req                = 0x8
  ,e_mux_sel_lce_mshr_owner              = 0x9
  ,e_mux_sel_lce_lce_req                 = 0xA
  ,e_mux_sel_lce_lce_resp                = 0xB
  ,e_mux_sel_lce_mem_resp                = 0xC
  ,e_mux_sel_lce_pending                 = 0xD
  ,e_mux_sel_lce_0                       = 0xF // constant 0
} bp_cce_inst_mux_sel_lce_e;

#define bp_cce_inst_mux_sel_lce_width 4

// Way
typedef enum {
  e_mux_sel_way_r0                       = 0x0
  ,e_mux_sel_way_r1                      = 0x1
  ,e_mux_sel_way_r2                      = 0x2
  ,e_mux_sel_way_r3                      = 0x3
  ,e_mux_sel_way_r4                      = 0x4
  ,e_mux_sel_way_r5                      = 0x5
  ,e_mux_sel_way_r6                      = 0x6
  ,e_mux_sel_way_r7                      = 0x7
  ,e_mux_sel_way_mshr_req                = 0x8
  ,e_mux_sel_way_mshr_owner              = 0x9
  ,e_mux_sel_way_mshr_lru                = 0xA
  ,e_mux_sel_way_sh_way                  = 0xC // Sharer's vector ways, indexed by src_a
  ,e_mux_sel_way_0                       = 0xF // constant 0
} bp_cce_inst_mux_sel_way_e;

#define bp_cce_inst_mux_sel_way_width 4

// Coherence State
// source select for directory coherence state input
typedef enum {
  e_mux_sel_coh_r0                       = 0x0
  ,e_mux_sel_coh_r1                      = 0x1
  ,e_mux_sel_coh_r2                      = 0x2
  ,e_mux_sel_coh_r3                      = 0x3
  ,e_mux_sel_coh_r4                      = 0x4
  ,e_mux_sel_coh_r5                      = 0x5
  ,e_mux_sel_coh_r6                      = 0x6
  ,e_mux_sel_coh_r7                      = 0x7
  ,e_mux_sel_coh_next_coh_state          = 0x8
  ,e_mux_sel_coh_lru_coh_state           = 0x9
  ,e_mux_sel_sharer_state                = 0xA // Sharer's vector states, indexed by src_a
  ,e_mux_sel_coh_inst_imm                = 0xF
} bp_cce_inst_mux_sel_coh_state_e;

#define bp_cce_inst_mux_sel_coh_state_width 4

/*
 * Source and Destination Queue Selects and One-hot masks
 */

// Source queue one hot
// order: {lceReq, lceResp, memResp, pending}
typedef enum {
  e_src_q_pending                        = 1
  ,e_src_q_mem_resp                      = 2
  ,e_src_q_lce_resp                      = 4
  ,e_src_q_lce_req                       = 8
} bp_cce_inst_src_q_e;

#define bp_cce_num_src_q 4

// Source queue select
typedef enum {
  e_src_q_sel_lce_req                    = 0x0
  ,e_src_q_sel_mem_resp                  = 0x1
  ,e_src_q_sel_pending                   = 0x2
  ,e_src_q_sel_lce_resp                  = 0x3
} bp_cce_inst_src_q_sel_e;

#define bp_cce_inst_src_q_sel_width 2

// Destination queue one hot
typedef enum {
  e_dst_q_lce_cmd                        = 1
  ,e_dst_q_mem_cmd                       = 2
} bp_cce_inst_dst_q_e;

#define bp_cce_num_dst_q 2

// Destination queue select
typedef enum {
  e_dst_q_sel_lce_cmd                    = 0x0
  ,e_dst_q_sel_mem_cmd                   = 0x1
} bp_cce_inst_dst_q_sel_e;

#define bp_cce_inst_dst_q_sel_width 2

/*
 * Instruction Struct Definitions
 *
 * Each instruction is 32-bits wide. There are also two metadata bits attached to each
 * instruction that indicate if the instruction is a branch and if the branch should
 * be predicted taken or not. The metadata bits enable the pre-decoder to quickly decide
 * what PC should be (speculatively) fetched next.
 *
 * Each instruction contains:
 *   op (3-bits)
 *   minor_op (4-bits)
 *   instruction type specific struct with padding (25-bits)
 *
 * Any changes made to this file must be reflected in the C version used by the assembler, and
 * in the assembler itself.
 *
 */

#define bp_cce_inst_type_u_width \
  (bp_cce_inst_data_width-bp_cce_inst_op_width-bp_cce_inst_minor_op_width)

/*
 * 2-Register Encoding
 *
 */

#define bp_cce_inst_rtype_pad (bp_cce_inst_type_u_width-bp_cce_inst_opd_width \
  -(2*bp_cce_inst_opd_width))

typedef struct {
  uint32_t                               pad : bp_cce_inst_rtype_pad;
  bp_cce_inst_opd_e                      src_b;
  bp_cce_inst_opd_e                      dst;
  bp_cce_inst_opd_e                      src_a;
} bp_cce_inst_rtype_s;

/*
 * Immediate Encoding
 *
 */

#define bp_cce_inst_itype_pad (bp_cce_inst_type_u_width-bp_cce_inst_opd_width \
  -bp_cce_inst_opd_width-bp_cce_inst_imm16_width)

typedef struct {
  uint16_t                               imm : bp_cce_inst_imm16_width;
  uint32_t                               pad : bp_cce_inst_itype_pad;
  bp_cce_inst_opd_e                      dst;
  bp_cce_inst_opd_e                      src_a;
} bp_cce_inst_itype_s;

/*
 * Memory Load Encoding (same as I-Type)
 * rd = mem[ra+imm]
 *
 * Src and dst can only be GPR
 */

// no padding needed

typedef struct {
  uint16_t                               imm : bp_cce_inst_imm16_width;
  uint8_t                                global_mem : 1;
  bp_cce_inst_opd_e                      dst : bp_cce_inst_opd_width;
  bp_cce_inst_opd_e                      src_a : bp_cce_inst_opd_width;
} bp_cce_inst_mltype_s;

/*
 * Memory Store Encoding (basically I-Type, but second source instead of destination)
 * mem[ra+imm] = rb
 *
 * Src and dst can only be GPR
 */

// no padding needed

typedef struct {
  uint16_t                               imm : bp_cce_inst_imm16_width;
  uint8_t                                global_mem : 1;
  bp_cce_inst_opd_e                      src_b : bp_cce_inst_opd_width;
  bp_cce_inst_opd_e                      src_a : bp_cce_inst_opd_width;
} bp_cce_inst_mstype_s;

/*
 * Branch Encoding
 *
 */

#define bp_cce_inst_btype_pad (bp_cce_inst_type_u_width-bp_cce_inst_imm4_width \
  -(2*bp_cce_inst_opd_width)-bp_cce_inst_addr_width)

typedef struct {
  uint16_t                               target : bp_cce_inst_addr_width;
  uint32_t                               pad : bp_cce_inst_btype_pad;
  bp_cce_inst_opd_e                      src_b;
  uint8_t                                pad4 : bp_cce_inst_imm4_width;
  bp_cce_inst_opd_e                      src_a;
} bp_cce_inst_btype_s;

/*
 * Branch-Immediate Encoding
 *
 */

#define bp_cce_inst_bitype_pad (bp_cce_inst_type_u_width-bp_cce_inst_opd_width \
  -bp_cce_inst_imm8_width-bp_cce_inst_addr_width)

typedef struct {
  uint16_t                               target : bp_cce_inst_addr_width;
  uint32_t                               pad : bp_cce_inst_bitype_pad;
  uint8_t                                imm : bp_cce_inst_imm8_width;
  bp_cce_inst_opd_e                      src_a;
} bp_cce_inst_bitype_s;

/*
 * Branch-Flag Encoding
 *
 */

// no padding, target and immediate occupy exactly 25 bits

typedef struct {
  uint16_t                               target : bp_cce_inst_addr_width;
  uint16_t                               imm : bp_cce_inst_imm16_width;
} bp_cce_inst_bftype_s;

/*
 * SpecQ Encoding (S-Type)
 *
 */

#define bp_cce_inst_stype_pad (bp_cce_inst_type_u_width-bp_cce_inst_spec_op_width \
  -bp_cce_inst_mux_sel_addr_width-bp_coh_bits-bp_cce_inst_opd_width)

typedef struct {
  uint32_t                               pad : bp_cce_inst_stype_pad;
  bp_coh_states_e                        state : bp_coh_bits;
  bp_cce_inst_mux_sel_addr_e             addr_sel : bp_cce_inst_mux_sel_addr_width;
  bp_cce_inst_opd_e                      dst : bp_cce_inst_opd_width;
  bp_cce_inst_spec_op_e                  cmd : bp_cce_inst_spec_op_width;
} bp_cce_inst_stype_s;

/*
 * Directory Pending Encoding (DP-Type)
 *
 */

#define bp_cce_inst_dptype_pad (bp_cce_inst_type_u_width-bp_cce_inst_mux_sel_addr_width \
  -bp_cce_inst_opd_width-1)

typedef struct {
  uint32_t                               pad : bp_cce_inst_dptype_pad;
  uint8_t                                pending : 1;
  bp_cce_inst_opd_e                      dst : bp_cce_inst_opd_width;
  bp_cce_inst_mux_sel_addr_e             addr_sel : bp_cce_inst_mux_sel_addr_width;
} bp_cce_inst_dptype_s;

/*
 * Directory Read Encoding (DR-Type)
 *
 */

#define bp_cce_inst_drtype_pad (bp_cce_inst_type_u_width-bp_cce_inst_mux_sel_addr_width \
  -bp_cce_inst_mux_sel_lce_width-(2*bp_cce_inst_mux_sel_way_width) \
  -(2*bp_cce_inst_opd_width))

typedef struct {
  uint32_t                               pad : bp_cce_inst_drtype_pad;
  bp_cce_inst_opd_e                      src_a : bp_cce_inst_opd_width;
  bp_cce_inst_mux_sel_way_e              lru_way_sel : bp_cce_inst_mux_sel_way_width;
  bp_cce_inst_mux_sel_way_e              way_sel : bp_cce_inst_mux_sel_way_width;
  bp_cce_inst_mux_sel_lce_e              lce_sel : bp_cce_inst_mux_sel_lce_width;
  bp_cce_inst_opd_e                      dst : bp_cce_inst_opd_width;
  bp_cce_inst_mux_sel_addr_e             addr_sel : bp_cce_inst_mux_sel_addr_width;
} bp_cce_inst_drtype_s;

/*
 * Directory Write Encoding (DW-Type)
 *
 */

#define bp_cce_inst_dwtype_pad (bp_cce_inst_type_u_width-bp_cce_inst_mux_sel_addr_width \
  -bp_cce_inst_mux_sel_lce_width-bp_cce_inst_mux_sel_way_width \
  -bp_cce_inst_mux_sel_coh_state_width-bp_coh_bits-bp_cce_inst_opd_width)

typedef struct {
  uint32_t                               pad : bp_cce_inst_dwtype_pad;
  bp_cce_inst_opd_e                      src_a : bp_cce_inst_opd_width;
  bp_coh_states_e                        state : bp_coh_bits;
  bp_cce_inst_mux_sel_way_e              way_sel : bp_cce_inst_mux_sel_way_width;
  bp_cce_inst_mux_sel_lce_e              lce_sel : bp_cce_inst_mux_sel_lce_width;
  bp_cce_inst_mux_sel_coh_state_e        state_sel : bp_cce_inst_mux_sel_coh_state_width;
  bp_cce_inst_mux_sel_addr_e             addr_sel : bp_cce_inst_mux_sel_addr_width;
} bp_cce_inst_dwtype_s;

/*
 * Pop Queue Encoding
 *
 */

#define bp_cce_inst_popq_pad (bp_cce_inst_type_u_width-bp_cce_inst_src_q_sel_width \
  -bp_cce_inst_opd_width-bp_cce_inst_imm2_width-1)

typedef struct {
  uint8_t                                write_pending : 1;
  uint32_t                               pad : bp_cce_inst_popq_pad;
  bp_cce_inst_opd_e                      dst : bp_cce_inst_opd_width;
  uint8_t                                pad2 : bp_cce_inst_imm2_width;
  bp_cce_inst_src_q_sel_e                src_q : bp_cce_inst_src_q_sel_width;
} bp_cce_inst_popq_s;

/*
 * Push Queue Encoding
 *
 */

// no padding, all bits used

typedef union {
  bp_cce_inst_mux_sel_way_e     way_sel : bp_cce_inst_mux_sel_way_width;
  bp_mem_msg_size_e             msg_size : bp_mem_msg_size_width;
} pushq_way_or_size_u;

typedef union {
  bp_lce_cmd_type_e      lce_cmd : bp_lce_cmd_type_width;
  bp_cce_mem_cmd_type_e  mem_cmd : bp_cce_mem_cmd_type_width;
} pushq_cmd_u;

typedef struct {
  uint8_t                                write_pending : 1;
  pushq_way_or_size_u                    way_or_size;
  bp_cce_inst_opd_e                      src_a : bp_cce_inst_opd_width;
  bp_cce_inst_mux_sel_lce_e              lce_sel : bp_cce_inst_mux_sel_lce_width;
  bp_cce_inst_mux_sel_addr_e             addr_sel : bp_cce_inst_mux_sel_addr_width;
  pushq_cmd_u                            cmd;
  uint8_t                                spec : 1;
  uint8_t                                custom : 1;
  bp_cce_inst_dst_q_sel_e                dst_q : bp_cce_inst_dst_q_sel_width;
} bp_cce_inst_pushq_s;

/*
 * Instruction Type Struct Union
 */

typedef union {
  bp_cce_inst_rtype_s                    rtype;
  bp_cce_inst_itype_s                    itype;
  bp_cce_inst_mltype_s                   mltype;
  bp_cce_inst_mstype_s                   mstype;
  bp_cce_inst_btype_s                    btype;
  bp_cce_inst_bitype_s                   bitype;
  bp_cce_inst_bftype_s                   bftype;
  bp_cce_inst_stype_s                    stype;
  bp_cce_inst_dptype_s                   dptype;
  bp_cce_inst_dwtype_s                   dwtype;
  bp_cce_inst_drtype_s                   drtype;
  bp_cce_inst_popq_s                     popq;
  bp_cce_inst_pushq_s                    pushq;
} bp_cce_inst_type_u;

typedef enum {
  e_rtype
  ,e_itype
  ,e_mltype
  ,e_mstype
  ,e_btype
  ,e_bitype
  ,e_bftype
  ,e_stype
  ,e_dptype
  ,e_dwtype
  ,e_drtype
  ,e_popq
  ,e_pushq
} bp_cce_inst_type_e;

typedef struct {
  uint8_t                                predict_taken : 1;
  uint8_t                                branch : 1;
  bp_cce_inst_type_u                     type_u;
  bp_cce_inst_minor_op_e                 minor_op;
  bp_cce_inst_op_e                       op : bp_cce_inst_op_width;
} bp_cce_inst_s;

#define bp_cce_inst_s_width (bp_cce_inst_data_width+2)

#endif

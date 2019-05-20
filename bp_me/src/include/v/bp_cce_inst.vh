/**
 *
 * Name:
 *   bp_cce_inst.vh
 *
 * Description:
 *   This file describes the CCE microcode instructions. Any changes made to this file must be
 *   reflected in the source code of the CCE microcode assembler, too.
 *
 *   This file defines both the assembler generated and internally decoded formats of the microcode.
 *
 *   Some software operations are supported via assembler transforms rather than being supported
 *   directly in hardware (e.g., ALU increment and decrement).
 *
 * Notes:
 *   Some operations that a programmer can specify in the CCE microcode program are not directly
 *   supported in hardware. These operations are translated into hardware microcode ops by the
 *   assembler. These operations are shown as comments below the op and minor op enums below.
 *
 */

`ifndef BP_CCE_INST_VH
`define BP_CCE_INST_VH

// Major Op Codes
typedef enum logic [2:0] {
  e_op_alu                               = 3'b000
  ,e_op_branch                           = 3'b001
  ,e_op_move                             = 3'b010
  ,e_op_flag                             = 3'b011
  ,e_op_read_dir                         = 3'b100
  ,e_op_write_dir                        = 3'b101
  ,e_op_misc                             = 3'b110
  ,e_op_queue                            = 3'b111
} bp_cce_inst_op_e;

`define bp_cce_inst_op_width $bits(bp_cce_inst_op_e)

// Minor ALU Op Codes
// Add, Subtract
typedef enum logic [2:0] {
  e_add_op                               = 3'b000   // Add
  ,e_sub_op                              = 3'b001   // Subtract
  ,e_lsh_op                              = 3'b010   // Left Shift
  ,e_rsh_op                              = 3'b011   // Right Shift
  ,e_and_op                              = 3'b100   // Bit-wise AND
  ,e_or_op                               = 3'b101   // Bit-wise OR
  ,e_xor_op                              = 3'b110   // Bit-wise XOR
  ,e_neg_op                              = 3'b111   // Bit-wise negation (unary)
} bp_cce_inst_minor_alu_op_e;

// Software supported ALU operations
// Increment by 1 // same as ADD, src_b = 1, dst = src_a
//,e_inc_op                              = 3'b000
// Decrement by 1 // same as DEC, src_b = 1, dst = src_a
//,e_dec_op                              = 3'b001

// Minor Branch Op Codes
typedef enum logic [2:0] {
  e_bi_op                                = 3'b111   // Branch Immediate (Unconditional)

  ,e_beq_op                              = 3'b010   // Branch if A == B
  ,e_bne_op                              = 3'b011   // Branch if A != B

  ,e_blt_op                              = 3'b100   // Branch if A < B
  ,e_ble_op                              = 3'b101   // Branch if A <= B
} bp_cce_inst_minor_branch_op_e;

// Software supported branch operations
// Branch if A == 0 // same as BEQ, src_b = 0
//,e_bz_op                               = 3'b010
// Branch if A != 0 // same as BNE, src_b = 0
//,e_bnz_op                              = 3'b011
// Branch if Queue.ready == 1 // same as BEQ src_a = queue.ready, src_b = 1
//,e_bqr_op                              = 3'b010
// Branch if A > B // same as BLT, swap src_a and src_b
//,e_bgt_op                              = 3'b100
// Branch if A >= B // same as BLE, swap src_a and src_b
//,e_bge_op                              = 3'b101
// Branch if Flag == 1 or 0
//,e_bf_op                               = 3'b010   // Branch if flag == 1
//,e_bfz_op                              = 3'b010   // Branch if flag == 0

// Minor Move Op Codes
typedef enum logic [2:0] {
  e_mov_op                               = 3'b000   // Move src_a to dst
  ,e_movi_op                             = 3'b001   // Move imm to dst
} bp_cce_inst_minor_mov_op_e;

// Minor Set Flag Op Codes
typedef enum logic [2:0] {
  e_sf_op                                = 3'b001   // Move imm[0] = 1 to dst(flag)
} bp_cce_inst_minor_flag_op_e;

// Software supported flag operations
// Move imm[1] = 0 to dst(flag)
//,e_sfz_op                              = 3'b001

// Minor Read Directory Op Codes
typedef enum logic [2:0] {
  e_rdp_op                               = 3'b000   // Read Directory Pending Bit
  ,e_rdw_op                              = 3'b001   // Read Directory Way Group
  ,e_rde_op                              = 3'b010   // Read Directory Entry
} bp_cce_inst_minor_read_dir_op_e;

// Minor Write Directory Op Codes
typedef enum logic [2:0] {
  e_wdp_op                               = 3'b000   // Write Directory Pending Bit
  ,e_wde_op                              = 3'b001   // Write Directory Entry
  ,e_wds_op                              = 3'b010   // Write Directory Entry State
} bp_cce_inst_minor_write_dir_op_e;

// Minor Misc Op Codes
typedef enum logic [2:0] {
  e_gad_op                               = 3'b000   // Generate Auxiliary Data
  ,e_stall_op                            = 3'b111   // Stall PC
} bp_cce_inst_minor_misc_op_e;

// Minor Queue Op Codes
typedef enum logic [2:0] {
  e_wfq_op                               = 3'b000   // Wait for Queue Ready
  ,e_pushq_op                            = 3'b001   // Push Queue
  ,e_popq_op                             = 3'b010   // Pop Queue
  ,e_poph_op                             = 3'b011   // Pop Header From Queue - does not pop message
} bp_cce_inst_minor_queue_op_e;

// Minor Op Code Union
typedef union packed {
  bp_cce_inst_minor_alu_op_e             alu_minor_op;
  bp_cce_inst_minor_branch_op_e          branch_minor_op;
  bp_cce_inst_minor_mov_op_e             mov_minor_op;
  bp_cce_inst_minor_flag_op_e            flag_minor_op;
  bp_cce_inst_minor_read_dir_op_e        read_dir_minor_op;
  bp_cce_inst_minor_write_dir_op_e       write_dir_minor_op;
  bp_cce_inst_minor_misc_op_e            misc_minor_op;
  bp_cce_inst_minor_queue_op_e           queue_minor_op;
} bp_cce_inst_minor_op_u;

`define bp_cce_inst_minor_op_width $bits(bp_cce_inst_minor_op_u)

// Source Select
typedef enum logic [4:0] {
  e_src_r0                               = 5'b00000
  ,e_src_r1                              = 5'b00001
  ,e_src_r2                              = 5'b00010
  ,e_src_r3                              = 5'b00011

  ,e_src_rqf                             = 5'b00100
  ,e_src_nerf                            = 5'b00101
  ,e_src_ldf                             = 5'b00110
  ,e_src_nwbf                            = 5'b00111
  ,e_src_tf                              = 5'b01000
  ,e_src_rf                              = 5'b01001
  ,e_src_rwbf                            = 5'b01010
  ,e_src_pf                              = 5'b01011
  ,e_src_uf                              = 5'b01100
  ,e_src_if                              = 5'b01101
  ,e_src_ef                              = 5'b01110
  ,e_src_pcf                             = 5'b01111
  ,e_src_ucf                             = 5'b10000

  ,e_src_const_0                         = 5'b10001
  ,e_src_const_1                         = 5'b10010
  ,e_src_imm                             = 5'b10011
  ,e_src_req_lce                         = 5'b10100
  ,e_src_ack_type                        = 5'b10101
  ,e_src_sharers_hit_r0                  = 5'b10110
  ,e_src_cce_id                          = 5'b10111

  ,e_src_lce_req_ready                   = 5'b11000
  ,e_src_mem_resp_ready                  = 5'b11001
  ,e_src_mem_data_resp_ready             = 5'b11010
  ,e_src_pending_ready                   = 5'b11011
  ,e_src_lce_resp_ready                  = 5'b11100
  ,e_src_lce_data_resp_ready             = 5'b11101

  ,e_src_cf                              = 5'b11110
} bp_cce_inst_src_e;

`define bp_cce_inst_src_width $bits(bp_cce_inst_src_e)

// Destination Select
typedef enum logic [4:0] {
  e_dst_r0                               = 5'b00000
  ,e_dst_r1                              = 5'b00001
  ,e_dst_r2                              = 5'b00010
  ,e_dst_r3                              = 5'b00011

  ,e_dst_rqf                             = 5'b00100
  ,e_dst_nerf                            = 5'b00101
  ,e_dst_ldf                             = 5'b00110
  ,e_dst_nwbf                            = 5'b00111
  ,e_dst_tf                              = 5'b01000
  ,e_dst_rf                              = 5'b01001
  ,e_dst_rwbf                            = 5'b01010
  ,e_dst_pf                              = 5'b01011
  ,e_dst_uf                              = 5'b01100
  ,e_dst_if                              = 5'b01101
  ,e_dst_ef                              = 5'b01110
  ,e_dst_pcf                             = 5'b01111
  ,e_dst_ucf                             = 5'b10000
  ,e_dst_cf                              = 5'b10001

  ,e_dst_next_coh_state                  = 5'b10010
} bp_cce_inst_dst_e;

`define bp_cce_inst_dst_width $bits(bp_cce_inst_dst_e)

// Flag register index select
typedef enum logic [3:0] {
  e_flag_sel_rqf                         = 4'b0000 // request type flag
  ,e_flag_sel_nerf                       = 4'b0001 // non-exclusive request flag
  ,e_flag_sel_ldf                        = 4'b0010 // lru dirty flag
  ,e_flag_sel_nwbf                       = 4'b0011 // null writeback flag
  ,e_flag_sel_tf                         = 4'b0100 // transfer flag
  ,e_flag_sel_rf                         = 4'b0101 // replacement flag
  ,e_flag_sel_rwbf                       = 4'b0110 // replacement writeback flag
  ,e_flag_sel_pf                         = 4'b0111 // pending flag
  ,e_flag_sel_uf                         = 4'b1000 // upgrade flag
  ,e_flag_sel_if                         = 4'b1001 // invalidate flag
  ,e_flag_sel_ef                         = 4'b1010 // exclusive flag
  ,e_flag_sel_pcf                        = 4'b1011 // pending-cleared flag
  ,e_flag_sel_ucf                        = 4'b1100 // uncached request flag
  ,e_flag_sel_cf                         = 4'b1101 // cached flag
  // unused 4'b1110
  // unused 4'b1111
} bp_cce_inst_flag_sel_e;

`define bp_cce_inst_flag_sel_width $bits(bp_cce_inst_flag_sel_e)

// Flag register one hot
typedef enum logic [13:0] {
  e_flag_rqf                             = 14'b00_0000_0000_0001 // request type flag
  ,e_flag_nerf                           = 14'b00_0000_0000_0010 // non-exclusive request flag
  ,e_flag_ldf                            = 14'b00_0000_0000_0100 // lru dirty flag
  ,e_flag_nwbf                           = 14'b00_0000_0000_1000 // null writeback flag
  ,e_flag_tf                             = 14'b00_0000_0001_0000 // transfer flag
  ,e_flag_rf                             = 14'b00_0000_0010_0000 // replacement flag
  ,e_flag_rwbf                           = 14'b00_0000_0100_0000 // replacement writeback flag
  ,e_flag_pf                             = 14'b00_0000_1000_0000 // pending flag
  ,e_flag_uf                             = 14'b00_0001_0000_0000 // upgrade flag
  ,e_flag_if                             = 14'b00_0010_0000_0000 // invalidate flag
  ,e_flag_ef                             = 14'b00_0100_0000_0000 // exclusive flag
  ,e_flag_pcf                            = 14'b00_1000_0000_0000 // pending-cleared flag
  ,e_flag_ucf                            = 14'b01_0000_0000_0000 // uncached request flag
  ,e_flag_cf                             = 14'b10_0000_0000_0000 // cached flag
} bp_cce_inst_flag_e;

`define bp_cce_inst_num_flags $bits(bp_cce_inst_flag_e)

// source select for directory way group input
typedef enum logic [2:0] {
  e_dir_wg_sel_r0                        = 3'b000
  ,e_dir_wg_sel_r1                       = 3'b001
  ,e_dir_wg_sel_r2                       = 3'b010
  ,e_dir_wg_sel_r3                       = 3'b011
  ,e_dir_wg_sel_req_addr                 = 3'b100
  ,e_dir_wg_sel_lru_way_addr             = 3'b101
} bp_cce_inst_dir_way_group_sel_e;

`define bp_cce_inst_dir_way_group_sel_width $bits(bp_cce_inst_dir_way_group_sel_e)

// source select for directory lce input
typedef enum logic [2:0] {
  e_dir_lce_sel_r0                       = 3'b000
  ,e_dir_lce_sel_r1                      = 3'b001
  ,e_dir_lce_sel_r2                      = 3'b010
  ,e_dir_lce_sel_r3                      = 3'b011
  ,e_dir_lce_sel_req_lce                 = 3'b100
  ,e_dir_lce_sel_transfer_lce            = 3'b101
} bp_cce_inst_dir_lce_sel_e;

`define bp_cce_inst_dir_lce_sel_width $bits(bp_cce_inst_dir_lce_sel_e)

// source select for directory way input
typedef enum logic [2:0] {
  e_dir_way_sel_r0                       = 3'b000
  ,e_dir_way_sel_r1                      = 3'b001
  ,e_dir_way_sel_r2                      = 3'b010
  ,e_dir_way_sel_r3                      = 3'b011
  ,e_dir_way_sel_req_addr_way            = 3'b100
  ,e_dir_way_sel_lru_way_addr_way        = 3'b101
  ,e_dir_way_sel_sh_way_r0               = 3'b110
} bp_cce_inst_dir_way_sel_e;

`define bp_cce_inst_dir_way_sel_width $bits(bp_cce_inst_dir_way_sel_e)

// source select for directory coherence state input
typedef enum logic {
  e_dir_coh_sel_next_coh_st              = 1'b0
  ,e_dir_coh_sel_inst_imm                = 1'b1
} bp_cce_inst_dir_coh_state_sel_e;

`define bp_cce_inst_dir_coh_state_sel_width $bits(bp_cce_inst_dir_coh_state_sel_e)

// source select for directory tag input
typedef enum logic [1:0] {
  e_dir_tag_sel_req_addr                 = 2'b00
  ,e_dir_tag_sel_lru_way_addr            = 2'b01
  ,e_dir_tag_sel_const_0                 = 2'b10
} bp_cce_inst_dir_tag_sel_e;

`define bp_cce_inst_dir_tag_sel_width $bits(bp_cce_inst_dir_tag_sel_e)


// Source queue one hot
// order: {lceReq, lceResp, lceDataResp, memResp, memDataResp, pending}
typedef enum logic [5:0] {
  e_src_q_pending                        = 6'b00_0001
  ,e_src_q_mem_data_resp                 = 6'b00_0010
  ,e_src_q_mem_resp                      = 6'b00_0100
  ,e_src_q_lce_data_resp                 = 6'b00_1000
  ,e_src_q_lce_resp                      = 6'b01_0000
  ,e_src_q_lce_req                       = 6'b10_0000
} bp_cce_inst_src_q_e;

`define bp_cce_num_src_q $bits(bp_cce_inst_src_q_e)

// Source queue select
typedef enum logic [2:0] {
  e_src_q_sel_lce_req                    = 3'b000
  ,e_src_q_sel_mem_resp                  = 3'b001
  ,e_src_q_sel_mem_data_resp             = 3'b010
  ,e_src_q_sel_pending                   = 3'b011
  ,e_src_q_sel_lce_resp                  = 3'b100
  ,e_src_q_sel_lce_data_resp             = 3'b101
} bp_cce_inst_src_q_sel_e;

`define bp_cce_inst_src_q_sel_width $bits(bp_cce_inst_src_q_sel_e)

// Destination queue select
typedef enum logic [1:0] {
  e_dst_q_lce_cmd                        = 2'b00
  ,e_dst_q_lce_data_cmd                  = 2'b01
  ,e_dst_q_mem_cmd                       = 2'b10
  ,e_dst_q_mem_data_cmd                  = 2'b11
} bp_cce_inst_dst_q_sel_e;

`define bp_cce_inst_dst_q_sel_width $bits(bp_cce_inst_dst_q_sel_e)

// LCE cmd lce_id source select
typedef enum logic [2:0] {
  e_lce_cmd_lce_r0                       = 3'b000
  ,e_lce_cmd_lce_r1                      = 3'b001
  ,e_lce_cmd_lce_r2                      = 3'b010
  ,e_lce_cmd_lce_r3                      = 3'b011
  ,e_lce_cmd_lce_req_lce                 = 3'b100
  ,e_lce_cmd_lce_tr_lce                  = 3'b101
  ,e_lce_cmd_lce_0                       = 3'b110
} bp_cce_inst_lce_cmd_lce_sel_e;

`define bp_cce_inst_lce_cmd_lce_sel_width $bits(bp_cce_inst_lce_cmd_lce_sel_e)

// LCE cmd addr source select
typedef enum logic [2:0] {
  e_lce_cmd_addr_r0                      = 3'b000
  ,e_lce_cmd_addr_r1                     = 3'b001
  ,e_lce_cmd_addr_r2                     = 3'b010
  ,e_lce_cmd_addr_r3                     = 3'b011
  ,e_lce_cmd_addr_req_addr               = 3'b100
  ,e_lce_cmd_addr_lru_way_addr           = 3'b101
  ,e_lce_cmd_addr_0                      = 3'b110
} bp_cce_inst_lce_cmd_addr_sel_e;

`define bp_cce_inst_lce_cmd_addr_sel_width $bits(bp_cce_inst_lce_cmd_addr_sel_e)

// LCE cmd way source select
typedef enum logic [2:0] {
  e_lce_cmd_way_req_addr_way             = 3'b000
  ,e_lce_cmd_way_tr_addr_way             = 3'b001
  ,e_lce_cmd_way_sh_list_r0              = 3'b010
  ,e_lce_cmd_way_lru_addr_way            = 3'b011
  ,e_lce_cmd_way_0                       = 3'b100
} bp_cce_inst_lce_cmd_way_sel_e;

`define bp_cce_inst_lce_cmd_way_sel_width $bits(bp_cce_inst_lce_cmd_way_sel_e)

// Mem Data cmd addr source select
typedef enum logic {
  e_mem_data_cmd_addr_lru_way_addr       = 1'b0
  ,e_mem_data_cmd_addr_req_addr          = 1'b1
} bp_cce_inst_mem_data_cmd_addr_sel_e;

`define bp_cce_inst_mem_data_cmd_addr_sel_width $bits(bp_cce_inst_mem_data_cmd_addr_sel_e)

// GPR Numbers
typedef enum logic [1:0] {
  e_gpr_r0                               = 2'b00
  ,e_gpr_r1                              = 2'b01
  ,e_gpr_r2                              = 2'b10
  ,e_gpr_r3                              = 2'b11
} bp_cce_gpr_e;

// Note: number of gpr must be a power of 2
`define bp_cce_inst_num_gpr (2**$bits(bp_cce_gpr_e))
`define bp_cce_inst_gpr_width 16

// source select for reqlce and reqaddr registers writes
typedef enum logic [1:0] {
  e_req_sel_lce_req                      = 2'b00
  ,e_req_sel_mem_resp                    = 2'b01
  ,e_req_sel_mem_data_resp               = 2'b10
  ,e_req_sel_pending                     = 2'b11
} bp_cce_inst_req_sel_e;

`define bp_cce_inst_req_sel_width $bits(bp_cce_inst_req_sel_e)

// Source select for req_addr_way
typedef enum logic [1:0] {
  e_req_addr_way_sel_logic               = 2'b00
  ,e_req_addr_way_sel_mem_resp           = 2'b01
  ,e_req_addr_way_sel_mem_data_resp      = 2'b10
} bp_cce_inst_req_addr_way_sel_e;

`define bp_cce_inst_req_addr_way_sel_width $bits(bp_cce_inst_req_addr_way_sel_e)

// Source select for lru_way
typedef enum logic [1:0] {
  e_lru_way_sel_lce_req                  = 2'b00
  ,e_lru_way_sel_mem_resp                = 2'b01
  ,e_lru_way_sel_mem_data_resp           = 2'b10
  ,e_lru_way_sel_pending                 = 2'b11
} bp_cce_inst_lru_way_sel_e;

`define bp_cce_inst_lru_way_sel_width $bits(bp_cce_inst_lru_way_sel_e)

// source select for cache block data register writes
typedef enum logic {
  e_data_sel_lce_data_resp               = 1'b0
  ,e_data_sel_mem_data_resp              = 1'b1
} bp_cce_inst_cache_block_data_sel_e;

`define bp_cce_inst_dat_sel_width $bits(bp_cce_inst_cache_block_data_sel_e)

// source select for transfer lce register writes
typedef enum logic {
  e_tr_lce_sel_logic                     = 1'b0
  ,e_tr_lce_sel_mem_resp                 = 1'b1
} bp_cce_inst_transfer_lce_sel_e;

`define bp_cce_inst_transfer_lce_sel_width $bits(bp_cce_inst_transfer_lce_sel_e)

// RQF flag source select
typedef enum logic [2:0] {
  e_rqf_lce_req                          = 3'b000
  ,e_rqf_mem_resp                        = 3'b001
  ,e_rqf_mem_data_resp                   = 3'b010
  ,e_rqf_pending                         = 3'b011
  ,e_rqf_imm0                            = 3'b100
} bp_cce_inst_rq_flag_sel_e;

`define bp_cce_inst_rq_flag_sel_width $bits(bp_cce_inst_rq_flag_sel_e)

// NERF and LDF flag source select
typedef enum logic [1:0] {
  e_nerldf_lce_req                       = 2'b00
  ,e_nerldf_pending                      = 2'b01
  ,e_nerldf_imm0                         = 2'b10
} bp_cce_inst_ner_ld_flag_sel_e;

`define bp_cce_inst_ner_ld_flag_sel_width $bits(bp_cce_inst_ner_ld_flag_sel_e)

// NWBF flag source select
typedef enum logic {
  e_nwbf_lce_data_resp                   = 1'b0
  ,e_nwbf_imm0                           = 1'b1
} bp_cce_inst_nwb_flag_sel_e;

`define bp_cce_inst_nwb_flag_sel_width $bits(bp_cce_inst_nwb_flag_sel_e)

// RWBF flag source select
typedef enum logic {
  e_rwbf_mem_resp                        = 1'b0
  ,e_rwbf_imm0                           = 1'b1
} bp_cce_inst_rwb_flag_sel_e;

`define bp_cce_inst_rwb_flag_sel_width $bits(bp_cce_inst_rwb_flag_sel_e)

// TF flag source select
typedef enum logic [1:0] {
  e_tf_logic                             = 2'b00
  ,e_tf_mem_resp                         = 2'b01
  ,e_tf_imm0                             = 2'b10
} bp_cce_inst_t_flag_sel_e;

`define bp_cce_inst_t_flag_sel_width $bits(bp_cce_inst_t_flag_sel_e)

// PF, RF, UF, IF, EF flag source select
typedef enum logic {
  e_pruief_logic                         = 1'b0
  ,e_pruief_imm0                         = 1'b1
} bp_cce_inst_pruie_flag_sel_e;

`define bp_cce_inst_pruie_flag_sel_width $bits(bp_cce_inst_pruie_flag_sel_e)

// Instruction immediate fields
`define bp_cce_inst_imm16_width 16
`define bp_cce_inst_flag_imm_bit 0


/*
 * Instruction Struct Definitions
 *
 * Each instruction is capped at 48-bits (currently). The size is statically set to allow for
 * proper padding to be inserted into the instruction structs, which helps normalize the microcode
 * structs and formats.
 *
 * Each instruction contains:
 *   op (3-bits)
 *   minor_op (3-bits)
 *   instruction type specific struct with padding (42-bits)
 *
 * Any changes made to this file must be reflected in the C version used by the assembler, and
 * in the assembler itself.
 */

`define bp_cce_inst_width 48
`define bp_cce_inst_type_u_width \
  (`bp_cce_inst_width-`bp_cce_inst_op_width-`bp_cce_inst_minor_op_width)

/*
 * ALU Operation
 */

`define bp_cce_inst_alu_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dst_width \
  -(2*`bp_cce_inst_src_width)-`bp_cce_inst_imm16_width)

typedef struct packed {
  bp_cce_inst_dst_e                      dst;
  bp_cce_inst_src_e                      src_a;
  bp_cce_inst_src_e                      src_b;
  logic [`bp_cce_inst_imm16_width-1:0]   imm;
  logic [`bp_cce_inst_alu_pad-1:0]       pad;
} bp_cce_inst_alu_op_s;

/*
 * Branch Operation
 */

`define bp_cce_inst_branch_pad (`bp_cce_inst_type_u_width-(2*`bp_cce_inst_src_width) \
  -`bp_cce_inst_imm16_width)

typedef struct packed {
  bp_cce_inst_src_e                      src_a;
  bp_cce_inst_src_e                      src_b;
  logic [`bp_cce_inst_imm16_width-1:0]   target;
  logic [`bp_cce_inst_branch_pad-1:0]    pad;
} bp_cce_inst_branch_op_s;

/*
 * Move Operation
 */

`define bp_cce_inst_mov_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dst_width \
  -`bp_cce_inst_src_width-`bp_cce_inst_imm16_width)

typedef struct packed {
  bp_cce_inst_dst_e                      dst;
  bp_cce_inst_src_e                      src;
  logic [`bp_cce_inst_imm16_width-1:0]   imm;
  logic [`bp_cce_inst_mov_pad-1:0]       pad;
} bp_cce_inst_mov_op_s;

/*
 * Set Flag Operation
 *
 */

`define bp_cce_inst_flag_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dst_width-1)

typedef struct packed {
  bp_cce_inst_dst_e                      dst;
  logic                                  val;
  logic [`bp_cce_inst_flag_pad-1:0]      pad;
} bp_cce_inst_flag_op_s;

/*
 * Read Directory Operation
 */

`define bp_cce_inst_read_dir_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dir_way_group_sel_width \
  -`bp_cce_inst_dir_lce_sel_width-`bp_cce_inst_dir_way_sel_width)

typedef struct packed {
  bp_cce_inst_dir_way_group_sel_e        dir_way_group_sel;
  bp_cce_inst_dir_lce_sel_e              dir_lce_sel;
  bp_cce_inst_dir_way_sel_e              dir_way_sel;
  logic [`bp_cce_inst_read_dir_pad-1:0]  pad;
} bp_cce_inst_read_dir_op_s;

/*
 * Write Directory Operation
 */

`define bp_cce_inst_write_dir_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dir_way_group_sel_width \
  -`bp_cce_inst_dir_lce_sel_width-`bp_cce_inst_dir_way_sel_width \
  -`bp_cce_inst_dir_coh_state_sel_width-`bp_cce_inst_dir_tag_sel_width \
  -`bp_cce_coh_bits)

typedef struct packed {
  // directory inputs
  bp_cce_inst_dir_way_group_sel_e        dir_way_group_sel;
  bp_cce_inst_dir_lce_sel_e              dir_lce_sel;
  bp_cce_inst_dir_way_sel_e              dir_way_sel;
  bp_cce_inst_dir_coh_state_sel_e        dir_coh_state_sel;
  bp_cce_inst_dir_tag_sel_e              dir_tag_sel;
  logic [`bp_cce_coh_bits-1:0]           imm;
  logic [`bp_cce_inst_write_dir_pad-1:0] pad;
} bp_cce_inst_write_dir_op_s;

/*
 * Misc Operation
 *
 * Currently, Misc operations require nothing; the entire struct is padding
 */

typedef struct packed {
  logic [`bp_cce_inst_type_u_width-1:0]  pad;
} bp_cce_inst_misc_op_s;

/*
 * Queue Operation
 */

`define bp_cce_inst_pushq_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dst_q_sel_width \
  -`bp_cce_lce_cmd_type_width-`bp_cce_inst_lce_cmd_lce_sel_width \
  -`bp_cce_inst_lce_cmd_addr_sel_width-`bp_cce_inst_lce_cmd_way_sel_width \
  -`bp_cce_inst_mem_data_cmd_addr_sel_width)

typedef struct packed {
  bp_cce_inst_dst_q_sel_e                dst_q;
  bp_cce_lce_cmd_type_e                  cmd;
  // cce_lce_cmd_queue inputs
  bp_cce_inst_lce_cmd_lce_sel_e          lce_cmd_lce_sel;
  bp_cce_inst_lce_cmd_addr_sel_e         lce_cmd_addr_sel;
  bp_cce_inst_lce_cmd_way_sel_e          lce_cmd_way_sel;
  // mem_data_cmd_queue inputs
  bp_cce_inst_mem_data_cmd_addr_sel_e    mem_data_cmd_addr_sel;
  logic [`bp_cce_inst_pushq_pad-1:0]     pad;
} bp_cce_inst_pushq_s;

`define bp_cce_inst_popq_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_src_q_sel_width)

typedef struct packed {
  bp_cce_inst_src_q_sel_e                src_q;
  logic [`bp_cce_inst_popq_pad-1:0]      pad;
} bp_cce_inst_popq_s;

`define bp_cce_inst_wfq_pad (`bp_cce_inst_type_u_width-`bp_cce_num_src_q)

typedef struct packed {
  logic [`bp_cce_num_src_q-1:0]          qmask;
  logic [`bp_cce_inst_wfq_pad-1:0]       pad;
} bp_cce_inst_wfq_s;

typedef union packed {
  bp_cce_inst_pushq_s                    pushq;
  bp_cce_inst_popq_s                     popq;
  bp_cce_inst_wfq_s                      wfq;
} bp_cce_inst_queue_op_u;

typedef struct packed {
  bp_cce_inst_queue_op_u                 op;
} bp_cce_inst_queue_op_s;

/*
 * Instruction Type Struct Union
 */

typedef union packed {
  bp_cce_inst_alu_op_s                   alu_op_s;
  bp_cce_inst_branch_op_s                branch_op_s;
  bp_cce_inst_mov_op_s                   mov_op_s;
  bp_cce_inst_flag_op_s                  flag_op_s;
  bp_cce_inst_read_dir_op_s              read_dir_op_s;
  bp_cce_inst_write_dir_op_s             write_dir_op_s;
  bp_cce_inst_misc_op_s                  misc_op_s;
  bp_cce_inst_queue_op_s                 queue_op_s;
} bp_cce_inst_type_u;

typedef struct packed {
  bp_cce_inst_op_e                       op;
  bp_cce_inst_minor_op_u                 minor_op_u;
  bp_cce_inst_type_u                     type_u;
} bp_cce_inst_s;

`define bp_cce_inst_s_width $bits(bp_cce_inst_s)

/*
 * bp_cce_inst_decoded_s defines the decoded form of the CCE microcode instructions
 *
 */
typedef struct packed {

  bp_cce_inst_minor_op_u                   minor_op_u;
  bp_cce_inst_src_e                        src_a;
  bp_cce_inst_src_e                        src_b;
  bp_cce_inst_dst_e                        dst;
  logic [`bp_cce_inst_imm16_width-1:0]     imm;

  // alu valid in
  logic                                    alu_v;

  // Register source selects
  bp_cce_inst_req_sel_e                    req_sel;
  bp_cce_inst_req_addr_way_sel_e           req_addr_way_sel;
  bp_cce_inst_lru_way_sel_e                lru_way_sel;
  bp_cce_inst_transfer_lce_sel_e           transfer_lce_sel;
  bp_cce_inst_cache_block_data_sel_e       cache_block_data_sel;

  // Flag source selects
  bp_cce_inst_rq_flag_sel_e                rqf_sel;
  bp_cce_inst_ner_ld_flag_sel_e            nerldf_sel;
  bp_cce_inst_nwb_flag_sel_e               nwbf_sel;
  bp_cce_inst_t_flag_sel_e                 tf_sel;
  bp_cce_inst_pruie_flag_sel_e             pruief_sel;
  bp_cce_inst_rwb_flag_sel_e               rwbf_sel;

  // Directory source selects
  bp_cce_inst_dir_way_group_sel_e          dir_way_group_sel;
  bp_cce_inst_dir_lce_sel_e                dir_lce_sel;
  bp_cce_inst_dir_way_sel_e                dir_way_sel;
  bp_cce_inst_dir_coh_state_sel_e          dir_coh_state_sel;
  bp_cce_inst_dir_tag_sel_e                dir_tag_sel;
  // Directory inputs
  logic [`bp_cce_inst_minor_op_width-1:0]  dir_r_cmd;
  logic                                    dir_r_v;
  logic [`bp_cce_inst_minor_op_width-1:0]  dir_w_cmd;
  logic                                    dir_w_v;

  // LCE command queue input selects
  bp_cce_inst_lce_cmd_lce_sel_e            lce_cmd_lce_sel;
  bp_cce_inst_lce_cmd_addr_sel_e           lce_cmd_addr_sel;
  bp_cce_inst_lce_cmd_way_sel_e            lce_cmd_way_sel;

  // LCE Command Queue message command
  bp_cce_lce_cmd_type_e                    lce_cmd_cmd;

  // Mem data command queue input selects
  bp_cce_inst_mem_data_cmd_addr_sel_e      mem_data_cmd_addr_sel;

  // Register write enables
  logic                                    mov_dst_w_v;
  logic                                    alu_dst_w_v;
  logic [`bp_cce_inst_num_gpr-1:0]         gpr_w_mask;
  logic                                    gpr_w_v;

  // Write enable for req_lce, req_addr, req_tab registers
  logic                                    req_w_v;
  // Write enable for req_addr_way register
  logic                                    req_addr_way_w_v;
  logic                                    lru_way_w_v;
  // Write enable for tr_lce and tr_lce_way registers
  logic                                    transfer_lce_w_v;
  logic                                    cache_block_data_w_v;
  logic                                    ack_type_w_v;

  logic                                    gad_op_w_v;
  logic                                    rdw_op_w_v;
  logic                                    rde_op_w_v;

  logic [`bp_cce_inst_num_flags-1:0]       flag_mask_w_v;

  // Write enables for uncached data and request size registers
  logic                                    nc_data_lce_req;
  logic                                    nc_data_mem_data_resp;
  // data written on lce request or mem data response
  logic                                    nc_data_w_v;
  // request size written any time ucf (rqf) written
  logic                                    nc_req_size_w_v;

  // inbound messages - yumi signals (to FIFOs)
  logic                                    lce_req_yumi;
  logic                                    lce_resp_yumi;
  logic                                    lce_data_resp_yumi;
  logic                                    mem_resp_yumi;
  logic                                    mem_data_resp_yumi;
  // outbound messages - ready signals
  logic                                    lce_cmd_v;
  logic                                    lce_data_cmd_v;
  logic                                    mem_cmd_v;
  logic                                    mem_data_cmd_v;

} bp_cce_inst_decoded_s;

`define bp_cce_inst_decoded_width $bits(bp_cce_inst_decoded_s)

`endif

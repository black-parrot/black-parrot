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
 *   assembler. See the C code version of this file and the assembler source code for the available
 *   software supported operations.
 *
 */

/* TODO:
  - more flexible routing of GPRs for inputs for directory, outbound queue fields, etc.
  - anywhere gpr r0-r3 can be used, expand to r0-r7
  - 16 GPRs?




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

// Minor Branch Op Codes
typedef enum logic [2:0] {
  e_beq_op                               = 3'b000   // Branch if A == B
  ,e_bne_op                              = 3'b001   // Branch if A != B

  ,e_bf_op                               = 3'b010   // Branch if flag == 1 or 0 (set by immediate)
  ,e_bs_op                               = 3'b011   // Branch if special == GPR/imm

  ,e_blt_op                              = 3'b100   // Branch if A < B
  ,e_ble_op                              = 3'b101   // Branch if A <= B

  ,e_bqv_op                              = 3'b110   // Branch if queue.valid == 1
  ,e_bi_op                               = 3'b111   // Branch Immediate (Unconditional)

} bp_cce_inst_minor_branch_op_e;

// Minor Move Op Codes
typedef enum logic [2:0] {
  e_mov_op                               = 3'b000   // Move GPR to GPR
  ,e_movi_op                             = 3'b001   // Move Immediate to GPR
  ,e_movf_op                             = 3'b010   // Move Flag to GPR
  ,e_movsg_op                            = 3'b011   // Move Special Register to GPR
  ,e_movgs_op                            = 3'b100   // Move GPR to Special Register
} bp_cce_inst_minor_mov_op_e;

// Minor Flag Op Codes
typedef enum logic [2:0] {
  e_sf_op                                = 3'b000   // Move imm[0] = 1 to dst(flag)
  ,e_sfz_op                              = 3'b001   // Move imm[0] = 0 to dst(flag)
  ,e_andf_op                             = 3'b010   // Logical AND two flags to GPR
  ,e_orf_op                              = 3'b011   // Logical OR two flags to GPR
} bp_cce_inst_minor_flag_op_e;

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
  ,e_clm_op                              = 3'b001   // Clear MSHR register
  ,e_fence_op                            = 3'b010   // CCE Fence
  ,e_stall_op                            = 3'b111   // Stall PC
} bp_cce_inst_minor_misc_op_e;

// Minor Queue Op Codes
typedef enum logic [2:0] {
  e_wfq_op                               = 3'b000   // Wait for Queue Valid
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

// GPR Source Select
typedef enum logic [4:0] {
  e_src_r0                               = 5'b00000
  ,e_src_r1                              = 5'b00001
  ,e_src_r2                              = 5'b00010
  ,e_src_r3                              = 5'b00011
  ,e_src_r4                              = 5'b00100
  ,e_src_r5                              = 5'b00101
  ,e_src_r6                              = 5'b00110
  ,e_src_r7                              = 5'b00111

  ,e_src_gpr_imm                         = 5'b11111

} bp_cce_inst_src_gpr_e;

`define bp_cce_inst_src_gpr_width $bits(bp_cce_inst_src_gpr_e)

// Flag Source Select
typedef enum logic [4:0] {
  e_src_rqf                              = 5'b00000
  ,e_src_ucf                             = 5'b00001
  ,e_src_nerf                            = 5'b00010
  ,e_src_ldf                             = 5'b00011
  ,e_src_pf                              = 5'b00100
  ,e_src_lef                             = 5'b00101
  ,e_src_cf                              = 5'b00110
  ,e_src_cef                             = 5'b00111
  ,e_src_cof                             = 5'b01000
  ,e_src_cdf                             = 5'b01001
  ,e_src_tf                              = 5'b01010
  ,e_src_rf                              = 5'b01011
  ,e_src_uf                              = 5'b01100
  ,e_src_if                              = 5'b01101
  ,e_src_nwbf                            = 5'b01110

  ,e_src_flag_imm                        = 5'b11111

} bp_cce_inst_src_flag_e;

`define bp_cce_inst_src_flag_width $bits(bp_cce_inst_src_flag_e)

// Special Source Select
typedef enum logic [4:0] {
  e_src_sharers_hit_r0                   = 5'b00000
  ,e_src_sharers_way_r0                  = 5'b00001
  ,e_src_sharers_state_r0                = 5'b00010

  ,e_src_req_lce                         = 5'b01000
  ,e_src_next_coh_state                  = 5'b01001
  ,e_src_num_lce                         = 5'b01010
  ,e_src_req_addr                        = 5'b01011

  ,e_src_lce_req_v                       = 5'b10000
  ,e_src_mem_resp_v                      = 5'b10001
  ,e_src_pending_v                       = 5'b10010
  ,e_src_lce_resp_v                      = 5'b10011
  ,e_src_mem_cmd_v                       = 5'b10100

  ,e_src_lce_resp_type                   = 5'b11000

  ,e_src_special_imm                     = 5'b11111

} bp_cce_inst_src_special_e;

`define bp_cce_inst_src_special_width $bits(bp_cce_inst_src_special_e)

// Source Union
typedef union packed {
  bp_cce_inst_src_gpr_e        gpr;
  bp_cce_inst_src_flag_e       flag;
  bp_cce_inst_src_special_e    special;
} bp_cce_inst_src_u;

`define bp_cce_inst_src_width $bits(bp_cce_inst_src_u)

typedef enum logic [3:0] {
  e_src_sel_gpr            = 4'b0000
  ,e_src_sel_flag          = 4'b0001
  ,e_src_sel_special       = 4'b0010
} bp_cce_inst_src_sel_e;

`define bp_cce_inst_src_sel_width $bits(bp_cce_inst_src_sel_e)

// GPR Destination Select
typedef enum logic [4:0] {
  e_dst_r0                               = 5'b00000
  ,e_dst_r1                              = 5'b00001
  ,e_dst_r2                              = 5'b00010
  ,e_dst_r3                              = 5'b00011
  ,e_dst_r4                              = 5'b00100
  ,e_dst_r5                              = 5'b00101
  ,e_dst_r6                              = 5'b00110
  ,e_dst_r7                              = 5'b00111

} bp_cce_inst_dst_gpr_e;

`define bp_cce_inst_dst_gpr_width $bits(bp_cce_inst_dst_gpr_e)

// Flag Destination Select
typedef enum logic [4:0] {
  e_dst_rqf                              = 5'b00000
  ,e_dst_ucf                             = 5'b00001
  ,e_dst_nerf                            = 5'b00010
  ,e_dst_ldf                             = 5'b00011
  ,e_dst_pf                              = 5'b00100
  ,e_dst_lef                             = 5'b00101
  ,e_dst_cf                              = 5'b00110
  ,e_dst_cef                             = 5'b00111
  ,e_dst_cof                             = 5'b01000
  ,e_dst_cdf                             = 5'b01001
  ,e_dst_tf                              = 5'b01010
  ,e_dst_rf                              = 5'b01011
  ,e_dst_uf                              = 5'b01100
  ,e_dst_if                              = 5'b01101
  ,e_dst_nwbf                            = 5'b01110

} bp_cce_inst_dst_flag_e;

`define bp_cce_inst_dst_flag_width $bits(bp_cce_inst_dst_flag_e)

// Special Destination Select
typedef enum logic [4:0] {
  e_dst_next_coh_state                   = 5'b00000
  ,e_dst_num_lce                         = 5'b00001

} bp_cce_inst_dst_special_e;

`define bp_cce_inst_dst_special_width $bits(bp_cce_inst_dst_special_e)

// Destination Union
typedef union packed {
  bp_cce_inst_dst_gpr_e        gpr;
  bp_cce_inst_dst_flag_e       flag;
  bp_cce_inst_dst_special_e    special;
} bp_cce_inst_dst_u;

`define bp_cce_inst_dst_width $bits(bp_cce_inst_dst_u)

typedef enum logic [3:0] {
  e_dst_sel_gpr
  ,e_dst_sel_flag
  ,e_dst_sel_special
} bp_cce_inst_dst_sel_e;

`define bp_cce_inst_dst_sel_width $bits(bp_cce_inst_dst_sel_e)

// Flag register index select
typedef enum logic [3:0] {
  e_flag_sel_rqf                         = 4'b0000 // request type flag
  ,e_flag_sel_ucf                        = 4'b0001 // uncached request flag
  ,e_flag_sel_nerf                       = 4'b0010 // non-exclusive request flag
  ,e_flag_sel_ldf                        = 4'b0011 // lru dirty flag
  ,e_flag_sel_pf                         = 4'b0100 // pending flag
  ,e_flag_sel_lef                        = 4'b0101 // lru cached exclusive flag
  ,e_flag_sel_cf                         = 4'b0110 // cached by other flag
  ,e_flag_sel_cef                        = 4'b0111 // cached exclusive by other flag
  ,e_flag_sel_cof                        = 4'b1000 // cached owned by other flag
  ,e_flag_sel_cdf                        = 4'b1001 // cached dirty by other flag
  ,e_flag_sel_tf                         = 4'b1010 // transfer flag
  ,e_flag_sel_rf                         = 4'b1011 // replacement flag
  ,e_flag_sel_uf                         = 4'b1100 // upgrade flag
  ,e_flag_sel_if                         = 4'b1101 // invalidate flag
  ,e_flag_sel_nwbf                       = 4'b1110 // null writeback flag
} bp_cce_inst_flag_sel_e;

`define bp_cce_inst_flag_sel_width $bits(bp_cce_inst_flag_sel_e)

// Flag register one hot
typedef enum logic [14:0] {
  e_flag_rqf                             = 15'b000_0000_0000_0001 // request type flag
  ,e_flag_ucf                            = 15'b000_0000_0000_0010 // uncached request flag
  ,e_flag_nerf                           = 15'b000_0000_0000_0100 // non-exclusive request flag
  ,e_flag_ldf                            = 15'b000_0000_0000_1000 // lru dirty flag
  ,e_flag_pf                             = 15'b000_0000_0001_0000 // pending flag
  ,e_flag_lef                            = 15'b000_0000_0010_0000 // lru cached exclusive flag
  ,e_flag_cf                             = 15'b000_0000_0100_0000 // cached by other flag
  ,e_flag_cef                            = 15'b000_0000_1000_0000 // cached exclusive by other flag
  ,e_flag_cof                            = 15'b000_0001_0000_0000 // cached owned by other flag
  ,e_flag_cdf                            = 15'b000_0010_0000_0000 // cached dirty by other flag
  ,e_flag_tf                             = 15'b000_0100_0000_0000 // transfer flag
  ,e_flag_rf                             = 15'b000_1000_0000_0000 // replacement flag
  ,e_flag_uf                             = 15'b001_0000_0000_0000 // upgrade flag
  ,e_flag_if                             = 15'b010_0000_0000_0000 // invalidate flag
  ,e_flag_nwbf                           = 15'b100_0000_0000_0000 // null writeback flag
} bp_cce_inst_flag_e;

`define bp_cce_inst_num_flags $bits(bp_cce_inst_flag_e)

// source select for directory way group input
typedef enum logic [3:0] {
  e_dir_wg_sel_r0                        = 4'b0000
  ,e_dir_wg_sel_r1                       = 4'b0001
  ,e_dir_wg_sel_r2                       = 4'b0010
  ,e_dir_wg_sel_r3                       = 4'b0011
  ,e_dir_wg_sel_r4                       = 4'b0100
  ,e_dir_wg_sel_r5                       = 4'b0101
  ,e_dir_wg_sel_r6                       = 4'b0110
  ,e_dir_wg_sel_r7                       = 4'b0111
  ,e_dir_wg_sel_req_addr                 = 4'b1000
  ,e_dir_wg_sel_lru_way_addr             = 4'b1001
} bp_cce_inst_dir_way_group_sel_e;

`define bp_cce_inst_dir_way_group_sel_width $bits(bp_cce_inst_dir_way_group_sel_e)

// source select for directory lce input
typedef enum logic [3:0] {
  e_dir_lce_sel_r0                       = 4'b0000
  ,e_dir_lce_sel_r1                      = 4'b0001
  ,e_dir_lce_sel_r2                      = 4'b0010
  ,e_dir_lce_sel_r3                      = 4'b0011
  ,e_dir_lce_sel_r4                      = 4'b0100
  ,e_dir_lce_sel_r5                      = 4'b0101
  ,e_dir_lce_sel_r6                      = 4'b0110
  ,e_dir_lce_sel_r7                      = 4'b0111
  ,e_dir_lce_sel_req_lce                 = 4'b1000
  ,e_dir_lce_sel_transfer_lce            = 4'b1001
} bp_cce_inst_dir_lce_sel_e;

`define bp_cce_inst_dir_lce_sel_width $bits(bp_cce_inst_dir_lce_sel_e)

// source select for directory way input
typedef enum logic [3:0] {
  e_dir_way_sel_r0                       = 4'b0000
  ,e_dir_way_sel_r1                      = 4'b0001
  ,e_dir_way_sel_r2                      = 4'b0010
  ,e_dir_way_sel_r3                      = 4'b0011
  ,e_dir_way_sel_r4                      = 4'b0100
  ,e_dir_way_sel_r5                      = 4'b0101
  ,e_dir_way_sel_r6                      = 4'b0110
  ,e_dir_way_sel_r7                      = 4'b0111
  ,e_dir_way_sel_req_addr_way            = 4'b1000
  ,e_dir_way_sel_lru_way_addr_way        = 4'b1001
  ,e_dir_way_sel_sh_way_r0               = 4'b1010
} bp_cce_inst_dir_way_sel_e;

`define bp_cce_inst_dir_way_sel_width $bits(bp_cce_inst_dir_way_sel_e)

// source select for directory coherence state input
typedef enum logic [3:0] {
  e_dir_coh_sel_r0                       = 4'b0000
  ,e_dir_coh_sel_r1                      = 4'b0001
  ,e_dir_coh_sel_r2                      = 4'b0010
  ,e_dir_coh_sel_r3                      = 4'b0011
  ,e_dir_coh_sel_r4                      = 4'b0100
  ,e_dir_coh_sel_r5                      = 4'b0101
  ,e_dir_coh_sel_r6                      = 4'b0110
  ,e_dir_coh_sel_r7                      = 4'b0111
  ,e_dir_coh_sel_next_coh_st             = 4'b1000
  ,e_dir_coh_sel_inst_imm                = 4'b1001
} bp_cce_inst_dir_coh_state_sel_e;

`define bp_cce_inst_dir_coh_state_sel_width $bits(bp_cce_inst_dir_coh_state_sel_e)

// source select for directory tag input
typedef enum logic [3:0] {
  e_dir_tag_sel_r0                       = 4'b0000
  ,e_dir_tag_sel_r1                      = 4'b0001
  ,e_dir_tag_sel_r2                      = 4'b0010
  ,e_dir_tag_sel_r3                      = 4'b0011
  ,e_dir_tag_sel_r4                      = 4'b0100
  ,e_dir_tag_sel_r5                      = 4'b0101
  ,e_dir_tag_sel_r6                      = 4'b0110
  ,e_dir_tag_sel_r7                      = 4'b0111
  ,e_dir_tag_sel_req_addr                = 4'b1000
  ,e_dir_tag_sel_lru_way_addr            = 4'b1001
  ,e_dir_tag_sel_const_0                 = 4'b1010
} bp_cce_inst_dir_tag_sel_e;

`define bp_cce_inst_dir_tag_sel_width $bits(bp_cce_inst_dir_tag_sel_e)

// Source queue one hot
// order: {lceReq, lceResp, memResp, pending}
typedef enum logic [4:0] {
  e_src_q_pending                        = 5'b00001
  ,e_src_q_mem_resp                      = 5'b00010
  ,e_src_q_lce_resp                      = 5'b00100
  ,e_src_q_lce_req                       = 5'b01000
  ,e_src_q_mem_cmd                       = 5'b10000
} bp_cce_inst_src_q_e;

`define bp_cce_num_src_q $bits(bp_cce_inst_src_q_e)

// Source queue select
typedef enum logic [2:0] {
  e_src_q_sel_lce_req                    = 3'b000
  ,e_src_q_sel_mem_resp                  = 3'b001
  ,e_src_q_sel_pending                   = 3'b010
  ,e_src_q_sel_lce_resp                  = 3'b011
  ,e_src_q_sel_mem_cmd                   = 3'b100
} bp_cce_inst_src_q_sel_e;

`define bp_cce_inst_src_q_sel_width $bits(bp_cce_inst_src_q_sel_e)

// Destination queue select
typedef enum logic [1:0] {
  e_dst_q_lce_cmd                        = 2'b00
  ,e_dst_q_mem_cmd                       = 2'b01
  ,e_dst_q_mem_resp                      = 2'b10
} bp_cce_inst_dst_q_sel_e;

`define bp_cce_inst_dst_q_sel_width $bits(bp_cce_inst_dst_q_sel_e)

// LCE cmd lce_id source select
typedef enum logic [3:0] {
  e_lce_cmd_lce_r0                       = 4'b0000
  ,e_lce_cmd_lce_r1                      = 4'b0001
  ,e_lce_cmd_lce_r2                      = 4'b0010
  ,e_lce_cmd_lce_r3                      = 4'b0011
  ,e_lce_cmd_lce_r4                      = 4'b0100
  ,e_lce_cmd_lce_r5                      = 4'b0101
  ,e_lce_cmd_lce_r6                      = 4'b0110
  ,e_lce_cmd_lce_r7                      = 4'b0111
  ,e_lce_cmd_lce_req_lce                 = 4'b1000
  ,e_lce_cmd_lce_tr_lce                  = 4'b1001
  ,e_lce_cmd_lce_0                       = 4'b1010
} bp_cce_inst_lce_cmd_lce_sel_e;

`define bp_cce_inst_lce_cmd_lce_sel_width $bits(bp_cce_inst_lce_cmd_lce_sel_e)

// LCE cmd addr source select
typedef enum logic [3:0] {
  e_lce_cmd_addr_r0                      = 4'b0000
  ,e_lce_cmd_addr_r1                     = 4'b0001
  ,e_lce_cmd_addr_r2                     = 4'b0010
  ,e_lce_cmd_addr_r3                     = 4'b0011
  ,e_lce_cmd_addr_r4                     = 4'b0100
  ,e_lce_cmd_addr_r5                     = 4'b0101
  ,e_lce_cmd_addr_r6                     = 4'b0110
  ,e_lce_cmd_addr_r7                     = 4'b0111
  ,e_lce_cmd_addr_req_addr               = 4'b1000
  ,e_lce_cmd_addr_lru_way_addr           = 4'b1001
  ,e_lce_cmd_addr_0                      = 4'b1010
} bp_cce_inst_lce_cmd_addr_sel_e;

`define bp_cce_inst_lce_cmd_addr_sel_width $bits(bp_cce_inst_lce_cmd_addr_sel_e)

// LCE cmd way source select
typedef enum logic [3:0] {
  e_lce_cmd_way_r0                       = 4'b0000
  ,e_lce_cmd_way_r1                      = 4'b0001
  ,e_lce_cmd_way_r2                      = 4'b0010
  ,e_lce_cmd_way_r3                      = 4'b0011
  ,e_lce_cmd_way_r4                      = 4'b0100
  ,e_lce_cmd_way_r5                      = 4'b0101
  ,e_lce_cmd_way_r6                      = 4'b0110
  ,e_lce_cmd_way_r7                      = 4'b0111
  ,e_lce_cmd_way_req_addr_way            = 4'b1000
  ,e_lce_cmd_way_tr_addr_way             = 4'b1001
  ,e_lce_cmd_way_sh_list_r0              = 4'b1010
  ,e_lce_cmd_way_lru_addr_way            = 4'b1011
  ,e_lce_cmd_way_0                       = 4'b1100
} bp_cce_inst_lce_cmd_way_sel_e;

`define bp_cce_inst_lce_cmd_way_sel_width $bits(bp_cce_inst_lce_cmd_way_sel_e)

// Mem Cmd addr source select
typedef enum logic [3:0] {
  e_mem_cmd_addr_r0                      = 4'b0000
  ,e_mem_cmd_addr_r1                     = 4'b0001
  ,e_mem_cmd_addr_r2                     = 4'b0010
  ,e_mem_cmd_addr_r3                     = 4'b0011
  ,e_mem_cmd_addr_r4                     = 4'b0100
  ,e_mem_cmd_addr_r5                     = 4'b0101
  ,e_mem_cmd_addr_r6                     = 4'b0110
  ,e_mem_cmd_addr_r7                     = 4'b0111
  ,e_mem_cmd_addr_lru_way_addr           = 4'b1000
  ,e_mem_cmd_addr_req_addr               = 4'b1001
} bp_cce_inst_mem_cmd_addr_sel_e;

`define bp_cce_inst_mem_cmd_addr_sel_width $bits(bp_cce_inst_mem_cmd_addr_sel_e)

// GPR Numbers
typedef enum logic [2:0] {
  e_gpr_r0                               = 3'b000
  ,e_gpr_r1                              = 3'b001
  ,e_gpr_r2                              = 3'b010
  ,e_gpr_r3                              = 3'b011
  ,e_gpr_r4                              = 3'b100
  ,e_gpr_r5                              = 3'b101
  ,e_gpr_r6                              = 3'b110
  ,e_gpr_r7                              = 3'b111
} bp_cce_gpr_e;

// Note: number of gpr must be a power of 2
`define bp_cce_inst_num_gpr (2**$bits(bp_cce_gpr_e))
`define bp_cce_inst_gpr_width 64

// source select for reqlce and reqaddr registers writes
typedef enum logic [1:0] {
  e_req_sel_lce_req                      = 2'b00
  ,e_req_sel_pending                     = 2'b01
  ,e_req_sel_mem_cmd                     = 2'b10
} bp_cce_inst_req_sel_e;

`define bp_cce_inst_req_sel_width $bits(bp_cce_inst_req_sel_e)

// Source select for req_addr_way
typedef enum logic [1:0] {
  e_req_addr_way_sel_logic               = 2'b00
  ,e_req_addr_way_sel_mem_resp           = 2'b01
} bp_cce_inst_req_addr_way_sel_e;

`define bp_cce_inst_req_addr_way_sel_width $bits(bp_cce_inst_req_addr_way_sel_e)

// Source select for lru_way
typedef enum logic [1:0] {
  e_lru_way_sel_lce_req                  = 2'b00
  ,e_lru_way_sel_pending                 = 2'b01
} bp_cce_inst_lru_way_sel_e;

`define bp_cce_inst_lru_way_sel_width $bits(bp_cce_inst_lru_way_sel_e)

// RQF
typedef enum logic [1:0] {
  e_rqf_lce_req                          = 2'b00
  ,e_rqf_pending                         = 2'b01
  ,e_rqf_imm0                            = 2'b10
} bp_cce_inst_rqf_sel_e;

`define bp_cce_inst_rqf_sel_width $bits(bp_cce_inst_rqf_sel_e)

// UCF
typedef enum logic [1:0] {
  e_ucf_lce_req                         = 2'b00
  ,e_ucf_pending                        = 2'b01
  ,e_ucf_imm0                           = 2'b10
} bp_cce_inst_ucf_sel_e;

`define bp_cce_inst_ucf_sel_width $bits(bp_cce_inst_ucf_sel_e)

// NERF
typedef enum logic [1:0] {
  e_nerf_lce_req                        = 2'b00
  ,e_nerf_pending                       = 2'b01
  ,e_nerf_imm0                          = 2'b10
} bp_cce_inst_nerf_sel_e;

`define bp_cce_inst_nerf_sel_width $bits(bp_cce_inst_nerf_sel_e)

// LDF
typedef enum logic [1:0] {
  e_ldf_lce_req                          = 2'b00
  ,e_ldf_pending                         = 2'b01
  ,e_ldf_imm0                            = 2'b10
} bp_cce_inst_ldf_sel_e;

`define bp_cce_inst_ldf_sel_width $bits(bp_cce_inst_ldf_sel_e)

// PF
typedef enum logic {
  e_pf_logic                             = 1'b0
  ,e_pf_imm0                             = 1'b1
} bp_cce_inst_pf_sel_e;

`define bp_cce_inst_pf_sel_width $bits(bp_cce_inst_pf_sel_e)

// LEF
typedef enum logic {
  e_lef_logic                             = 1'b0
  ,e_lef_imm0                             = 1'b1
} bp_cce_inst_lef_sel_e;

`define bp_cce_inst_lef_sel_width $bits(bp_cce_inst_lef_sel_e)

// CF
typedef enum logic {
  e_cf_logic                             = 1'b0
  ,e_cf_imm0                             = 1'b1
} bp_cce_inst_cf_sel_e;

`define bp_cce_inst_cf_sel_width $bits(bp_cce_inst_cf_sel_e)

// CEF
typedef enum logic {
  e_cef_logic                             = 1'b0
  ,e_cef_imm0                             = 1'b1
} bp_cce_inst_cef_sel_e;

`define bp_cce_inst_cef_sel_width $bits(bp_cce_inst_cef_sel_e)

// COF
typedef enum logic {
  e_cof_logic                             = 1'b0
  ,e_cof_imm0                             = 1'b1
} bp_cce_inst_cof_sel_e;

`define bp_cce_inst_cof_sel_width $bits(bp_cce_inst_cof_sel_e)

// CDF
typedef enum logic {
  e_cdf_logic                             = 1'b0
  ,e_cdf_imm0                             = 1'b1
} bp_cce_inst_cdf_sel_e;

`define bp_cce_inst_cdf_sel_width $bits(bp_cce_inst_cdf_sel_e)

// TF
typedef enum logic {
  e_tf_logic                              = 1'b0
  ,e_tf_imm0                              = 1'b1
} bp_cce_inst_tf_sel_e;

`define bp_cce_inst_tf_sel_width $bits(bp_cce_inst_tf_sel_e)

// RF
typedef enum logic {
  e_rf_logic                              = 1'b0
  ,e_rf_imm0                              = 1'b1
} bp_cce_inst_rf_sel_e;

`define bp_cce_inst_rf_sel_width $bits(bp_cce_inst_rf_sel_e)

// UF
typedef enum logic {
  e_uf_logic                             = 1'b0
  ,e_uf_imm0                             = 1'b1
} bp_cce_inst_uf_sel_e;

`define bp_cce_inst_uf_sel_width $bits(bp_cce_inst_uf_sel_e)

// IF
typedef enum logic {
  e_if_logic                             = 1'b0
  ,e_if_imm0                             = 1'b1
} bp_cce_inst_if_sel_e;

`define bp_cce_inst_if_sel_width $bits(bp_cce_inst_if_sel_e)

// NWBF
typedef enum logic {
  e_nwbf_lce_resp                        = 1'b0
  ,e_nwbf_imm0                           = 1'b1
} bp_cce_inst_nwbf_sel_e;

`define bp_cce_inst_nwbf_sel_width $bits(bp_cce_inst_nwbf_sel_e)


// Instruction immediate fields
`define bp_cce_inst_imm16_width 16
`define bp_cce_inst_imm32_width 32
`define bp_cce_inst_imm64_width 64
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
  bp_cce_inst_dst_gpr_e                  dst;
  bp_cce_inst_src_gpr_e                  src_a;
  bp_cce_inst_src_gpr_e                  src_b;
  logic [`bp_cce_inst_imm16_width-1:0]   imm;
  logic [`bp_cce_inst_alu_pad-1:0]       pad;
} bp_cce_inst_alu_op_s;

/*
 * Branch Operation
 */

`define bp_cce_inst_branch_pad (`bp_cce_inst_type_u_width-(2*`bp_cce_inst_src_width) \
  -(2*`bp_cce_inst_imm16_width))

typedef struct packed {
  bp_cce_inst_src_u                      src_a;
  bp_cce_inst_src_u                      src_b;
  logic [`bp_cce_inst_imm16_width-1:0]   target;
  logic [`bp_cce_inst_imm16_width-1:0]   imm;
  // no pad
} bp_cce_inst_branch_op_s;

/*
 * Move Operation
 */

`define bp_cce_inst_mov_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dst_width \
  -`bp_cce_inst_src_width-`bp_cce_inst_imm32_width)

typedef struct packed {
  bp_cce_inst_dst_u                      dst;
  bp_cce_inst_src_u                      src;
  logic [`bp_cce_inst_imm32_width-1:0]   imm;
  // no pad
} bp_cce_inst_mov_op_s;

/*
 * Flag Operation
 *
 */

`define bp_cce_inst_flag_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dst_width \
  -(2*`bp_cce_inst_src_width)-1)

typedef struct packed {
  bp_cce_inst_dst_u                      dst;
  bp_cce_inst_src_flag_e                 src_a;
  bp_cce_inst_src_flag_e                 src_b;
  logic                                  val;
  logic [`bp_cce_inst_flag_pad-1:0]      pad;
} bp_cce_inst_flag_op_s;

/*
 * Read Directory Operation
 */

`define bp_cce_inst_read_dir_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dir_way_group_sel_width \
  -`bp_cce_inst_dir_lce_sel_width-`bp_cce_inst_dir_way_sel_width-`bp_cce_inst_dir_tag_sel_width \
  -`bp_cce_inst_dst_width)

typedef struct packed {
  bp_cce_inst_dir_way_group_sel_e        dir_way_group_sel;
  bp_cce_inst_dir_lce_sel_e              dir_lce_sel;
  bp_cce_inst_dir_way_sel_e              dir_way_sel;
  bp_cce_inst_dir_tag_sel_e              dir_tag_sel;
  bp_cce_inst_dst_gpr_e                  dst;
  logic [`bp_cce_inst_read_dir_pad-1:0]  pad;
} bp_cce_inst_read_dir_op_s;

/*
 * Write Directory Operation
 */

`define bp_cce_inst_write_dir_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_dir_way_group_sel_width \
  -`bp_cce_inst_dir_lce_sel_width-`bp_cce_inst_dir_way_sel_width \
  -`bp_cce_inst_dir_coh_state_sel_width-`bp_cce_inst_dir_tag_sel_width \
  -`bp_coh_bits)

typedef struct packed {
  // directory inputs
  bp_cce_inst_dir_way_group_sel_e        dir_way_group_sel;
  bp_cce_inst_dir_lce_sel_e              dir_lce_sel;
  bp_cce_inst_dir_way_sel_e              dir_way_sel;
  bp_cce_inst_dir_coh_state_sel_e        dir_coh_state_sel;
  bp_cce_inst_dir_tag_sel_e              dir_tag_sel;
  logic [`bp_coh_bits-1:0]               imm;
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
  -$bits(bp_lce_cmd_type_e)-`bp_cce_inst_lce_cmd_lce_sel_width \
  -`bp_cce_inst_lce_cmd_addr_sel_width-`bp_cce_inst_lce_cmd_way_sel_width \
  -`bp_cce_inst_mem_cmd_addr_sel_width)

typedef struct packed {
  bp_cce_inst_dst_q_sel_e                dst_q;
  union packed
  {
    bp_lce_cmd_type_e      lce_cmd;
    bp_cce_mem_cmd_type_e  mem_cmd;
    bp_mem_cce_cmd_type_e  mem_resp;
  }                                      cmd;
  // cce_lce_cmd_queue inputs
  bp_cce_inst_lce_cmd_lce_sel_e          lce_cmd_lce_sel;
  bp_cce_inst_lce_cmd_addr_sel_e         lce_cmd_addr_sel;
  bp_cce_inst_lce_cmd_way_sel_e          lce_cmd_way_sel;
  // mem_cmd_queue inputs
  bp_cce_inst_mem_cmd_addr_sel_e         mem_cmd_addr_sel;
  logic [`bp_cce_inst_pushq_pad-1:0]     pad;
} bp_cce_inst_pushq_s;

`define bp_cce_inst_popq_pad (`bp_cce_inst_type_u_width-`bp_cce_inst_src_q_sel_width \
  -`bp_cce_inst_dst_width)

typedef struct packed {
  bp_cce_inst_src_q_sel_e                src_q;
  bp_cce_inst_dst_gpr_e                  dst;
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

  // Basic operation information
  bp_cce_inst_op_e                         op;
  bp_cce_inst_minor_op_u                   minor_op_u;

  // Destination and Source signals
  bp_cce_inst_dst_u                        dst;
  bp_cce_inst_src_u                        src_a;
  bp_cce_inst_src_u                        src_b;

  // Select signals for dst and src unions
  bp_cce_inst_dst_sel_e                    dst_sel;
  bp_cce_inst_src_sel_e                    src_a_sel;
  bp_cce_inst_src_sel_e                    src_b_sel;

  // Immediate
  logic [`bp_cce_inst_gpr_width-1:0]       imm;

  // ALU signals
  // ALU arithmetic operation
  logic                                    alu_v;
  // ALU branch operation
  logic                                    branch_v;

  // op uses gad module
  logic                                    gad_v;
  // Pending Bit Read Operation
  logic                                    pending_r_v;
  // Pending Bit Write Operation
  logic                                    pending_w_v;

  // Register source selects
  bp_cce_inst_req_sel_e                    req_sel;
  bp_cce_inst_lru_way_sel_e                lru_way_sel;

  // Flag source selects
  bp_cce_inst_rqf_sel_e                    rqf_sel;
  bp_cce_inst_ucf_sel_e                    ucf_sel;
  bp_cce_inst_nerf_sel_e                   nerf_sel;
  bp_cce_inst_ldf_sel_e                    ldf_sel;
  bp_cce_inst_pf_sel_e                     pf_sel;
  bp_cce_inst_lef_sel_e                    lef_sel;
  bp_cce_inst_cf_sel_e                     cf_sel;
  bp_cce_inst_cef_sel_e                    cef_sel;
  bp_cce_inst_cof_sel_e                    cof_sel;
  bp_cce_inst_cdf_sel_e                    cdf_sel;
  bp_cce_inst_tf_sel_e                     tf_sel;
  bp_cce_inst_rf_sel_e                     rf_sel;
  bp_cce_inst_uf_sel_e                     uf_sel;
  bp_cce_inst_if_sel_e                     if_sel;
  bp_cce_inst_nwbf_sel_e                   nwbf_sel;

  // Directory source selects
  bp_cce_inst_dir_way_group_sel_e          dir_way_group_sel;
  bp_cce_inst_dir_lce_sel_e                dir_lce_sel;
  bp_cce_inst_dir_way_sel_e                dir_way_sel;
  bp_cce_inst_dir_coh_state_sel_e          dir_coh_state_sel;
  bp_cce_inst_dir_tag_sel_e                dir_tag_sel;

  // Directory inputs
  // TODO: r/w cmd can be replaced with decoded_inst.minor_op_u
  logic [`bp_cce_inst_minor_op_width-1:0]  dir_r_cmd;
  logic                                    dir_r_v;
  logic [`bp_cce_inst_minor_op_width-1:0]  dir_w_cmd;
  logic                                    dir_w_v;

  // LCE command queue input selects
  bp_cce_inst_lce_cmd_lce_sel_e            lce_cmd_lce_sel;
  bp_cce_inst_lce_cmd_addr_sel_e           lce_cmd_addr_sel;
  bp_cce_inst_lce_cmd_way_sel_e            lce_cmd_way_sel;

  // LCE Command Queue message command
  bp_lce_cmd_type_e                        lce_cmd;

  // Mem Command Queue message command
  bp_cce_mem_cmd_type_e                    mem_cmd;
  // Mem Command queue input selects
  bp_cce_inst_mem_cmd_addr_sel_e           mem_cmd_addr_sel;

  // Mem Response type
  bp_mem_cce_cmd_type_e                    mem_resp;

  // Register write enables
  // TODO: write enable for every register
  // - not really an enable, but rather a signal to tell register file when/how to set source
  // for register _n signals
  // TODO: CCE tracer - add detection of current instruction == stall, terminate simulation
  // this allows testing microcode by finishing with stall
  logic                                    mov_dst_w_v;
  logic                                    alu_dst_w_v;
  logic [`bp_cce_inst_num_gpr-1:0]         gpr_w_mask;
  logic [`bp_cce_inst_num_flags-1:0]       flag_mask_w_v;

  // Write enable for gpr from RDE op
  logic                                    rde_w_v;

  // Write enable for req_lce, req_addr registers
  logic                                    req_w_v;
  // Write enable for req_addr_way register
  logic                                    req_addr_way_w_v;
  logic                                    lru_way_w_v;
  // Write enable for tr_lce and tr_lce_way registers
  logic                                    transfer_lce_w_v;
  // Write enable for lce response type
  logic                                    resp_type_w_v;
  // Write enable for mem response type
  logic                                    mem_resp_type_w_v;
  // Write enable for mem command type
  logic                                    mem_cmd_type_w_v;


  // Write enables for uncached data and request size registers
  // data written on lce request
  logic                                    nc_data_w_v;
  // request size written any time ucf (rqf) written
  logic                                    nc_req_size_w_v;

  // inbound messages - yumi signals (to FIFOs)
  logic                                    lce_req_yumi;
  logic                                    lce_resp_yumi;
  logic                                    mem_resp_yumi;
  logic                                    mem_cmd_yumi;

  // outbound messages - valid signals
  logic                                    lce_cmd_v;
  logic                                    mem_cmd_v;
  logic                                    mem_resp_v;

  // clear mshr
  logic                                    mshr_clear;

} bp_cce_inst_decoded_s;

`define bp_cce_inst_decoded_width $bits(bp_cce_inst_decoded_s)

`endif

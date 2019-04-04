/*
 * bp_cce_inst.h
 *
 * This file defines the CCE microcode instruction struct and the various fields within in.
 *
 */

#ifndef BP_CCE_INST_H
#define BP_CCE_INST_H

// Major Op Codes
typedef enum {
  e_op_alu                       = 0x0
  ,e_op_branch                   = 0x1
  ,e_op_move                     = 0x2
  ,e_op_flag                     = 0x2 // Set and Clear Flag are MOVI variants
  ,e_op_read_dir                 = 0x4
  ,e_op_write_dir                = 0x5
  ,e_op_misc                     = 0x6
  ,e_op_queue                    = 0x7
} bp_cce_inst_op_e;

#define bp_cce_inst_op_width 3

// Minor Op Codes
typedef enum {
  e_add                          = 0x0   // Add
  ,e_inc                         = 0x0   // Increment by 1 // same as ADD, src_b = 1, dst = src_a
  ,e_sub                         = 0x1   // Subtract
  ,e_dec                         = 0x1   // Decrement by 1 // same as DEC, src_b = 1, dst = src_a
} bp_cce_inst_minor_alu_op_e;

typedef enum {
  e_bi                           = 0x7   // Branch Immediate (Unconditional)

  ,e_beq                         = 0x2   // Branch if A == B
  ,e_bne                         = 0x3   // Branch if A != B

  ,e_bz                          = 0x2   // Branch if A == 0 // same as BEQ, src_b = 0
  ,e_bnz                         = 0x3   // Branch if A != 0 // same as BNE, src_b = 0

  ,e_bf                          = 0x2   // Branch if Flag == 1 // same as BEQ, src_a = flag, src_b = 1
  ,e_bfz                         = 0x2   // Branch if Flag == 0 // same as BEQ, src_a = flag, src_b = 0

  ,e_bqr                         = 0x2   // Branch if Queue.ready == 1 // same as BEQ src_a = queue.ready, src_b = 1

  ,e_blt                         = 0x4   // Branch if A < B
  ,e_ble                         = 0x5   // Branch if A <= B
  ,e_bgt                         = 0x4   // Branch if A > B // same as BLT, swap src_a and src_b
  ,e_bge                         = 0x5   // Branch if A >= B // same as BLE, swap src_a and src_b
} bp_cce_inst_minor_branch_op_e;

typedef enum {
  e_mov                          = 0x0   // Move src_a to dst
  ,e_movi                        = 0x1   // Move imm to dst
} bp_cce_inst_minor_mov_op_e;

typedef enum {
  e_sf                           = 0x1   // Move imm[0] = 1 to dst(flag)
  ,e_sfz                         = 0x1   // Move imm[1] = 0 to dst(flag)
} bp_cce_inst_minor_flag_op_e;

typedef enum {
  e_rdp                          = 0x0   // Read Directory Pending Bit
  ,e_rdw                         = 0x1   // Read Directory Way Group
  ,e_rde                         = 0x2   // Read Directory Entry
} bp_cce_inst_minor_read_dir_op_e;

typedef enum {
  e_wdp                          = 0x0   // Write Directory Pending Bit
  ,e_wde                         = 0x1   // Write Directory Entry
  ,e_wds                         = 0x2   // Write Directory Entry State
} bp_cce_inst_minor_write_dir_op_e;

typedef enum {
  e_gad                          = 0x0   // Generate Auxiliary Data
  ,e_stall                       = 0x7   // Stall PC - used for errors
} bp_cce_inst_minor_misc_op_e;

typedef enum {
  e_wfq                          = 0x0   // Wait for Queue Ready
  ,e_pushq                       = 0x1   // Push Queue
  ,e_popq                        = 0x2   // Pop Queue
} bp_cce_inst_minor_queue_op_e;

#define bp_cce_inst_minor_op_width 3

typedef enum {
  e_src_r0                       = 0x0
  ,e_src_r1                      = 0x1
  ,e_src_r2                      = 0x2
  ,e_src_r3                      = 0x3
  ,e_src_rqf                     = 0x4
  ,e_src_nerf                    = 0x5
  ,e_src_ldf                     = 0x6
  ,e_src_nwbf                    = 0x7
  ,e_src_tf                      = 0x8
  ,e_src_rf                      = 0x9
  ,e_src_rwbf                    = 0xA
  ,e_src_pf                      = 0xB
  ,e_src_uf                      = 0xC
  ,e_src_if                      = 0xD
  ,e_src_ef                      = 0xE
  ,e_src_pcf                     = 0xF
  ,e_src_ucf                     = 0x10

  ,e_src_const_0                 = 0x11
  ,e_src_const_1                 = 0x12
  ,e_src_imm                     = 0x13
  ,e_src_req_lce                 = 0x14
  ,e_src_ack_type                = 0x15
  ,e_src_sharers_hit_r0          = 0x16

  ,e_src_lce_req_ready           = 0x18
  ,e_src_mem_resp_ready          = 0x19
  ,e_src_mem_data_resp_ready     = 0x1A
  ,e_src_pending_ready           = 0x1B
  ,e_src_lce_resp_ready          = 0x1C
  ,e_src_lce_data_resp_ready     = 0x1D
} bp_cce_inst_src_e;

#define bp_cce_inst_src_width 5

typedef enum {
  e_dst_r0                       = 0x0
  ,e_dst_r1                      = 0x1
  ,e_dst_r2                      = 0x2
  ,e_dst_r3                      = 0x3
  ,e_dst_rqf                     = 0x4
  ,e_dst_nerf                    = 0x5
  ,e_dst_ldf                     = 0x6
  ,e_dst_nwbf                    = 0x7
  ,e_dst_tf                      = 0x8
  ,e_dst_rf                      = 0x9
  ,e_dst_rwbf                    = 0xA
  ,e_dst_pf                      = 0xB
  ,e_dst_uf                      = 0xC
  ,e_dst_if                      = 0xD
  ,e_dst_ef                      = 0xE
  ,e_dst_pcf                     = 0xF
  ,e_dst_ucf                     = 0x10
  ,e_dst_next_coh_state          = 0x11
} bp_cce_inst_dst_e;

#define bp_cce_inst_dst_width 5

typedef enum {
  e_gpr_r0                       = 0x0
  ,e_gpr_r1                      = 0x1
  ,e_gpr_r2                      = 0x2
  ,e_gpr_r3                      = 0x3
} bp_cce_gpr_e;

#define bp_cce_inst_num_gpr 4
#define bp_cce_inst_gpr_width 16

typedef enum {
  e_flag_rqf                     = 1 // Request Type Flag
  ,e_flag_nerf                   = 2 // Non-Exclusive Request Flag
  ,e_flag_ldf                    = 4 // LRU Dirty Flag
  ,e_flag_nwbf                   = 8 // Null Writeback Flag
  ,e_flag_tf                     = 16 // Transfer Flag
  ,e_flag_rf                     = 32 // Replacement Flag
  ,e_flag_rwbf                   = 64 // Replacement Writeback Flag
  ,e_flag_pf                     = 128 // Pending Flag
  ,e_flag_uf                     = 256 // Upgrade Flag
  ,e_flag_if                     = 512 // Invalidate Flag
  ,e_flag_ef                     = 1024 // Exclusive Flag
  ,e_flag_pcf                    = 2048 // Pending-Cleared Flag
  ,e_flag_ucf                    = 4096 // Uncached Request Flag
} bp_cce_inst_flag_e;

#define bp_cce_inst_num_flags 13

typedef enum {
  e_flag_sel_rqf                 = 0x0 // Request Type Flag
  ,e_flag_sel_nerf               = 0x1 // Non-Exclusive Request Flag
  ,e_flag_sel_ldf                = 0x2 // LRU Dirty Flag
  ,e_flag_sel_nwbf               = 0x3 // Null Writeback Flag
  ,e_flag_sel_tf                 = 0x4 // Transfer Flag
  ,e_flag_sel_rf                 = 0x5 // Replacement Flag
  ,e_flag_sel_rwbf               = 0x6 // Replacement Writeback Flag
  ,e_flag_sel_pf                 = 0x7 // Pending Flag
  ,e_flag_sel_uf                 = 0x8 // Upgrade Flag
  ,e_flag_sel_if                 = 0x9 // Invalidate Flag
  ,e_flag_sel_ef                 = 0xA // Exclusive Flag
  ,e_flag_sel_pcf                = 0xB // Pending-Cleared Flag
  ,e_flag_sel_ucf                = 0xC // Uncached Request Flag
} bp_cce_inst_flag_sel_e;

#define bp_cce_inst_flag_sel_width 4

// Source select for ReqLCE and ReqAddr registers writes
typedef enum {
  e_req_sel_lce_req              = 0x0
  ,e_req_sel_mem_resp            = 0x1
  ,e_req_sel_mem_data_resp       = 0x2
  ,e_req_sel_pending             = 0x3
} bp_cce_inst_req_sel_e;

#define bp_cce_inst_req_sel_width 2

typedef enum {
  e_req_addr_way_sel_logic           = 0x0
  ,e_req_addr_way_sel_mem_resp       = 0x1
  ,e_req_addr_way_sel_mem_data_resp  = 0x2
} bp_cce_inst_req_addr_way_sel_e;

#define bp_cce_inst_req_addr_way_sel_width 2

typedef enum {
  e_lru_way_sel_lce_req          = 0x0
  ,e_lru_way_sel_mem_resp        = 0x1
  ,e_lru_way_sel_mem_data_resp   = 0x2
  ,e_lru_way_sel_pending         = 0x3
} bp_cce_inst_lru_way_sel_e;

#define bp_cce_inst_lru_way_sel_width 2

// Source select for Cache Block Data register writes
typedef enum {
  e_data_sel_lce_data_resp       = 0x0
  ,e_data_sel_mem_data_resp      = 0x1
} bp_cce_inst_cache_block_data_sel_e;

#define bp_cce_inst_dat_sel_width 1

// Source select for Directory Way Group input
typedef enum {
  e_dir_wg_sel_r0                = 0x0
  ,e_dir_wg_sel_r1               = 0x1
  ,e_dir_wg_sel_r2               = 0x2
  ,e_dir_wg_sel_r3               = 0x3
  ,e_dir_wg_sel_req_addr         = 0x4
  ,e_dir_wg_sel_lru_way_addr     = 0x5
} bp_cce_inst_dir_way_group_sel_e;

#define bp_cce_inst_dir_way_group_sel_width 3

// Source select for Directory LCE input
typedef enum {
  e_dir_lce_sel_r0               = 0x0
  ,e_dir_lce_sel_r1              = 0x1
  ,e_dir_lce_sel_r2              = 0x2
  ,e_dir_lce_sel_r3              = 0x3
  ,e_dir_lce_sel_req_lce         = 0x4
  ,e_dir_lce_sel_transfer_lce    = 0x5
} bp_cce_inst_dir_lce_sel_e;

#define bp_cce_inst_dir_lce_sel_width 3

// Source select for Directory Way input
typedef enum {
  e_dir_way_sel_r0                 = 0x0
  ,e_dir_way_sel_r1                = 0x1
  ,e_dir_way_sel_r2                = 0x2
  ,e_dir_way_sel_r3                = 0x3
  ,e_dir_way_sel_req_addr_way      = 0x4
  ,e_dir_way_sel_lru_way_addr_way  = 0x5
  ,e_dir_way_sel_sh_way_r0         = 0x6
} bp_cce_inst_dir_way_sel_e;

#define bp_cce_inst_dir_way_sel_width 3

// Source select for Directory Coherence State input
typedef enum {
  e_dir_coh_sel_next_coh_st      = 0x0
  ,e_dir_coh_sel_inst_imm        = 0x1
} bp_cce_inst_dir_coh_state_sel_e;

#define bp_cce_inst_dir_coh_state_sel_width 1

// Source select for Directory Tag input
typedef enum {
  e_dir_tag_sel_req_addr         = 0x0
  ,e_dir_tag_sel_lru_way_addr    = 0x1
  ,e_dir_tag_sel_const_0         = 0x2
} bp_cce_inst_dir_tag_sel_e;

#define bp_cce_inst_dir_tag_sel_width 2

// Source select for Transfer LCE register writes
typedef enum {
  e_tr_lce_sel_logic             = 0x0
  ,e_tr_lce_sel_mem_resp         = 0x1
} bp_cce_inst_transfer_lce_sel_e;

#define bp_cce_inst_transfer_lce_sel_width 1

typedef enum {
  e_src_q_lce_req                = 0x0
  ,e_src_q_mem_resp              = 0x1
  ,e_src_q_mem_data_resp         = 0x2
  ,e_src_q_pending               = 0x3
  ,e_src_q_lce_resp              = 0x4
  ,e_src_q_lce_data_resp         = 0x5
} bp_cce_inst_src_q_sel_e;

#define bp_cce_inst_src_q_sel_width 3
#define bp_cce_num_src_q 6

typedef enum {
  e_dst_q_lce_cmd                = 0x0
  ,e_dst_q_lce_data_cmd          = 0x1
  ,e_dst_q_mem_cmd               = 0x2
  ,e_dst_q_mem_data_cmd          = 0x3
} bp_cce_inst_dst_q_sel_e;

#define bp_cce_inst_dst_q_sel_width 2

typedef enum {
  e_rqf_lce_req                  = 0x0
  ,e_rqf_mem_resp                = 0x1
  ,e_rqf_mem_data_resp           = 0x2
  ,e_rqf_pending                 = 0x3
  ,e_rqf_imm0                    = 0x4
} bp_cce_inst_rq_flag_sel_e;

#define bp_cce_inst_rq_flag_sel_width 3

typedef enum {
  e_nerldf_lce_req               = 0x0
  ,e_nerldf_pending              = 0x1
  ,e_nerldf_imm0                 = 0x2
} bp_cce_inst_ner_ld_flag_sel_e;

#define bp_cce_inst_ner_ld_flag_sel_width 2

typedef enum {
  e_nwbf_lce_data_resp           = 0x0
  ,e_nwbf_imm0                   = 0x1
} bp_cce_inst_nwb_flag_sel_e;

#define bp_cce_inst_nwb_flag_sel_width 1

typedef enum {
  e_rwbf_mem_resp                = 0x0
  ,e_rwbf_imm0                   = 0x1
} bp_cce_inst_rwb_flag_sel_e;

#define bp_cce_inst_rwb_flag_sel_width 1

typedef enum {
  e_tf_logic                     = 0x0
  ,e_tf_mem_resp                 = 0x1
  ,e_tf_imm0                     = 0x2
} bp_cce_inst_t_flag_sel_e;

#define bp_cce_inst_t_flag_sel_width 2

typedef enum {
  e_pruief_logic                 = 0x0
  ,e_pruief_imm0                 = 0x1
} bp_cce_inst_pruie_flag_sel_e;

#define bp_cce_inst_pruie_flag_sel_width 1

typedef enum {
  e_lce_cmd_lce_r0               = 0x0
  ,e_lce_cmd_lce_r1              = 0x1
  ,e_lce_cmd_lce_r2              = 0x2
  ,e_lce_cmd_lce_r3              = 0x3
  ,e_lce_cmd_lce_req_lce         = 0x4
  ,e_lce_cmd_lce_tr_lce          = 0x5
  ,e_lce_cmd_lce_0               = 0x6
} bp_cce_inst_lce_cmd_lce_sel_e;

#define bp_cce_inst_lce_cmd_lce_sel_width 3

typedef enum {
  e_lce_cmd_addr_r0              = 0x0
  ,e_lce_cmd_addr_r1             = 0x1
  ,e_lce_cmd_addr_r2             = 0x2
  ,e_lce_cmd_addr_r3             = 0x3
  ,e_lce_cmd_addr_req_addr       = 0x4
  ,e_lce_cmd_addr_lru_way_addr   = 0x5
  ,e_lce_cmd_addr_0              = 0x6
} bp_cce_inst_lce_cmd_addr_sel_e;

#define bp_cce_inst_lce_cmd_addr_sel_width 3

typedef enum {
  e_lce_cmd_way_req_addr_way     = 0x0
  ,e_lce_cmd_way_tr_addr_way     = 0x1
  ,e_lce_cmd_way_sh_list_r0      = 0x2
  ,e_lce_cmd_way_lru_addr_way    = 0x3
  ,e_lce_cmd_way_0               = 0x4
} bp_cce_inst_lce_cmd_way_sel_e;

#define bp_cce_inst_lce_cmd_way_sel_width 3

typedef enum {
  e_mem_data_cmd_addr_lru_way_addr = 0x0
  ,e_mem_data_cmd_addr_req_addr    = 0x1
} bp_cce_inst_mem_data_cmd_addr_sel_e;

#define bp_cce_inst_mem_data_cmd_addr_sel_width 1

// CCE Microcode Instruction Struct
typedef struct __attribute__((__packed__)) {
  bp_cce_inst_op_e op : bp_cce_inst_op_width;
  uint8_t minor_op : bp_cce_inst_minor_op_width;

  bp_cce_inst_src_e src_a : bp_cce_inst_src_width;
  bp_cce_inst_src_e src_b : bp_cce_inst_src_width;
  bp_cce_inst_dst_e dst : bp_cce_inst_dst_width;
  uint16_t imm : bp_cce_inst_gpr_width;

  // Source selects

  // req_lce_r and req_lce_addr_r
  bp_cce_inst_req_sel_e req_sel : bp_cce_inst_req_sel_width;
  // req_addr_way_r
  bp_cce_inst_req_addr_way_sel_e req_addr_way_sel : bp_cce_inst_req_addr_way_sel_width;
  // lru_way_r
  bp_cce_inst_lru_way_sel_e lru_way_sel : bp_cce_inst_lru_way_sel_width;
  // transfer_lce_r and transfer_lce_way_r
  bp_cce_inst_transfer_lce_sel_e transfer_lce_sel : bp_cce_inst_transfer_lce_sel_width;
  // cache_block_data_r
  bp_cce_inst_cache_block_data_sel_e cache_block_data_sel : bp_cce_inst_dat_sel_width;

  // RQF
  bp_cce_inst_rq_flag_sel_e rqf_sel : bp_cce_inst_rq_flag_sel_width;
  // NERF and LDF
  bp_cce_inst_ner_ld_flag_sel_e nerldf_sel : bp_cce_inst_ner_ld_flag_sel_width;
  // NWBF
  bp_cce_inst_nwb_flag_sel_e nwbf_sel : bp_cce_inst_nwb_flag_sel_width;
  // TF
  bp_cce_inst_t_flag_sel_e tf_sel : bp_cce_inst_t_flag_sel_width;
  // PF, RF, UF, IF, EF
  bp_cce_inst_pruie_flag_sel_e pruief_sel : bp_cce_inst_pruie_flag_sel_width;
  // RWBF
  bp_cce_inst_rwb_flag_sel_e rwbf_sel : bp_cce_inst_rwb_flag_sel_width;

  // directory inputs
  bp_cce_inst_dir_way_group_sel_e dir_way_group_sel : bp_cce_inst_dir_way_group_sel_width;
  bp_cce_inst_dir_lce_sel_e dir_lce_sel : bp_cce_inst_dir_lce_sel_width;
  bp_cce_inst_dir_way_sel_e dir_way_sel : bp_cce_inst_dir_way_sel_width;
  bp_cce_inst_dir_coh_state_sel_e dir_coh_state_sel : bp_cce_inst_dir_coh_state_sel_width;
  bp_cce_inst_dir_tag_sel_e dir_tag_sel : bp_cce_inst_dir_tag_sel_width;

  // cce_lce_cmd_queue inputs
  bp_cce_inst_lce_cmd_lce_sel_e lce_cmd_lce_sel : bp_cce_inst_lce_cmd_lce_sel_width;
  bp_cce_inst_lce_cmd_addr_sel_e lce_cmd_addr_sel : bp_cce_inst_lce_cmd_addr_sel_width;
  bp_cce_inst_lce_cmd_way_sel_e lce_cmd_way_sel : bp_cce_inst_lce_cmd_way_sel_width;

  // mem_data_cmd_queue inputs
  bp_cce_inst_mem_data_cmd_addr_sel_e mem_data_cmd_addr_sel : bp_cce_inst_mem_data_cmd_addr_sel_width;

  // Write enables
  uint8_t req_w_v : 1; // req_lce, req_addr, req_tag
  uint8_t req_addr_way_w_v : 1; // req_addr_way
  uint8_t lru_way_w_v : 1;
  uint8_t transfer_lce_w_v : 1; // transfer_lce, transfer_lce_way
  uint8_t cache_block_data_w_v : 1;
  uint8_t ack_type_w_v : 1;

  // flag writes
  uint16_t flag_mask_w_v : bp_cce_inst_num_flags;
} bp_cce_inst_s;

#define bp_cce_inst_s_width \
  bp_cce_inst_op_width \
  + bp_cce_inst_minor_op_width \
  + bp_cce_inst_src_width \
  + bp_cce_inst_src_width \
  + bp_cce_inst_dst_width \
  + bp_cce_inst_gpr_width \
  + bp_cce_inst_req_sel_width \
  + bp_cce_inst_req_addr_way_sel_width \
  + bp_cce_inst_lru_way_sel_width \
  + bp_cce_inst_transfer_lce_sel_width \
  + bp_cce_inst_dat_sel_width \
  + bp_cce_inst_rq_flag_sel_width \
  + bp_cce_inst_ner_ld_flag_sel_width \
  + bp_cce_inst_nwb_flag_sel_width \
  + bp_cce_inst_t_flag_sel_width \
  + bp_cce_inst_pruie_flag_sel_width \
  + bp_cce_inst_rwb_flag_sel_width \
  + bp_cce_inst_dir_way_group_sel_width \
  + bp_cce_inst_dir_lce_sel_width \
  + bp_cce_inst_dir_way_sel_width \
  + bp_cce_inst_dir_coh_state_sel_width \
  + bp_cce_inst_dir_tag_sel_width \
  + bp_cce_inst_lce_cmd_lce_sel_width \
  + bp_cce_inst_lce_cmd_addr_sel_width \
  + bp_cce_inst_lce_cmd_way_sel_width \
  + bp_cce_inst_mem_data_cmd_addr_sel_width \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + bp_cce_inst_num_flags


#endif

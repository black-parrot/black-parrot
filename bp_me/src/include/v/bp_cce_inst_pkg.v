/**
 * bp_cce_inst_pkg.v
 *
 * This file describes the CCE microcode instructions. Any changes made to this file must be
 * reflected in the source code of the CCE microcode assembler, too.
 *
 * Some software operations are supported via assembler transforms rather than being supported
 * directly in hardware (e.g., ALU increment and decrement).
 */

`ifndef BP_CCE_INST_PKG_VH
`define BP_CCE_INST_PKG_VH

package bp_cce_inst_pkg;

  // Major Op Codes
  typedef enum logic [2:0] {
    e_op_alu                               = 3'b000
    ,e_op_branch                           = 3'b001
    ,e_op_move                             = 3'b010
    ,e_op_read_dir                         = 3'b100
    ,e_op_write_dir                        = 3'b101
    ,e_op_misc                             = 3'b110
    ,e_op_queue                            = 3'b111
  } bp_cce_inst_op_e;
  //,e_op_flag                             = 3'b010 // Set and Clear Flag are MOVI variants

  `define bp_cce_inst_op_width $bits(bp_cce_inst_op_e)

  // Minor Op Codes
  typedef enum logic [2:0] {
    e_add_op                               = 3'b000   // Add
    ,e_sub_op                              = 3'b001   // Subtract
  } bp_cce_inst_minor_alu_op_e;
  //,e_inc_op                              = 3'b000   // Increment by 1 // same as ADD, src_b = 1, dst = src_a
  //,e_dec_op                              = 3'b001   // Decrement by 1 // same as DEC, src_b = 1, dst = src_a

  typedef enum logic [2:0] {
    e_bi_op                                = 3'b111   // Branch Immediate (Unconditional)

    ,e_beq_op                              = 3'b010   // Branch if A == B
    ,e_bne_op                              = 3'b011   // Branch if A != B

    ,e_blt_op                              = 3'b100   // Branch if A < B
    ,e_ble_op                              = 3'b101   // Branch if A <= B
  } bp_cce_inst_minor_branch_op_e;
  //,e_bz_op                               = 3'b010   // Branch if A == 0 // same as BEQ, src_b = 0
  //,e_bnz_op                              = 3'b011   // Branch if A != 0 // same as BNE, src_b = 0
  //,e_bf_op                               = 3'b010   // Branch if Flag == 1 // same as BEQ, src_a = flag, src_b = 1
  //,e_bfz_op                              = 3'b010   // Branch if Flag == 0 // same as BEQ, src_a = flag, src_b = 0
  //,e_bqr_op                              = 3'b010   // Branch if Queue.ready == 1 // same as BEQ src_a = queue.ready, src_b = 1
  //,e_bgt_op                              = 3'b100   // Branch if A > B // same as BLT, swap src_a and src_b
  //,e_bge_op                              = 3'b101   // Branch if A >= B // same as BLE, swap src_a and src_b

  typedef enum logic [2:0] {
    e_mov_op                               = 3'b000   // Move src_a to dst
    ,e_movi_op                             = 3'b001   // Move imm to dst
  } bp_cce_inst_minor_mov_op_e;

  typedef enum logic [2:0] {
    e_sf_op                                = 3'b001   // Move imm[0] = 1 to dst(flag)
  } bp_cce_inst_minor_flag_op_e;
  //,e_sfz_op                              = 3'b001   // Move imm[1] = 0 to dst(flag)

  typedef enum logic [2:0] {
    e_rdp_op                               = 3'b000   // Read Directory Pending Bit
    ,e_rdw_op                              = 3'b001   // Read Directory Way Group
    ,e_rde_op                              = 3'b010   // Read Directory Entry
  } bp_cce_inst_minor_read_dir_op_e;

  typedef enum logic [2:0] {
    e_wdp_op                               = 3'b000   // Write Directory Pending Bit
    ,e_wde_op                              = 3'b001   // Write Directory Entry
    ,e_wds_op                              = 3'b010   // Write Directory Entry State
  } bp_cce_inst_minor_write_dir_op_e;

  typedef enum logic [2:0] {
    e_gad_op                               = 3'b000   // Generate Auxiliary Data
    ,e_stall_op                            = 3'b111   // Stall PC
  } bp_cce_inst_minor_misc_op_e;

  typedef enum logic [2:0] {
    e_wfq_op                               = 3'b000   // Wait for Queue Ready
    ,e_pushq_op                            = 3'b001   // Push Queue
    ,e_popq_op                             = 3'b010   // Pop Queue
  } bp_cce_inst_minor_queue_op_e;

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
    ,e_src_const_0                         = 5'b10000
    ,e_src_const_1                         = 5'b10001
    ,e_src_imm                             = 5'b10010
    ,e_src_req_lce                         = 5'b10011
    ,e_src_ack_type                        = 5'b10100
    ,e_src_sharers_hit_r0                  = 5'b10101
    ,e_src_lce_req_ready                   = 5'b11000
    ,e_src_mem_resp_ready                  = 5'b11001
    ,e_src_mem_data_resp_ready             = 5'b11010
    ,e_src_pending_ready                   = 5'b11011
    ,e_src_lce_resp_ready                  = 5'b11100
    ,e_src_lce_data_resp_ready             = 5'b11101
  } bp_cce_inst_src_e;

  `define bp_cce_inst_src_width $bits(bp_cce_inst_src_e)

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
    ,e_dst_next_coh_state                  = 5'b10000
  } bp_cce_inst_dst_e;

  `define bp_cce_inst_dst_width $bits(bp_cce_inst_dst_e)

  typedef enum logic [1:0] {
    e_gpr_r0                               = 2'b00
    ,e_gpr_r1                              = 2'b01
    ,e_gpr_r2                              = 2'b10
    ,e_gpr_r3                              = 2'b11
  } bp_cce_gpr_e;

  // Note: number of gpr must be a power of 2
  `define bp_cce_inst_num_gpr (2**$bits(bp_cce_gpr_e))
  `define bp_cce_inst_gpr_width 16

  typedef enum logic [11:0] {
    e_flag_rqf                             = 12'b0000_0000_0001 // request type flag
    ,e_flag_nerf                           = 12'b0000_0000_0010 // non-exclusive request flag
    ,e_flag_ldf                            = 12'b0000_0000_0100 // lru dirty flag
    ,e_flag_nwbf                           = 12'b0000_0000_1000 // null writeback flag
    ,e_flag_tf                             = 12'b0000_0001_0000 // transfer flag
    ,e_flag_rf                             = 12'b0000_0010_0000 // replacement flag
    ,e_flag_rwbf                           = 12'b0000_0100_0000 // replacement writeback flag
    ,e_flag_pf                             = 12'b0000_1000_0000 // pending flag
    ,e_flag_uf                             = 12'b0001_0000_0000 // upgrade flag
    ,e_flag_if                             = 12'b0010_0000_0000 // invalidate flag
    ,e_flag_ef                             = 12'b0100_0000_0000 // exclusive flag
    ,e_flag_pcf                            = 12'b1000_0000_0000 // pending-cleared flag
  } bp_cce_inst_flag_e;

  `define bp_cce_inst_num_flags $bits(bp_cce_inst_flag_e)

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
  } bp_cce_inst_flag_sel_e;

  `define bp_cce_inst_flag_sel_width $bits(bp_cce_inst_flag_sel_e)

  // source select for reqlce and reqaddr registers writes
  typedef enum logic [1:0] {
    e_req_sel_lce_req                      = 2'b00
    ,e_req_sel_mem_resp                    = 2'b01
    ,e_req_sel_mem_data_resp               = 2'b10
    ,e_req_sel_pending                     = 2'b11
  } bp_cce_inst_req_sel_e;

  `define bp_cce_inst_req_sel_width $bits(bp_cce_inst_req_sel_e)

  typedef enum logic [1:0] {
    e_req_addr_way_sel_logic               = 2'b00
    ,e_req_addr_way_sel_mem_resp           = 2'b01
    ,e_req_addr_way_sel_mem_data_resp      = 2'b10
  } bp_cce_inst_req_addr_way_sel_e;

  `define bp_cce_inst_req_addr_way_sel_width $bits(bp_cce_inst_req_addr_way_sel_e)

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

  // source select for transfer lce register writes
  typedef enum logic {
    e_tr_lce_sel_logic                     = 1'b0
    ,e_tr_lce_sel_mem_resp                 = 1'b1
  } bp_cce_inst_transfer_lce_sel_e;

  `define bp_cce_inst_transfer_lce_sel_width $bits(bp_cce_inst_transfer_lce_sel_e)

  typedef enum logic [2:0] {
    e_src_q_lce_req                        = 3'b000
    ,e_src_q_mem_resp                      = 3'b001
    ,e_src_q_mem_data_resp                 = 3'b010
    ,e_src_q_pending                       = 3'b011
    ,e_src_q_lce_resp                      = 3'b100
    ,e_src_q_lce_data_resp                 = 3'b101
  } bp_cce_inst_src_q_sel_e;

  `define bp_cce_inst_src_q_sel_width $bits(bp_cce_inst_src_q_sel_e)
  `define bp_cce_num_src_q 6

  typedef enum logic [1:0] {
    e_dst_q_lce_cmd                        = 2'b00
    ,e_dst_q_lce_data_cmd                  = 2'b01
    ,e_dst_q_mem_cmd                       = 2'b10
    ,e_dst_q_mem_data_cmd                  = 2'b11
  } bp_cce_inst_dst_q_sel_e;

  `define bp_cce_inst_dst_q_sel_width $bits(bp_cce_inst_dst_q_sel_e)

  typedef enum logic [2:0] {
    e_rqf_lce_req                          = 3'b000
    ,e_rqf_mem_resp                        = 3'b001
    ,e_rqf_mem_data_resp                   = 3'b010
    ,e_rqf_pending                         = 3'b011
    ,e_rqf_imm0                            = 3'b100
  } bp_cce_inst_rq_flag_sel_e;

  `define bp_cce_inst_rq_flag_sel_width $bits(bp_cce_inst_rq_flag_sel_e)

  typedef enum logic [1:0] {
    e_nerldf_lce_req                       = 2'b00
    ,e_nerldf_pending                      = 2'b01
    ,e_nerldf_imm0                         = 2'b10
  } bp_cce_inst_ner_ld_flag_sel_e;

  `define bp_cce_inst_ner_ld_flag_sel_width $bits(bp_cce_inst_ner_ld_flag_sel_e)

  typedef enum logic {
    e_nwbf_lce_data_resp                   = 1'b0
    ,e_nwbf_imm0                           = 1'b1
  } bp_cce_inst_nwb_flag_sel_e;

  `define bp_cce_inst_nwb_flag_sel_width $bits(bp_cce_inst_nwb_flag_sel_e)

  typedef enum logic {
    e_rwbf_mem_resp                        = 1'b0
    ,e_rwbf_imm0                           = 1'b1
  } bp_cce_inst_rwb_flag_sel_e;

  `define bp_cce_inst_rwb_flag_sel_width $bits(bp_cce_inst_rwb_flag_sel_e)

  typedef enum logic [1:0] {
    e_tf_logic                             = 2'b00
    ,e_tf_mem_resp                         = 2'b01
    ,e_tf_imm0                             = 2'b10
  } bp_cce_inst_t_flag_sel_e;

  `define bp_cce_inst_t_flag_sel_width $bits(bp_cce_inst_t_flag_sel_e)

  typedef enum logic {
    e_pruief_logic                         = 1'b0
    ,e_pruief_imm0                         = 1'b1
  } bp_cce_inst_pruie_flag_sel_e;

  `define bp_cce_inst_pruie_flag_sel_width $bits(bp_cce_inst_pruie_flag_sel_e)

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

  typedef enum logic [2:0] {
    e_lce_cmd_way_req_addr_way             = 3'b000
    ,e_lce_cmd_way_tr_addr_way             = 3'b001
    ,e_lce_cmd_way_sh_list_r0              = 3'b010
    ,e_lce_cmd_way_lru_addr_way            = 3'b011
    ,e_lce_cmd_way_0                       = 3'b100
  } bp_cce_inst_lce_cmd_way_sel_e;

  `define bp_cce_inst_lce_cmd_way_sel_width $bits(bp_cce_inst_lce_cmd_way_sel_e)

  typedef enum logic {
    e_mem_data_cmd_addr_lru_way_addr       = 1'b0
    ,e_mem_data_cmd_addr_req_addr          = 1'b1
  } bp_cce_inst_mem_data_cmd_addr_sel_e;

  `define bp_cce_inst_mem_data_cmd_addr_sel_width $bits(bp_cce_inst_mem_data_cmd_addr_sel_e)

  // Instruction immediate fields
  `define bp_cce_inst_flag_imm_bit 0

  // CCE Microcode Instruction Struct
  typedef struct packed {
    bp_cce_inst_op_e                       op;
    bp_cce_inst_minor_op_u                 minor_op;

    bp_cce_inst_src_e                      src_a;
    bp_cce_inst_src_e                      src_b;
    bp_cce_inst_dst_e                      dst;
    logic [`bp_cce_inst_gpr_width-1:0]     imm;

    // Source selects

    // req_lce_r and req_lce_addr_r
    bp_cce_inst_req_sel_e                  req_sel;
    // req_addr_way_r
    bp_cce_inst_req_addr_way_sel_e         req_addr_way_sel;
    // lru_way_r
    bp_cce_inst_lru_way_sel_e              lru_way_sel;
    // transfer_lce_r and transfer_lce_way_r
    bp_cce_inst_transfer_lce_sel_e         transfer_lce_sel;
    // cache_block_data_r
    bp_cce_inst_cache_block_data_sel_e     cache_block_data_sel;

    // RQF
    bp_cce_inst_rq_flag_sel_e              rqf_sel;
    // NERF and LDF
    bp_cce_inst_ner_ld_flag_sel_e          nerldf_sel;
    // NWBF
    bp_cce_inst_nwb_flag_sel_e             nwbf_sel;
    // TF
    bp_cce_inst_t_flag_sel_e               tf_sel;
    // PF, RF, UF, IF, EF
    bp_cce_inst_pruie_flag_sel_e           pruief_sel;
    // RWBF
    bp_cce_inst_rwb_flag_sel_e             rwbf_sel;

    // directory inputs
    bp_cce_inst_dir_way_group_sel_e        dir_way_group_sel;
    bp_cce_inst_dir_lce_sel_e              dir_lce_sel;
    bp_cce_inst_dir_way_sel_e              dir_way_sel;
    bp_cce_inst_dir_coh_state_sel_e        dir_coh_state_sel;
    bp_cce_inst_dir_tag_sel_e              dir_tag_sel;

    // cce_lce_cmd_queue inputs
    bp_cce_inst_lce_cmd_lce_sel_e          lce_cmd_lce_sel;
    bp_cce_inst_lce_cmd_addr_sel_e         lce_cmd_addr_sel;
    bp_cce_inst_lce_cmd_way_sel_e          lce_cmd_way_sel;

    // mem_data_cmd_queue inputs
    bp_cce_inst_mem_data_cmd_addr_sel_e    mem_data_cmd_addr_sel;

    // Write enables
    logic                                  req_w_v; // req_lce, req_addr, req_tag
    logic                                  req_addr_way_w_v; // req_addr_way
    logic                                  lru_way_w_v;
    logic                                  transfer_lce_w_v; // transfer_lce, transfer_lce_way
    logic                                  cache_block_data_w_v;
    logic                                  ack_type_w_v;

    // flag writes
    logic [`bp_cce_inst_num_flags-1:0]     flag_mask_w_v;
  } bp_cce_inst_s;

  `define bp_cce_inst_width $bits(bp_cce_inst_s)

endpackage

`endif

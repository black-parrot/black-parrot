/**
 * bp_cce_decoded_inst.h
 *
 */

#ifndef BP_CCE_DECODED_INST_H
#define BP_CCE_DECODED_INST_H

#include "bp_cce_inst.h"
#include "bp_common_me_if.h"

typedef struct __attribute__((__packed__)) {

  uint8_t minor_op : bp_cce_inst_minor_op_width;
  bp_cce_inst_src_e src_a : bp_cce_inst_src_width;
  bp_cce_inst_src_e src_b : bp_cce_inst_src_width;
  bp_cce_inst_dst_e dst : bp_cce_inst_dst_width;
  uint16_t imm : bp_cce_inst_gpr_width;

  uint8_t alu_v : 1;

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

  // Directory inputs
  uint8_t dir_r_cmd : bp_cce_inst_minor_op_width;
  uint8_t dir_r_v : 1;
  uint8_t dir_w_cmd : bp_cce_inst_minor_op_width;
  uint8_t dir_w_v : 1;

  // cce_lce_cmd_queue inputs
  bp_cce_inst_lce_cmd_lce_sel_e lce_cmd_lce_sel : bp_cce_inst_lce_cmd_lce_sel_width;
  bp_cce_inst_lce_cmd_addr_sel_e lce_cmd_addr_sel : bp_cce_inst_lce_cmd_addr_sel_width;
  bp_cce_inst_lce_cmd_way_sel_e lce_cmd_way_sel : bp_cce_inst_lce_cmd_way_sel_width;

  // LCE Command Queue message command
  bp_cce_lce_cmd_type_e lce_cmd_cmd : bp_cce_lce_cmd_type_width;

  // mem_data_cmd_queue inputs
  bp_cce_inst_mem_data_cmd_addr_sel_e mem_data_cmd_addr_sel : bp_cce_inst_mem_data_cmd_addr_sel_width;

  // Register write enables
  uint8_t mov_dst_w_v : 1;
  uint8_t alu_dst_w_v : 1;
  uint8_t gpr_w_mask : bp_cce_inst_num_gpr;
  uint8_t gpr_w_v : 1;

  uint8_t req_w_v : 1;
  uint8_t req_addr_way_w_v : 1;
  uint8_t lru_way_w_v : 1;
  uint8_t transfer_lce_w_v : 1;
  uint8_t cache_block_data_w_v : 1;
  uint8_t ack_type_w_v : 1;

  uint8_t gad_op_w_v : 1;
  uint8_t rdw_op_w_v : 1;
  uint8_t rde_op_w_v : 1;

  uint16_t flag_mask_w_v : bp_cce_inst_num_flags;

  // uncached requests
  uint8_t nc_data_lce_req : 1;
  uint8_t nc_data_mem_data_resp : 1;
  uint8_t nc_data_w_v : 1;
  uint8_t nc_req_size_w_v : 1;

  // dequeue signals
  uint8_t lce_req_yumi : 1;
  uint8_t lce_resp_yumi : 1;
  uint8_t lce_data_resp_yumi : 1;
  uint8_t mem_resp_yumi : 1;
  uint8_t mem_data_resp_yumi : 1;
  // enqueue signals
  uint8_t lce_cmd_v : 1;
  uint8_t lce_data_cmd_v : 1;
  uint8_t mem_cmd_v : 1;
  uint8_t mem_data_cmd_v : 1;


} bp_cce_inst_decoded_s;

#define bp_cce_inst_decoded_s_width \
  bp_cce_inst_minor_op_width \
  + bp_cce_inst_src_width \
  + bp_cce_inst_src_width \
  + bp_cce_inst_dst_width \
  + bp_cce_inst_gpr_width \
  + 1 \
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
  + bp_cce_inst_minor_op_width \
  + 1 \
  + bp_cce_inst_minor_op_width \
  + 1 \
  + bp_cce_inst_lce_cmd_lce_sel_width \
  + bp_cce_inst_lce_cmd_addr_sel_width \
  + bp_cce_inst_lce_cmd_way_sel_width \
  + bp_cce_lce_cmd_type_width \
  + bp_cce_inst_mem_data_cmd_addr_sel_width \
  + 1 \
  + 1 \
  + bp_cce_inst_num_gpr \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + bp_cce_inst_num_flags \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1 \
  + 1


#endif

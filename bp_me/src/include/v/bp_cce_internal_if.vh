/**
 *
 * Name:
 *   bp_cce_internal_if.vh
 *
 * Description:
 *   This file defines the internal interface structs used within the CCE.
 *
 */

`ifndef BP_CCE_INTERNAL_IF_VH
`define BP_CCE_INTERNAL_IF_VH

`include "bp_common_me_if.vh"
`include "bp_cce_inst_pkg.v"

import bp_cce_inst_pkg::*;

/*
 * bp_cce_inst_decoded_s defines the decoded form of the CCE microcode instructions
 *
 */
typedef struct packed {

  bp_cce_inst_minor_op_u                   minor_op_u;
  bp_cce_inst_src_e                        src_a;
  bp_cce_inst_src_e                        src_b;
  bp_cce_inst_dst_e                        dst;
  logic [`bp_cce_inst_gpr_width-1:0]       imm;

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

  // dequeue signals
  logic                                    lce_req_ready;
  logic                                    lce_resp_ready;
  logic                                    lce_data_resp_ready;
  logic                                    mem_resp_ready;
  logic                                    mem_data_resp_ready;
  // enqueue signals
  logic                                    lce_cmd_v;
  logic                                    lce_data_cmd_v;
  logic                                    mem_cmd_v;
  logic                                    mem_data_cmd_v;

} bp_cce_inst_decoded_s;

`endif

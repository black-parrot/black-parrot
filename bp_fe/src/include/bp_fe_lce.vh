/**
 * bp_fe_lce.vh
 *
 */

`ifndef BP_FE_LCE_VH
`define BP_FE_LCE_VH

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

import bp_common_pkg::*;

/*
 *
*/
typedef enum bit [1:0] {
  e_tag_mem_set_clear   = 2'b00
  ,e_tag_mem_ivalidate  = 2'b01
  ,e_tag_mem_set_tag    = 2'b10
} bp_fe_icache_tag_mem_opcode_e;

`define bp_fe_icache_tag_mem_opcode_width $bits(bp_fe_icache_tag_mem_opcode_e)

typedef enum bit {
  e_meta_data_mem_set_clear = 1'b0
  ,e_meta_data_mem_set_lru   = 1'b1
} bp_fe_icache_meta_data_mem_opcode_e;

`define bp_fe_icache_meta_data_mem_opcode_width $bits(bp_fe_icache_meta_data_mem_opcode_e)

/*
 * bp_fe_lce_cce_req_state_e specifies the state of the cce_lce_cmd.
 */
typedef enum bit [2:0] {
  e_lce_cce_req_ready          = 3'b000
  ,e_lce_cce_req_send_miss_req = 3'b001
  ,e_lce_cce_req_send_ack_tr   = 3'b010
  ,e_lce_cce_req_send_coh_ack  = 3'b011
  ,e_lce_cce_req_sleep         = 3'b100
} bp_fe_lce_cce_req_state_e;

`define bp_fe_lce_cce_req_state_width $bits(bp_fe_lce_cce_req_state_e)

/*
 * bp_fe_cce_lce_cmd_state_e specifies the state of the cce_lce_cmd.
 */
typedef enum bit [1:0] {
  e_cce_lce_cmd_reset     = 2'b00
  ,e_cce_lce_cmd_ready    = 2'b01
  ,e_cce_lce_cmd_transfer = 2'b10
} bp_fe_cce_lce_cmd_state_e;

`define bp_fe_cce_lce_cmd_state_width $bits(bp_fe_cce_lce_cmd_state_e)

/* 
 * data_mem_pkt_s specifies a data memory packet transferred from LCE to the i-cache
*/
`define declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, data_width_p) \
  typedef struct packed {                                                              \
    logic [`BSG_SAFE_CLOG2(lce_sets_p)-1:0]  index;                                    \
    logic [`BSG_SAFE_CLOG2(lce_assoc_p)-1:0] assoc;                                    \
    logic                                    we;                                       \
    logic [data_width_p-1:0]                 data;                                     \
  } bp_fe_icache_lce_data_mem_pkt_s

`define bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p, lce_assoc_p, data_width_p) \
  (`BSG_SAFE_CLOG2(lce_sets_p)+`BSG_SAFE_CLOG2(lce_assoc_p)+data_width_p+1)

/* 
 * tag_mem_pkt_s specifies a tag memory packet transferred from LCE to the i-cache
*/               
`define declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p) \
  typedef struct packed {                                                                          \
    logic [`BSG_SAFE_CLOG2(lce_sets_p)-1:0]    index;                                              \
    logic [`BSG_SAFE_CLOG2(lce_assoc_p)-1:0]   assoc;                                              \
    logic [`BSG_SAFE_CLOG2(coh_states_p)-1:0]  state;                                              \
    logic [tag_width_p-1:0]                    tag;                                                \
    bp_fe_icache_tag_mem_opcode_e              opcode;                                             \
  } bp_fe_icache_lce_tag_mem_pkt_s

`define bp_fe_icache_lce_tag_mem_pkt_width(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p) \
  (`BSG_SAFE_CLOG2(lce_sets_p)+`BSG_SAFE_CLOG2(lce_assoc_p)+`BSG_SAFE_CLOG2(coh_states_p)+tag_width_p+2)

/* 
 * meta_data_mem_pkt_s specifies a meta data memory packet transferred from LCE to the i-cache
*/               
`define declare_bp_fe_icache_lce_meta_data_mem_pkt_s(lce_sets_p, lce_assoc_p) \
  typedef struct packed {                                                     \
    logic [`BSG_SAFE_CLOG2(lce_sets_p)-1:0]  index;                           \
    logic [`BSG_SAFE_CLOG2(lce_assoc_p)-1:0] way;                             \
    bp_fe_icache_meta_data_mem_opcode_e      opcode;                          \
  } bp_fe_icache_lce_meta_data_mem_pkt_s

`define bp_fe_icache_lce_meta_data_mem_pkt_width(lce_sets_p, lce_assoc_p) \
  (`BSG_SAFE_CLOG2(lce_sets_p)+`BSG_SAFE_CLOG2(lce_assoc_p)+1)

`endif

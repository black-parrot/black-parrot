/**
 * bp_fe_lce.vh
 *
 */

`ifndef BP_FE_LCE_VH
`define BP_FE_LCE_VH

`include "bsg_defines.v"

`include "bp_common_me_if.vh"

/*
 *
*/
typedef enum logic [1:0] {
  e_tag_mem_set_clear   = 2'b00
  , e_tag_mem_ivalidate  = 2'b01
  , e_tag_mem_set_tag    = 2'b10
} bp_fe_icache_tag_mem_opcode_e;

`define bp_fe_icache_tag_mem_opcode_width $bits(bp_fe_icache_tag_mem_opcode_e)

typedef enum logic {
  e_metadata_mem_set_clear = 1'b0
  , e_metadata_mem_set_lru   = 1'b1
} bp_fe_icache_metadata_mem_opcode_e;

`define bp_fe_icache_metadata_mem_opcode_width $bits(bp_fe_icache_metadata_mem_opcode_e)

/*
 * bp_fe_lce_cce_req_state_e specifies the state of the lce_cmd.
 */
typedef enum logic [2:0] {
  e_lce_req_ready          = 3'b000
  , e_lce_req_send_miss_req = 3'b001
  , e_lce_req_send_ack_tr   = 3'b010
  , e_lce_req_send_coh_ack  = 3'b011
  , e_lce_req_sleep         = 3'b100
} bp_fe_lce_req_state_e;

`define bp_fe_lce_req_state_width $bits(bp_fe_lce_req_state_e)

/*
 * bp_fe_cce_lce_cmd_state_e specifies the state of the lce_cmd.
 *TODO:same name for transfer used in common
 */
typedef enum logic [1:0] {
  e_lce_cmd_reset     = 2'b00
  , e_lce_cmd_ready    = 2'b01
  , e_lce_cmd_transfer_tmp = 2'b10
} bp_fe_lce_cmd_state_e;

`define bp_fe_lce_cmd_state_width $bits(bp_fe_lce_cmd_state_e)

/* 
 * data_mem_pkt_s specifies a data memory packet transferred from LCE to the i-cache
*/
`define declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, ways_p, data_width_p)      \
  typedef struct packed                                                                \
  {                                                                                    \
    logic [`BSG_SAFE_CLOG2(lce_sets_p)-1:0]  index;                                    \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]      way_id;                                   \
    logic                                    we;                                       \
    logic [data_width_p-1:0]                 data;                                     \
  }  bp_fe_icache_lce_data_mem_pkt_s;

`define bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p, ways_p, data_width_p) \
  (`BSG_SAFE_CLOG2(lce_sets_p)+`BSG_SAFE_CLOG2(ways_p)+data_width_p+1)

/* 
 * tag_mem_pkt_s specifies a tag memory packet transferred from LCE to the i-cache
*/               
`define declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, ways_p, tag_width_p) \
  typedef struct packed {                                                       \
    logic [`BSG_SAFE_CLOG2(lce_sets_p)-1:0]    index;                           \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]        way_id;                          \
    logic [`bp_cce_coh_bits-1:0]               state;                           \
    logic [tag_width_p-1:0]                    tag;                             \
    bp_fe_icache_tag_mem_opcode_e              opcode;                          \
  }  bp_fe_icache_lce_tag_mem_pkt_s;

`define bp_fe_icache_lce_tag_mem_pkt_width(lce_sets_p, ways_p, tag_width_p) \
  (`BSG_SAFE_CLOG2(lce_sets_p)+`BSG_SAFE_CLOG2(ways_p)+`bp_cce_coh_bits+tag_width_p+$bits(bp_fe_icache_tag_mem_opcode_e))

/* 
 * metadata_mem_pkt_s specifies a meta data memory packet transferred from LCE to the i-cache
*/               
`define declare_bp_fe_icache_lce_metadata_mem_pkt_s(lce_sets_p, ways_p)      \
  typedef struct packed {                                                    \
    logic [`BSG_SAFE_CLOG2(lce_sets_p)-1:0] index;                           \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]     way;                             \
    bp_fe_icache_metadata_mem_opcode_e      opcode;                          \
  } bp_fe_icache_lce_metadata_mem_pkt_s;

`define bp_fe_icache_lce_metadata_mem_pkt_width(lce_sets_p, ways_p) \
  (`BSG_SAFE_CLOG2(lce_sets_p)+`BSG_SAFE_CLOG2(ways_p)+$bits(bp_fe_icache_metadata_mem_opcode_e))

`endif

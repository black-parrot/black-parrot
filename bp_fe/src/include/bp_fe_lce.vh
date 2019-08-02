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
  , e_tag_mem_invalidate  = 2'b01
  , e_tag_mem_set_tag    = 2'b10
} bp_fe_icache_tag_mem_opcode_e;

`define bp_fe_icache_tag_mem_opcode_width $bits(bp_fe_icache_tag_mem_opcode_e)

typedef enum logic {
  e_stat_mem_set_clear = 1'b0
  , e_stat_mem_read = 1'b1
} bp_fe_icache_stat_mem_opcode_e;

`define bp_fe_icache_stat_mem_opcode_width $bits(bp_fe_icache_stat_mem_opcode_e)

typedef enum logic [1:0] {
  e_icache_lce_data_mem_write
  , e_icache_lce_data_mem_read
  , e_icache_lce_data_mem_uncached
} bp_fe_icache_lce_data_mem_opcode_e;

`define bp_fe_icache_lce_data_mem_opcode_width $bits(bp_fe_icache_lce_data_mem_opcode_e)

// TODO: might not be needed for icache
typedef enum logic {
  e_icache_lce_mode_uncached
  ,e_icache_lce_mode_normal
} bp_fe_icache_lce_mode_e;

`define bp_fe_icache_lce_mode_bits $bits(bp_fe_icache_lce_mode_e)

/*
 * bp_fe_lce_cce_req_state_e specifies the state of the lce_cmd.
 */
typedef enum logic [2:0] {
  e_lce_req_ready
  , e_lce_req_send_miss_req
  , e_lce_req_send_ack_tr
  , e_lce_req_send_coh_ack
  , e_lce_req_send_uncached_load_req
  , e_lce_req_sleep
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
`define declare_bp_fe_icache_lce_data_mem_pkt_s(sets_p, ways_p, data_width_p)          \
  typedef struct packed                                                                \
  {                                                                                    \
    logic [`BSG_SAFE_CLOG2(sets_p)-1:0]      index;                                    \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]      way_id;                                   \
    logic [data_width_p-1:0]                 data;                                     \
    bp_fe_icache_lce_data_mem_opcode_e       opcode;                                   \
  }  bp_fe_icache_lce_data_mem_pkt_s;

`define bp_fe_icache_lce_data_mem_pkt_width(sets_p, ways_p, data_width_p) \
  (`BSG_SAFE_CLOG2(sets_p)+`BSG_SAFE_CLOG2(ways_p)+data_width_p \
   +`bp_fe_icache_lce_data_mem_opcode_width)

/* 
 * tag_mem_pkt_s specifies a tag memory packet transferred from LCE to the i-cache
*/               
`define declare_bp_fe_icache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_p)     \
  typedef struct packed {                                                       \
    logic [`BSG_SAFE_CLOG2(sets_p)-1:0]        index;                           \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]        way_id;                          \
    logic [`bp_coh_bits-1:0]                   state;                           \
    logic [tag_width_p-1:0]                    tag;                             \
    bp_fe_icache_tag_mem_opcode_e              opcode;                          \
  }  bp_fe_icache_lce_tag_mem_pkt_s;

`define bp_fe_icache_lce_tag_mem_pkt_width(sets_p, ways_p, tag_width_p) \
  (`BSG_SAFE_CLOG2(sets_p)+`BSG_SAFE_CLOG2(ways_p)+`bp_coh_bits+tag_width_p+$bits(bp_fe_icache_tag_mem_opcode_e))

/* 
 * stat_mem_pkt_s specifies a meta data memory packet transferred from LCE to the i-cache
*/               
`define declare_bp_fe_icache_lce_stat_mem_pkt_s(sets_p, ways_p)          \
  typedef struct packed {                                                \
    logic [`BSG_SAFE_CLOG2(sets_p)-1:0]    index;                        \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]    way;                          \
    bp_fe_icache_stat_mem_opcode_e         opcode;                       \
  } bp_fe_icache_lce_stat_mem_pkt_s;

`define bp_fe_icache_lce_stat_mem_pkt_width(sets_p, ways_p) \
  (`BSG_SAFE_CLOG2(sets_p)+`BSG_SAFE_CLOG2(ways_p)+$bits(bp_fe_icache_stat_mem_opcode_e))

/*
 * Declare all lce widths at once as localparams
 */
`define declare_bp_fe_lce_widths(ways_mp, sets_mp, tag_width_mp, lce_data_width_mp)                                \
    , localparam data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(sets_mp,ways_mp,lce_data_width_mp) \
    , localparam tag_mem_pkt_width_lp=`bp_fe_icache_lce_tag_mem_pkt_width(sets_mp,ways_mp,tag_width_mp)        \
    , localparam stat_mem_pkt_width_lp=`bp_fe_icache_lce_stat_mem_pkt_width(sets_mp,ways_mp            \
)

/*
 * Declare all icache-lce-cce width calculations at once as localparams
 */
`define declare_bp_fe_tag_widths(ways_mp, sets_mp, num_lce_mp, num_cce_mp, data_width_mp, paddr_width_mp)   \
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_mp)                                                   \
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_mp)                                                \
    , localparam cce_id_width_lp=`BSG_SAFE_CLOG2(num_cce_mp)                                                \
    , localparam lce_data_width_lp=(ways_mp*data_width_mp)                                                  \
    , localparam block_size_in_words_lp=ways_mp                                                             \
    , localparam data_mask_width_lp=(data_width_mp>>3)                                                      \
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)                                   \
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)                               \
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_mp)                                                    \
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)                          \
    , localparam tag_width_lp=(paddr_width_mp-block_offset_width_lp-index_width_lp                          \
)       

`endif

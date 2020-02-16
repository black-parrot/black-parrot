/**
 * bp_common_cache_service.vh
 */

`ifndef BP_CACHE_MISS_PKT_VH
`define BP_CACHE_MISS_PKT_VH

//`include "bsg_defines.vh"
//`include "bp_common_me_if.vh"

// Miss IF
// Cache Service Interface - Cache miss message type

typedef enum [2:0]
{
  e_miss_load          = 3'b000
  , e_miss_store       = 3'b001
  , e_uc_load          = 3'b010
  , e_uc_store         = 3'b011
  , e_wt_store         = 3'b100
  , e_block_read       = 3'b101
} bp_cache_miss_msg_type_e;

// Cache Service Interface - Cache miss size

typedef enum logic [2:0]
{
  e_size_1B     = 3'b000
  , e_size_2B   = 3'b001
  , e_size_4B   = 3'b010
  , e_size_8B   = 3'b011
  , e_size_16B  = 3'b100
  , e_size_32B  = 3'b101
  , e_size_64B  = 3'b110
} bp_cache_miss_size_e;

// Cache Service Interface - Cache miss structure

`define declare_bp_cache_miss_s(data_width_mp, ways_mp, paddr_width_mp, tag_width_mp) \
 typedef struct packed                             \
 {                                                 \
   logic [data_width_mp-1:0] data;                 \
   logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] repl_way;  \
   logic dirty;                                    \
   bp_cache_miss_size_e size;                      \
   logic [paddr_width_mp-1:0] addr;                \
   logic [tag_width_mp-1:0] tag;                   \
   bp_cache_miss_msg_type_e msg_type;              \
 } bp_cache_miss_s

`define bp_cache_miss_width(data_width_mp, ways_mp, paddr_width_mp, tag_width_mp) \
 (data_width_mp+ways_mp+1+$bits(bp_cache_miss_size_e) \
 +paddr_width_mp+$bits(bp_cache_miss_msg_type_e)+tag_width_mp)

`define declare_bp_cache_miss_widths(data_width_mp, ways_mp, paddr_width_mp, tag_width_mp) \
 , localparam bp_cache_miss_width_lp = `bp_cache_miss_width(data_width_mp, ways_mp, paddr_width_mp, tag_width_mp)

// Fill IF

// Data mem pkt opcodes
typedef enum logic [1:0] {
 // write cache block
 e_cache_data_mem_write,

 // read cache block
 e_cache_data_mem_read,

 // write uncached load data
 e_cache_data_mem_uncached,

 // NOP
 e_cache_data_mem_nop
} bp_cache_data_mem_opcode_e;

`define bp_cache_data_mem_opcode_width $bits(bp_cache_data_mem_opcode_e)

// Tag mem pkt opcodes
typedef enum logic [2:0] {
 // clear all blocks in a set for a given index
 e_cache_tag_mem_set_clear,

 // invalidate a block for given index and way_id
 e_cache_tag_mem_invalidate,

 // set tag and coherence state for given index and way_id
 e_cache_tag_mem_set_tag,

 // read tag mem packets for writeback and transfer (Used for UCE)
 e_cache_tag_mem_read,

 // NOP
 e_cache_tag_mem_nop
} bp_cache_tag_mem_opcode_e;

`define bp_cache_tag_mem_opcode_width $bits(bp_cache_tag_mem_opcode_e)

// Stat mem pkt opcodes
typedef enum logic [1:0] {
 // clear all dirty bits and LRU bits to zero for given index.
 e_cache_stat_mem_set_clear,

 // read stat_info for given index.
 e_cache_stat_mem_read,

 // clear dirty bit for given index and way_id.
 e_cache_stat_mem_clear_dirty,

 // NOP
 e_cache_stat_mem_nop
} bp_cache_stat_mem_opcode_e;

`define bp_cache_stat_mem_opcode_width $bits(bp_cache_stat_mem_opcode_e)

// data mem pkt structure
`define declare_bp_cache_data_mem_pkt_s(sets_p, ways_p, data_width_p)                  \
  typedef struct packed                                                                \
  {                                                                                    \
    logic [`BSG_SAFE_CLOG2(sets_p)-1:0]      index;                                    \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]      way_id;                                   \
    logic [data_width_p-1:0]                 data;                                     \
    bp_cache_data_mem_opcode_e               opcode;                                   \
  }  bp_cache_data_mem_pkt_s;

`define bp_cache_data_mem_pkt_width(sets_p, ways_p, data_width_p) \
  (`BSG_SAFE_CLOG2(sets_p)+`BSG_SAFE_CLOG2(ways_p)+data_width_p \
   +`bp_cache_data_mem_opcode_width)

// tag mem pkt structure
`define declare_bp_cache_tag_mem_pkt_s(sets_p, ways_p, tag_width_p)             \
  typedef struct packed {                                                       \
    logic [`BSG_SAFE_CLOG2(sets_p)-1:0]        index;                           \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]        way_id;                          \
    logic [`bp_coh_bits-1:0]                   state;                           \
    logic [tag_width_p-1:0]                    tag;                             \
    bp_cache_tag_mem_opcode_e                  opcode;                          \
  }  bp_cache_tag_mem_pkt_s;

`define bp_cache_tag_mem_pkt_width(sets_p, ways_p, tag_width_p) \
  (`BSG_SAFE_CLOG2(sets_p)+`BSG_SAFE_CLOG2(ways_p)+`bp_coh_bits+tag_width_p+$bits(bp_cache_tag_mem_opcode_e))

`define declare_bp_cache_stat_mem_pkt_s(sets_p, ways_p)                  \
  typedef struct packed {                                                \
    logic [`BSG_SAFE_CLOG2(sets_p)-1:0]    index;                        \
    logic [`BSG_SAFE_CLOG2(ways_p)-1:0]    way_id;                       \
    bp_cache_stat_mem_opcode_e             opcode;                       \
  } bp_cache_stat_mem_pkt_s;

`define bp_cache_stat_mem_pkt_width(sets_p, ways_p) \
  (`BSG_SAFE_CLOG2(sets_p)+`BSG_SAFE_CLOG2(ways_p)+$bits(bp_cache_stat_mem_opcode_e))

`define declare_bp_cache_if_widths(ways_mp, sets_mp, tag_width_mp, lce_data_width_mp)                                \
    , localparam bp_cache_data_mem_pkt_width_lp=`bp_cache_data_mem_pkt_width(sets_mp,ways_mp,lce_data_width_mp) \
    , localparam bp_cache_tag_mem_pkt_width_lp=`bp_cache_tag_mem_pkt_width(sets_mp,ways_mp,tag_width_mp)        \
    , localparam bp_cache_stat_mem_pkt_width_lp=`bp_cache_stat_mem_pkt_width(sets_mp,ways_mp            \
)

`endif

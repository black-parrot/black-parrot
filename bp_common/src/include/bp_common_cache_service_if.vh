/**
 * bp_common_cache_service.vh
 */

`ifndef BP_COMMON_CACHE_SERVICE_VH
`define BP_COMMON_CACHE_SERVICE_VH

//`include "bsg_defines.vh"
//`include "bp_common_me_if.vh"

// Miss IF
// Cache Service Interface - Cache miss message type

typedef enum logic [2:0]
{
  e_miss_load          = 3'b000
  , e_miss_store       = 3'b001
  , e_uc_load          = 3'b010
  , e_uc_store         = 3'b011
  , e_wt_store         = 3'b100
  , e_cache_flush      = 3'b101
  , e_cache_clear      = 3'b110
} bp_cache_req_msg_type_e;

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
} bp_cache_req_size_e;

// Cache Service Interface - Cache miss structure

`define declare_bp_cache_req_s(data_width_mp, paddr_width_mp, cache_name_mp) \
 typedef struct packed                             \
 {                                                 \
   logic [data_width_mp-1:0] data;                 \
   bp_cache_req_size_e size;                       \
   logic [paddr_width_mp-1:0] addr;                \
   bp_cache_req_msg_type_e msg_type;               \
 }  bp_``cache_name_mp``_req_s

`define bp_cache_req_width(data_width_mp, paddr_width_mp) \
 (data_width_mp+$bits(bp_cache_req_size_e) \
 +paddr_width_mp+$bits(bp_cache_req_msg_type_e))

`define declare_bp_cache_req_metadata_s(ways_mp, cache_name_mp) \
typedef struct packed                              \
{                                                  \
  logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] repl_way;   \
  logic dirty;                                     \
}  bp_``cache_name_mp``_req_metadata_s

`define bp_cache_req_metadata_width(ways_mp) \
  (`BSG_SAFE_CLOG2(ways_mp)+1)

// Fill IF
// Data mem pkt opcodes
typedef enum logic [1:0] {
 // write cache block
 e_cache_data_mem_write,
 // read cache block
 e_cache_data_mem_read,
 // write uncached load data
 e_cache_data_mem_uncached
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
 e_cache_tag_mem_read
} bp_cache_tag_mem_opcode_e;

`define bp_cache_tag_mem_opcode_width $bits(bp_cache_tag_mem_opcode_e)

// Stat mem pkt opcodes
typedef enum logic [1:0] {
 // clear all dirty bits and LRU bits to zero for given index.
 e_cache_stat_mem_set_clear,
 // read stat_info for given index.
 e_cache_stat_mem_read,
 // clear dirty bit for given index and way_id.
 e_cache_stat_mem_clear_dirty
} bp_cache_stat_mem_opcode_e;

`define bp_cache_stat_mem_opcode_width $bits(bp_cache_stat_mem_opcode_e)

// data mem pkt structure
`define declare_bp_cache_data_mem_pkt_s(sets_mp, ways_mp, data_width_mp, cache_name_mp) \
  typedef struct packed                                                                 \
  {                                                                                     \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]      index;                                    \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0]      way_id;                                   \
    logic [data_width_mp-1:0]                 data;                                     \
    bp_cache_data_mem_opcode_e                opcode;                                   \
  }  bp_``cache_name_mp``_data_mem_pkt_s

`define bp_cache_data_mem_pkt_width(sets_mp, ways_mp, data_width_mp) \
  (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+data_width_mp \
   +`bp_cache_data_mem_opcode_width)

// tag mem pkt structure
`define declare_bp_cache_tag_mem_pkt_s(sets_mp, ways_mp, tag_width_mp, cache_name_mp) \
  typedef struct packed {                                                        \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]        index;                           \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0]        way_id;                          \
    logic [`bp_coh_bits-1:0]                    state;                           \
    logic [tag_width_mp-1:0]                    tag;                             \
    bp_cache_tag_mem_opcode_e                   opcode;                          \
  }  bp_``cache_name_mp``_tag_mem_pkt_s

`define bp_cache_tag_mem_pkt_width(sets_mp, ways_mp, tag_width_mp) \
  (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+`bp_coh_bits+tag_width_mp+`bp_cache_tag_mem_opcode_width)

`define declare_bp_cache_stat_mem_pkt_s(sets_mp, ways_mp, cache_name_mp)  \
  typedef struct packed {                                                 \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]    index;                        \
    logic [`BSG_SAFE_CLOG2(ways_mp)-1:0]    way_id;                       \
    bp_cache_stat_mem_opcode_e              opcode;                       \
  } bp_``cache_name_mp``_stat_mem_pkt_s

`define bp_cache_stat_mem_pkt_width(sets_mp, ways_mp) \
  (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+`bp_cache_stat_mem_opcode_width)

`define declare_bp_cache_stat_info_s(ways_mp, cache_name_mp)  \
  typedef struct packed {                 \
    logic [ways_mp-2:0] lru;              \
    logic [ways_mp-1:0] dirty;            \
  } bp_``cache_name_mp``_stat_info_s

`define bp_cache_stat_info_width(ways_mp) \
  (2*ways_mp-1)

`define declare_bp_cache_service_if(addr_width_mp, tag_width_mp, sets_mp, ways_mp, req_data_width_mp, block_data_width_mp, cache_name_mp) \
  `declare_bp_cache_req_s(req_data_width_mp, addr_width_mp, cache_name_mp);               \
  `declare_bp_cache_req_metadata_s(ways_mp, cache_name_mp);                               \
  `declare_bp_cache_data_mem_pkt_s(sets_mp, ways_mp, block_data_width_mp, cache_name_mp); \
  `declare_bp_cache_tag_mem_pkt_s(sets_mp, ways_mp, tag_width_mp, cache_name_mp);         \
  `declare_bp_cache_stat_mem_pkt_s(sets_mp, ways_mp, cache_name_mp)

`define declare_bp_cache_service_if_widths(addr_width_mp, tag_width_mp, sets_mp, ways_mp, req_data_width_mp, block_data_width_mp, cache_name_mp) \
  , localparam ``cache_name_mp``_req_width_lp = `bp_cache_req_width(req_data_width_mp, addr_width_mp)                    \
  , localparam ``cache_name_mp``_req_metadata_width_lp = `bp_cache_req_metadata_width(ways_mp)                           \
  , localparam ``cache_name_mp``_data_mem_pkt_width_lp=`bp_cache_data_mem_pkt_width(sets_mp,ways_mp,block_data_width_mp) \
  , localparam ``cache_name_mp``_tag_mem_pkt_width_lp=`bp_cache_tag_mem_pkt_width(sets_mp,ways_mp,tag_width_mp)          \
  , localparam ``cache_name_mp``_stat_mem_pkt_width_lp=`bp_cache_stat_mem_pkt_width(sets_mp,ways_mp)

`endif

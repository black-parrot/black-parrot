/**
 * bp_fe_icache.vh
 *
 * This file declares the internal structs of the BlackParrot Front End I-Cache
 * module. For simplicity and flexibility, these structs are parameterized. Each
 * struct declares its width separately to prevent pre-processor ordering issues.
 */

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH

`include "bsg_defines.v"
`include "bp_common_me_if.vh"

/*
 *
 * bp_fe_icache_stat_s is the struct that specifies the format of the
 * I-Cache meta-data array. The meta-data array contains the auxiliary
 * information, i.e., dirty bits and LRU bits. A dirty bit indicates whether the
 * corresponding line is dirty. The LRU bits are used to track the recency of
 * access to the ways. The meta-data array format (for a 4-way associative 
 * cache) is as follows:
 * | LRU | dirty | dirty | dirty | dirty |
 *       - way_0 - way_1 - way_2 - way_3 - 
 * For the I-Cache meta-data array, we do not need dirty bits. Upon a miss, the
 * LCE transmits the meta-data (including LRU and dirty bits) information of the
 * tag set to the CCE, and the CCE makes the necessary decisions. 
*/
`define declare_bp_fe_icache_stat_s(ways_mp) \
  typedef struct packed                         \
  {                                             \
    logic [ways_mp-2:0] way;                     \
  }  bp_fe_icache_stat_s

`define bp_fe_icache_stat_width(ways_mp) \
  (ways_mp-1)

// Cache Service Interface - Cache miss message type

typedef enum [2:0]
{
  e_miss_load          = 3'b000
  , e_miss_store       = 3'b001
  , e_uc_load          = 3'b010
  , e_uc_store         = 3'b011
  , e_wt_store         = 3'b100
  , e_block_read_resp  = 3'b101
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

`define declare_bp_cache_miss_s(data_width_mp, ways_mp, paddr_width_mp) \
 typedef struct packed                             \
 {                                                 \
   logic [data_width_mp-1:0] data;                 \
   logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] repl_way;  \
   logic dirty;                                    \
   bp_cache_miss_size_e size;                      \
   logic [paddr_width_mp-1:0] addr;                \
   bp_cache_miss_msg_type_e msg_type;              \
 } bp_cache_miss_s

`define bp_cache_miss_width(data_width_mp, ways_mp, paddr_width_mp) \
 (data_width_mp+ways_mp+1+$bits(bp_cache_miss_size_e) \
 +paddr_width_mp+$bits(bp_cache_miss_msg_type_e))

`define declare_bp_cache_miss_widths(data_width_mp, ways_mp, paddr_width_mp) \
 , localparam bp_cache_miss_width_lp = `bp_cache_miss_width(data_width_mp, ways_mp, paddr_width_mp)

/*
 *
 * bp_fe_icache_tag_set_s is the struct that defines the format of the I-Cache
 * tag array. The tag array consists of state bits as well as physical tag
 * bits. The state bits indicate the state of the cache line according to the
 * cache coherency protocol. L1 I-Cache only has shared (S) and invalid (I)
 * states. The tag array format (for a 4-way associative cache) is as follows:
 * | S | addr | S | addr | S | addr | S | addr |
 * -   way_0  -   way_1  -   way_2 -    way_3  -
 */
`define declare_bp_fe_icache_tag_set_s(tag_width_mp, ways_mp) \
  typedef struct packed                                     \
  {                                                         \
    logic [`bp_coh_bits-1:0]       state;                    \
    logic [tag_width_mp-1:0]       tag;                      \
  }  bp_fe_icache_tag_set_s [ways_mp-1:0]

`define bp_fe_icache_tag_set_width(tag_width_mp, ways_mp) \
  ((`bp_coh_bits+tag_width_mp)*ways_mp)

`define bp_fe_icache_tag_state_width(tag_width_mp) \
  (`bp_coh_bits+tag_width_mp)

/*
 * Declare all icache widths at once as localparams
 */
`define declare_bp_icache_widths(vaddr_width_mp, tag_width_mp, ways_mp)                                \
    , localparam bp_fe_icache_tag_state_width_lp=`bp_fe_icache_tag_state_width(tag_width_mp)           \
    , localparam bp_fe_icache_stat_width_lp=`bp_fe_icache_stat_width(ways_mp)

`endif

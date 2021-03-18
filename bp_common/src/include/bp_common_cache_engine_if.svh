/**
 * bp_common_cache_engine.svh
 */

`ifndef BP_COMMON_CACHE_ENGINE_SVH
`define BP_COMMON_CACHE_ENGINE_SVH

  `define declare_bp_cache_req_s(data_width_mp, paddr_width_mp, cache_name_mp) \
    typedef struct packed                             \
    {                                                 \
      logic hit;                                      \
      logic [data_width_mp-1:0] data;                 \
      bp_cache_req_size_e size;                       \
      logic [paddr_width_mp-1:0] addr;                \
      bp_cache_req_msg_type_e msg_type;               \
      bp_cache_req_wr_subop_e subop;                  \
    }  bp_``cache_name_mp``_req_s

  `define bp_cache_req_width(data_width_mp, paddr_width_mp) \
    (1+data_width_mp+$bits(bp_cache_req_size_e)+paddr_width_mp+$bits(bp_cache_req_msg_type_e)+$bits(bp_cache_req_wr_subop_e))

  `define declare_bp_cache_req_metadata_s(ways_mp, cache_name_mp) \
    typedef struct packed                                   \
    {                                                       \
      logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] hit_or_repl_way; \
      logic dirty;                                          \
    }  bp_``cache_name_mp``_req_metadata_s

  `define bp_cache_req_metadata_width(ways_mp) \
    (`BSG_SAFE_CLOG2(ways_mp)+1)

    typedef enum logic [1:0]
    {// write cache block
     e_cache_data_mem_write
     // read cache block
     ,e_cache_data_mem_read
     // write uncached load data
     ,e_cache_data_mem_uncached
    } bp_cache_data_mem_opcode_e;

    // Tag mem pkt opcodes
    typedef enum logic [2:0]
    {// clear all blocks in a set for a given index
     e_cache_tag_mem_set_clear
     // set tag and coherence state for given index and way_id
     ,e_cache_tag_mem_set_tag
     // set coherence state for given index and way_id
     ,e_cache_tag_mem_set_state
     // read tag mem packets for writeback and transfer (Used for UCE)
     ,e_cache_tag_mem_read
    } bp_cache_tag_mem_opcode_e;

    // Stat mem pkt opcodes
    typedef enum logic [1:0]
    {// clear all dirty bits and LRU bits to zero for given index.
     e_cache_stat_mem_set_clear
     // read stat_info for given index.
     ,e_cache_stat_mem_read
     // clear dirty bit for given index and way_id.
     ,e_cache_stat_mem_clear_dirty
    } bp_cache_stat_mem_opcode_e;

  `define declare_bp_cache_data_mem_pkt_s(sets_mp, ways_mp, block_data_width_mp, fill_width_mp, cache_name_mp) \
    typedef struct packed                                                                     \
    {                                                                                         \
      logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]            index;                                  \
      logic [`BSG_SAFE_CLOG2(ways_mp)-1:0]            way_id;                                 \
      logic [fill_width_mp-1:0]                       data;                                   \
      logic [(block_data_width_mp/fill_width_mp)-1:0] fill_index;                             \
      bp_cache_data_mem_opcode_e                      opcode;                                 \
    }  bp_``cache_name_mp``_data_mem_pkt_s

  `define bp_cache_data_mem_pkt_width(sets_mp, ways_mp, block_data_width_mp, fill_width_mp)   \
    (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+fill_width_mp                          \
     +(block_data_width_mp/fill_width_mp)+$bits(bp_cache_data_mem_opcode_e))

  `define declare_bp_cache_tag_mem_pkt_s(sets_mp, ways_mp, tag_width_mp, cache_name_mp) \
    typedef struct packed                                                          \
    {                                                                              \
      logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]        index;                           \
      logic [`BSG_SAFE_CLOG2(ways_mp)-1:0]        way_id;                          \
      bp_coh_states_e                             state;                           \
      logic [tag_width_mp-1:0]                    tag;                             \
      bp_cache_tag_mem_opcode_e                   opcode;                          \
    }  bp_``cache_name_mp``_tag_mem_pkt_s

  `define bp_cache_tag_mem_pkt_width(sets_mp, ways_mp, tag_width_mp) \
    (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+$bits(bp_coh_states_e)+tag_width_mp+$bits(bp_cache_tag_mem_opcode_e))

  `define declare_bp_cache_tag_info_s(tag_width_mp, cache_name_mp) \
    typedef struct packed {                                                 \
      logic [$bits(bp_coh_states_e)-1:0] state;                             \
      logic [tag_width_mp-1:0]           tag;                               \
    }  bp_``cache_name_mp``_tag_info_s;

  `define bp_cache_tag_info_width(tag_width_mp) \
    ($bits(bp_coh_states_e)+tag_width_mp)

  `define declare_bp_cache_stat_mem_pkt_s(sets_mp, ways_mp, cache_name_mp)  \
    typedef struct packed                                                   \
    {                                                                       \
      logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]    index;                        \
      logic [`BSG_SAFE_CLOG2(ways_mp)-1:0]    way_id;                       \
      bp_cache_stat_mem_opcode_e              opcode;                       \
    }  bp_``cache_name_mp``_stat_mem_pkt_s

  `define bp_cache_stat_mem_pkt_width(sets_mp, ways_mp) \
    (`BSG_SAFE_CLOG2(sets_mp)+`BSG_SAFE_CLOG2(ways_mp)+$bits(bp_cache_stat_mem_opcode_e))

  `define declare_bp_cache_stat_info_s(ways_mp, cache_name_mp)  \
    typedef struct packed                          \
    {                                              \
      logic [`BSG_SAFE_MINUS(ways_mp, 2):0] lru;   \
      logic [ways_mp-1:0]                   dirty; \
    }  bp_``cache_name_mp``_stat_info_s

  // Direct mapped caches need 2-bits in the stat info
  `define bp_cache_stat_info_width(ways_mp) \
    (`BSG_MAX(2,2*ways_mp-1))

  `define declare_bp_cache_engine_if(addr_width_mp, tag_width_mp, sets_mp, ways_mp, req_data_width_mp, block_data_width_mp, fill_width_mp, cache_name_mp) \
    `declare_bp_cache_req_s(req_data_width_mp, addr_width_mp, cache_name_mp);                              \
    `declare_bp_cache_req_metadata_s(ways_mp, cache_name_mp);                                              \
    `declare_bp_cache_data_mem_pkt_s(sets_mp, ways_mp, block_data_width_mp, fill_width_mp, cache_name_mp); \
    `declare_bp_cache_tag_mem_pkt_s(sets_mp, ways_mp, tag_width_mp, cache_name_mp);                        \
    `declare_bp_cache_tag_info_s(tag_width_mp, cache_name_mp);                                             \
    `declare_bp_cache_stat_mem_pkt_s(sets_mp, ways_mp, cache_name_mp);                                     \
    `declare_bp_cache_stat_info_s(ways_mp, cache_name_mp);


  `define declare_bp_cache_engine_if_widths(addr_width_mp, tag_width_mp, sets_mp, ways_mp, req_data_width_mp, block_data_width_mp, fill_width_mp, cache_name_mp) \
    , localparam ``cache_name_mp``_req_width_lp = `bp_cache_req_width(req_data_width_mp, addr_width_mp)                                  \
    , localparam ``cache_name_mp``_req_metadata_width_lp = `bp_cache_req_metadata_width(ways_mp)                                         \
    , localparam ``cache_name_mp``_data_mem_pkt_width_lp=`bp_cache_data_mem_pkt_width(sets_mp,ways_mp,block_data_width_mp,fill_width_mp) \
    , localparam ``cache_name_mp``_tag_mem_pkt_width_lp=`bp_cache_tag_mem_pkt_width(sets_mp,ways_mp,tag_width_mp)                        \
    , localparam ``cache_name_mp``_tag_info_width_lp=`bp_cache_tag_info_width(tag_width_mp)                                              \
    , localparam ``cache_name_mp``_stat_mem_pkt_width_lp=`bp_cache_stat_mem_pkt_width(sets_mp,ways_mp)                                   \
    , localparam ``cache_name_mp``_stat_info_width_lp=`bp_cache_stat_info_width(ways_mp)

`endif

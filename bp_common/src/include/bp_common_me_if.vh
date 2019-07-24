/**
 * bp_common_me_if.vh
 *
 * This file defines the interface between the CCEs and LCEs, and the CCEs and memory in the
 * BlackParrot coherence system. For ease of reuse and flexiblity, this interface is defined as a
 * collection of parameterized structs.
 *
 */

`ifndef BP_COMMON_ME_IF_VH
`define BP_COMMON_ME_IF_VH

`include "bsg_defines.v"

/*
 *
 * LCE-CCE Interface
 *
 * The following enums and structs define the LCE-CCE Interface within a BlackParrot coherence
 * system.
 *
 * There are 5 logical networks/message types:
 * 1. LCE Request
 * 2. LCE Response
 * 3. LCE Data Response
 * 4. LCE Command
 * 5. LCE Data Command
 *
 * These five logical message types are carried on three networks:
 * 1. Request (low priority)
 * 2. Command (medium priority), LCE Commands and Data Commands
 * 3. Response (high priority), LCE Responses and Data Responses
 *
 * A Request message may cause a Command message, and a Command message may cause a Response.
 * A higher priority message may not cause a lower priority message to be sent, which avoids
 * a circular dependency between message classes.
 *
 * LCE Request Processing Flow:
 *  At a high level, a cache miss is handled by an LCE Request being sent to the CCE, followed by
 *  a series of commands and and responses that handle invalidating, evicting, and writing-back
 *  blocks as needed, sending data and tags to the LCE, and concluding with the LCE sending a response
 *  to the CCE managing the transaction. The length of a coherence transaction depends on the type of
 *  request (read- or write-miss), the current state of the requested block, and the current state of
 *  the cache way that the miss will be filled into.
 *
 *
 * Clients should use the declare_bp_me_if() macro to declare all of the interface structs at once.
 *
 */



/* TODO list

1. Do we care about alignment of cache block data field in message, and the relation of flit payload
   size to cache block data size? Having flit payload size be power of 2 and having cache block data
   aligned to flits could make transfer between LCE-CCE-MEM easier to handle in the CCE in particular.

*/


/*
 *
 * LCE to CCE Request
 *
 */

/*
 * bp_lce_cce_req_type_e specifies whether the containing message is related to a read or write
 * cache miss request from and LCE.
 */
typedef enum bit [2:0]
{
  e_lce_req_type_rd          = 3'b000 // Read-miss
  , e_lce_req_type_wr        = 3'b001 // Write-miss
  , e_lce_req_type_uc_rd     = 3'b010 // Uncached Read-miss
  , e_lce_req_type_uc_wr     = 3'b011 // Uncached Write-miss
  // 3'b100 - 3'b111 reserved / custom
} bp_lce_cce_req_type_e;

`define bp_lce_cce_req_type_width $bits(bp_lce_cce_req_type_e)

/*
 * bp_lce_cce_req_non_excl_e specifies whether the requesting LCE would like a read-miss request
 * to be returned in an exclusive coherence state if possible or not. An I$, for example, should
 * set this bit to indicate that there is no benefit in the CCE granting a cache block in the E
 * state as opposed to the S state in a MESI protocol. The CCE treats this bit as a hint, and is
 * not required to follow it.
 */
typedef enum bit 
{
  e_lce_req_excl             = 1'b0 // exclusive cache line request (read-only, exclusive request)
  , e_lce_req_non_excl       = 1'b1 // non-exclusive cache line request (read-only, shared request)
} bp_lce_cce_req_non_excl_e;

`define bp_lce_cce_req_non_excl_width $bits(bp_lce_cce_req_non_excl_e)

/*
 * bp_lce_cce_lru_dirty_e specifies whether the LRU way in an LCE request (bp_lce_cce_req_s)
 * contains a dirty cache block. The 
 */
typedef enum bit 
{
  e_lce_req_lru_clean        = 1'b0 // lru way from requesting lce's tag set is clean
  , e_lce_req_lru_dirty      = 1'b1 // lru way from requesting lce's tag set is dirty
} bp_lce_cce_lru_dirty_e;

`define bp_lce_cce_lru_dirty_width $bits(bp_lce_cce_lru_dirty_e)

/*
 * bp_lce_cce_uc_req_size_e defines the size of a uncached load or store request, in bytes.
 *
 */
typedef enum bit [1:0]
{
  e_lce_uc_req_1   = 2'b00
  , e_lce_uc_req_2 = 2'b01
  , e_lce_uc_req_4 = 2'b10
  , e_lce_uc_req_8 = 2'b11
} bp_lce_cce_uc_req_size_e;

`define bp_lce_cce_uc_req_size_width $bits(bp_lce_cce_uc_req_size_e)

/*
 * bp_lce_cce_req_s defines an LCE request sent by an LCE to a CCE on a cache miss. An LCE enters
 *   a Stall state after sending a request, and it may not send another request until it is
 *   "woken up" by a Set Tag and Wakeup command from the CCE or after receiving a Set Tag command
 *   from a CCE and either a Write Data command from a CCE or an LCE to LCE Transfer from an LCE.
 * dst_id is the CCE responsible for the cache missing address
 * src_id is the requesting LCE
 * msg_type indicates if this is a read or write miss request
 * non_exclusive indicates if the requesting cache prefers non-exclusive read-access
 * addr is the cache missing address
 * lru_way_id indicates the way within the target set that will be used to fill the miss in to
 * lru_dirty indicates if the LRU way was dirty or clean when the miss request was sent
 */

`define declare_bp_lce_cce_req_req_s(addr_width_mp, lce_assoc_mp) \
  typedef struct packed                                         \
  {                                                             \
    bp_lce_cce_lru_dirty_e                       lru_dirty;     \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    lru_way_id;    \
    logic [addr_width_mp-1:0]                    addr;          \
    bp_lce_cce_req_non_excl_e                    non_exclusive; \
  }  bp_lce_cce_req_req_s

`define declare_bp_lce_cce_req_uc_req_s(addr_width_mp, data_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
    bp_lce_cce_uc_req_size_e                     uc_size;       \
    logic [addr_width_mp-1:0]                    addr;          \
  }  bp_lce_cce_req_uc_req_s

`define declare_bp_lce_cce_req_s(num_cce_mp, num_lce_mp, msg_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [msg_width_mp-1:0]                     msg;           \
    bp_lce_cce_req_type_e                        msg_type;      \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id;        \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      dst_id;        \
  }  bp_lce_cce_req_s


/*
 *
 * CCE to LCE Command
 *
 */

/*
 * bp_cce_lce_cmd_type_e defines the various commands that an CCE may issue to an LCE
 * e_lce_cmd_sync is used at the end of reset to direct the LCE to inform the CCE it is ready
 * e_lce_cmd_set_clear is sent by the CCE to invalidate an entire cache set in the LCE
 * e_lce_cmd_transfer is sent to command an LCE to transfer an entire cache block to another LCE
 * e_lce_cmd_set_tag is sent to update the tag and coherence state of a single cache line
 * e_lce_cmd_set_tag_wakeup is the same as e_lce_cmd_set_tag, plus it tells the LCE to wake up
 *   and resume normal execution. This is sent only when the CCE detects a write-miss request
 *   is actually an upgrade request.
 * e_lce_cmd_invalidate_tag is sent to invalidate a single cache entry. This command results in
 *   the coherence state of the specified entry being changed to Invalid (no read or write
 *   permissions)
 */
typedef enum bit [3:0] 
{
  e_lce_cmd_sync             = 4'b0000
  ,e_lce_cmd_set_clear       = 4'b0001
  ,e_lce_cmd_transfer        = 4'b0010
  ,e_lce_cmd_writeback       = 4'b0011
  ,e_lce_cmd_set_tag         = 4'b0100
  ,e_lce_cmd_set_tag_wakeup  = 4'b0101
  ,e_lce_cmd_invalidate_tag  = 4'b0110
  ,e_lce_cmd_uc_st_done      = 4'b0111
  // 4'b1000 - 4'b1111 reserved / custom
} bp_cce_lce_cmd_type_e;

`define bp_cce_lce_cmd_type_width $bits(bp_cce_lce_cmd_type_e)

/*
 * bp_cce_coh_states_e defines the coherence states available in BlackParrot. Each bit represents
 * a property of the cache block as defined below:
 * 0: Shared (not Exclusive)
 * 1: Owned
 * 2: Potentially Dirty
 *
 * These properties are derived from "A Primer on Memory Consistency and Cache Coherence", and
 * they allow an easy definition for the common MOESIF coherence states.
 */
typedef enum bit [2:0] 
{
  e_COH_I                   = 3'b000 // Invalid
  ,e_COH_S                  = 3'b001 // Shared - clean, not owned, shared (not exclusive)
  ,e_COH_E                  = 3'b010 // Exclusive - clean, owned, not shared (exclusive)
  ,e_COH_F                  = 3'b011 // Forward - clean, owned, shared (not exclusive)
  //                          3'b100 - potentially dirty, not owned, not shared (exclusive)
  //                          3'b101 - potentially dirty, not owned, shared (not exclusive)
  ,e_COH_M                  = 3'b110 // Modified - potentially dirty, owned, not shared (exclusive)
  ,e_COH_O                  = 3'b111 // Owned - potentially dirty, owned, shared (not exclusive)
} bp_coh_states_e;

`define bp_coh_shared_bit 0
`define bp_coh_owned_bit 1
`define bp_coh_dirty_bit 2

`define bp_coh_bits $bits(bp_coh_states_e)

// LCE Command Network Message Types
typedef enum logic [1:0] {
  e_lce_cmd_cmd            // command
  ,e_lce_cmd_data          // cache block data to LCE, i.e., cache block fill
  ,e_lce_cmd_uc_data       // unached data to LCE, i.e, up to 64-bits data
} bp_lce_cmd_type_e;

`define bp_lce_cmd_type_width $bits(bp_lce_cmd_type_e)

/**
 *  bp_lce_cmd_cmd_s defines a command sent by a CCE to and LCE
 *
 *  src_id:        is the CCE sending the command
 *  msg_type:      is the command
 *  addr:          specifies the memory address associated with the command
 *  way_id:        is the way within the set that addr maps to in the LCE that should be used for the command
 *  state:         specifies the Coherence State to be used for invalidate, set_tag, and set_tag_wakeup
 *  target:        is the LCE that will receive a transfer for a transfer command
 *  target_way_id: is the way within the target LCE's set (computed from addr) to fill the data in to
 */
`define declare_bp_lce_cmd_cmd_s(num_cce_mp, num_lce_mp, addr_width_mp, lce_assoc_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    target_way_id; \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      target;        \
    logic [`bp_coh_bits-1:0]                     state;         \
    logic [addr_width_mp-1:0]                    addr;          \
    bp_cce_lce_cmd_type_e                        msg_type;      \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      src_id;        \
  }  bp_lce_cmd_cmd_s;                                          \


/**
 *  bp_lce_cmd_data_s is used to send cache block data from CCE to LCE or from LCE to LCE.
 *
 *  way_id:   the way within the receiving LCE's target set to fill the data in to.
 *  data:     the cache block data
 */
`define declare_bp_lce_cmd_data_s(data_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
  }  bp_lce_cmd_data_s;                                         \

/**
 *  bp_lce_cmd_uc_data_s is used to send cache block data from CCE to LCE or from LCE to LCE.
 *
 *  data:     the uncached load data
 */
`define declare_bp_lce_cmd_uc_data_s(data_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
  }  bp_lce_cmd_uc_data_s;                                      \

/**
 *  bp_lce_cmd_s is the generic message for LCE Command and LCE Data Command that is sent across the
 *  Command network from CCE to LCE.
 *
 *  Although not required, It is designed to be sent through a wormhole routed network that will send
 *  the minimum number of flits required, based on the msg_type field.
 *
 *  msg_type: indicates the type of message and implies the size of the message payload
 *
 */
`define declare_bp_lce_cmd_s(num_lce_mp, lce_assoc_mp, msg_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [msg_width_mp-1:0]                     msg;           \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;        \
    bp_lce_cmd_type_e                            msg_type;      \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      dst_id;        \
  } bp_lce_cmd_s


/*
 *
 * LCE to CCE Response
 *
 */

/*
 * bp_lce_cce_ack_type_e defines the types of ACK messages that an LCE may send to an CCE
 *   in an bp_lce_cce_resp_s response message
 * e_lce_cce_sync_ack acknowledges receipt and processing of a Sync command
 * e_lce_cce_inv_ack acknowledges that an LCE has processed an Invalidation command
 * e_lce_cce_coh_ack acknowledges than an LCE has received both a set tag command AND a data
 *   command, or a set tag and wakeup command from the CCE. The sending LCE considers itself woken
 *   up after sending this ACK.
 */
typedef enum bit [2:0] 
{
  e_lce_cce_sync_ack         = 3'b000
  ,e_lce_cce_inv_ack         = 3'b001
  ,e_lce_cce_coh_ack         = 3'b010
  // 3'b011 - 3'b111 reserved / custom
} bp_lce_cce_ack_type_e;

`define bp_lce_cce_ack_type_width $bits(bp_lce_cce_ack_type_e)

/*
 * bp_lce_cce_resp_s is sent from an LCE to an CCE to acknowledge a command
 * dst_id is the CCE that sent the command causing this ack message response
 * src_id is the LCE sending the ack
 * msg_type is the type of ack being sent
 * addr is the address associated with the command sent by the CCE
 *
 * NOTE: addr is undefined/unused for e_lce_cce_sync_ack
 */
`define declare_bp_lce_cce_resp_resp_s(addr_width_mp) \
  typedef struct packed                                    \
  {                                                        \
    logic [addr_width_mp-1:0]                    addr;     \
    bp_lce_cce_ack_type_e                        msg_type; \
  } bp_lce_cce_resp_resp_s


/*
 * bp_lce_cce_msg_type_e is an enum that is used by the LCE when sending a writeback response
 *   to indicate if the response contains valid data
 * e_lce_resp_wb indicates the data field (cache block data) is valid, and that the LCE ahd the
 *   cache block in a dirty state
 * e_lce_resp_null_wb indicates that the LCE never wrote to the cache block and the block is still
 *   clean. The data field should be 0 and is invalid.
 */

typedef enum logic
{
  e_lce_cce_resp_wb              = 1'b0  // Normal Writeback Response (full data)
  ,e_lce_cce_resp_null_wb        = 1'b1  // Null Writeback Response (no data)
} bp_lce_cce_resp_data_msg_type_e;

`define bp_lce_cce_resp_data_msg_type_width $bits(bp_lce_cce_resp_data_msg_type_e)

/*
 * bp_lce_cce_data_resp_s is used by an LCE to respond to a writeback command from the CCE
 * dst_id is the CCE that commanded the writeback
 * src_id is the LCE responding to the command
 * msg_type indicates if the target cache block was dirty or clean in the LCE
 * addr is the memory address of the cache block being written back
 * data is the cache block data (if this is not a null writeback)
 */
`define declare_bp_lce_cce_resp_data_s(addr_width_mp, data_width_mp) \
  typedef struct packed                                    \
  {                                                        \
    logic [data_width_mp-1:0]                    data;     \
    logic [addr_width_mp-1:0]                    addr;     \
    bp_lce_cce_resp_data_msg_type_e              msg_type; \
  } bp_lce_cce_resp_data_s

typedef enum logic
{
  e_lce_cce_resp_ack               = 1'b0  // Acks, other responses
  ,e_lce_cce_resp_data             = 1'b1  // Data Response
} bp_lce_cce_resp_type_e;

`define bp_lce_cce_resp_type_width $bits(bp_lce_cce_resp_type_e)

/**
 *  bp_lce_cce_resp_s is the generic message for LCE Response and LCE Data Response that is sent across the
 *  Response network from LCE to CCE.
 *
 *  It is designed to be sent through a wormhole routed network that will send
 *  the minimum number of flits required, based on the msg_type field.
 *
 *  msg_type: indicates the type of message and implies the size of the message payload
 *
 */
`define declare_bp_lce_cce_resp_s(num_cce_mp, num_lce_mp, msg_width_mp) \
  typedef struct packed                                     \
  {                                                         \
    logic [msg_width_mp-1:0]                     msg;       \
    bp_lce_cce_resp_type_e                       msg_type;  \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id;    \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      dst_id;    \
  } bp_lce_cce_resp_s


/*
 *
 * CCE-Memory Interface
 *
 */

/*
 * bp_cce_mem_cmd_type_e specifies the memory command from the CCE
 */
typedef enum bit [2:0]
{
  e_cce_mem_rd        = 3'b000  // Read-miss request
  , e_cce_mem_wr      = 3'b001  // Write-miss request
  , e_cce_mem_uc_rd   = 3'b010  // Uncached load
  , e_cce_mem_uc_wr   = 3'b011  // Uncached store
  , e_cce_mem_wb      = 3'b100  // Cache block Writeback
  , e_mem_cce_inv     = 3'b101  // Invalidate block (from Mem to CCE)
  // 3'b110 - 3'b111 reserved / custom
} bp_cce_mem_cmd_type_e;

`define bp_cce_mem_cmd_type_width $bits(bp_cce_mem_cmd_type_e)

/*
 *
 * CCE to Mem Command
 *
 */

/*
 * bp_cce_mem_cmd_payload_s defines a payload that is sent to the memory system by the CCE as part
 * of bp_cce_mem_cmd_s and returned by the mem to the CCE in bp_mem_cce_data_resp_s. This data
 * is not required by the memory system to complete the request.
 *
 * lce_id is the LCE that sent the initial cache miss request
 * way_id is the way within the cache miss address target set to fill the data in to
 */

`define declare_bp_cce_mem_cmd_payload_s(num_lce_mp, lce_assoc_mp) \
  typedef struct packed                                       \
  {                                                           \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      lce_id;      \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;      \
  }  bp_cce_mem_cmd_payload_s


/*
 * bp_cce_mem_cmd_s is sent by a CCE to the Memory to request a cache block
 * msg_type indicates if this block is for a read or write cache miss
 * addr is the memory address from the cache miss
 * payload is data sent to mem and returned to cce unmodified
 */
`define declare_bp_cce_mem_cmd_s(addr_width_mp, data_width_mp)  \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
    bp_cce_mem_cmd_payload_s                     payload;       \
    bp_lce_cce_uc_req_size_e                     uc_size;       \
    logic [addr_width_mp-1:0]                    addr;          \
    bp_cce_mem_cmd_type_e                        msg_type;      \
  }  bp_cce_mem_cmd_s

/*
 *
 * Mem to CCE Response
 *
 */

/*
 * bp_mem_cce_resp_s is sent from the Memory to a CCE to acknowledge completion of a writeback
 * dst_id is the CCE that initiated the writeback request
 * src_id is the Memory that is responding
 * msg_type indicates if this block is for a read or write cache miss
 *
 */
`define declare_bp_mem_cce_resp_s(addr_width_mp, data_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
    bp_cce_mem_cmd_payload_s                     payload;       \
    bp_lce_cce_uc_req_size_e                     uc_size;       \
    logic [addr_width_mp-1:0]                    addr;          \
    bp_cce_mem_cmd_type_e                        msg_type;      \
  } bp_mem_cce_resp_s


/*
 * Width Macros
 */

// CCE-LCE Interface
`define bp_lce_cce_req_req_width(addr_width_mp, lce_assoc_mp) \
  (`bp_lce_cce_req_non_excl_width+addr_width_mp+`BSG_SAFE_CLOG2(lce_assoc_mp) \
   +`bp_lce_cce_lru_dirty_width)

`define bp_lce_cce_req_uc_req_width(addr_width_mp, data_width_mp) \
  (addr_width_mp+`bp_lce_cce_uc_req_size_width+data_width_mp)

`define bp_lce_cce_req_width(num_cce_mp, num_lce_mp, msg_width_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cce_req_type_width \
   +msg_width_mp)

`define bp_lce_cmd_cmd_width(num_cce_mp, num_lce_mp, addr_width_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`bp_cce_lce_cmd_type_width+addr_width_mp+`bp_coh_bits \
   +`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_lce_cmd_data_width(data_width_mp) (data_width_mp)

`define bp_lce_cmd_uc_data_width(data_width_mp) (data_width_mp)

`define bp_lce_cmd_width(num_lce_mp, lce_assoc_mp, msg_width_mp) \
  (`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cmd_type_width+`BSG_SAFE_CLOG2(lce_assoc_mp)+msg_width_mp)

`define bp_lce_cce_resp_resp_width(addr_width_mp) \
  (`bp_lce_cce_ack_type_width+addr_width_mp)

`define bp_lce_cce_resp_data_width(addr_width_mp, data_width_mp) \
  (`bp_lce_cce_resp_data_msg_type_width+addr_width_mp+data_width_mp)

`define bp_lce_cce_resp_width(num_cce_mp, num_lce_mp, msg_width_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cce_resp_type_width+msg_width_mp)

// CCE-MEM Interface
`define bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_cce_mem_cmd_width(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_cce_mem_cmd_type_width+addr_width_mp+data_width_mp \
   +`bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp)\
   +`bp_lce_cce_uc_req_size_width)

`define bp_mem_cce_resp_width(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_cce_mem_cmd_type_width+addr_width_mp+data_width_mp \
   +`bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp) \
   +`bp_lce_cce_uc_req_size_width)

/*
 * 
 * LCE-CCE Interface Macro
 *
 * This macro defines all of the lce-cce interface stucts and port widths at once as localparams
 *
 */
`define declare_bp_lce_cce_if(num_cce_mp, num_lce_mp, paddr_width_mp, lce_assoc_mp, data_width_mp, cce_block_width_mp, lce_req_msg_width_mp, lce_cmd_msg_width_mp, lce_resp_msg_width_mp) \
  `declare_bp_lce_cce_req_req_s(paddr_width_mp, lce_assoc_mp);                                    \
  `declare_bp_lce_cce_req_uc_req_s(paddr_width_mp, data_width_mp);                                \
  `declare_bp_lce_cce_req_s(num_cce_mp, num_lce_mp, lce_req_msg_width_mp);                        \
  `declare_bp_lce_cmd_cmd_s(num_cce_mp, num_lce_mp, paddr_width_mp, lce_assoc_mp);                \
  `declare_bp_lce_cmd_data_s(cce_block_width_mp);                                                 \
  `declare_bp_lce_cmd_uc_data_s(data_width_mp);                                                   \
  `declare_bp_lce_cmd_s(num_lce_mp, lce_assoc_mp, lce_cmd_msg_width_mp);                          \
  `declare_bp_lce_cce_resp_resp_s(paddr_width_mp);                                                \
  `declare_bp_lce_cce_resp_data_s(paddr_width_mp, cce_block_width_mp);                            \
  `declare_bp_lce_cce_resp_s(num_cce_mp, num_lce_mp, lce_resp_msg_width_mp);


`define declare_bp_lce_cce_if_widths(num_cce_mp, num_lce_mp, paddr_width_mp, lce_assoc_mp, data_width_mp, cce_block_width_mp) \
    , localparam lce_cce_req_req_width_lp=`bp_lce_cce_req_req_width(paddr_width_mp             \
                                                                    ,lce_assoc_mp              \
                                                                    )                          \
    , localparam lce_cce_req_uc_req_width_lp=`bp_lce_cce_req_uc_req_width(paddr_width_mp       \
                                                                       ,data_width_mp          \
                                                                       )                       \
    , localparam lce_cce_req_msg_width_lp=`BSG_MAX(lce_cce_req_req_width_lp                    \
                                                   ,lce_cce_req_uc_req_width_lp                \
                                                   )                                           \
    , localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_mp                         \
                                                            ,num_lce_mp                        \
                                                            ,lce_cce_req_msg_width_lp          \
                                                            )                                  \
    , localparam lce_cce_resp_resp_width_lp=`bp_lce_cce_resp_resp_width(paddr_width_mp)        \
    , localparam lce_cce_resp_data_width_lp=`bp_lce_cce_resp_data_width(paddr_width_mp         \
                                                                        ,cce_block_width_mp    \
                                                                        )                      \
    , localparam lce_cce_resp_msg_width_lp=`BSG_MAX(lce_cce_resp_resp_width_lp                 \
                                                    ,lce_cce_resp_data_width_lp                \
                                                    )                                          \
    , localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_mp                       \
                                                              ,num_lce_mp                      \
                                                              ,lce_cce_resp_msg_width_lp       \
                                                              )                                \
    , localparam lce_cmd_cmd_width_lp=`bp_lce_cmd_cmd_width(num_cce_mp                         \
                                                            ,num_lce_mp                        \
                                                            ,paddr_width_mp                    \
                                                            ,lce_assoc_mp                      \
                                                            )                                  \
    , localparam lce_cmd_data_width_lp=`bp_lce_cmd_data_width(cce_block_width_mp)              \
    , localparam lce_cmd_uc_data_width_lp=`bp_lce_cmd_uc_data_width(data_width_mp)             \
    , localparam lce_cmd_msg_width_lp=`BSG_MAX(`BSG_MAX(lce_cmd_cmd_width_lp                   \
                                                        , lce_cmd_data_width_lp)               \
                                               ,lce_cmd_uc_data_width_lp                       \
                                               )                                               \
    , localparam lce_cmd_width_lp=`bp_lce_cmd_width(num_lce_mp                                 \
                                                    ,lce_assoc_mp                              \
                                                    ,lce_cmd_msg_width_lp                      \
                                                    )

/*
 *
 * Memory End Interface Macro
 *
 * This macro defines all of the memory end interface struct and port widths at once as localparams
 *
 */

`define declare_bp_me_if(paddr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  `declare_bp_cce_mem_cmd_payload_s(num_lce_mp, lce_assoc_mp);                    \
  `declare_bp_cce_mem_cmd_s(paddr_width_mp, data_width_mp);                       \
  `declare_bp_mem_cce_resp_s(paddr_width_mp, data_width_mp);

`define declare_bp_me_if_widths(paddr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  , localparam cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_mp                 \
                                                          ,data_width_mp                 \
                                                          ,num_lce_mp                    \
                                                          ,lce_assoc_mp)                 \
  , localparam mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_mp               \
                                                            ,data_width_mp               \
                                                            ,num_lce_mp                  \
                                                            ,lce_assoc_mp)               \


`endif

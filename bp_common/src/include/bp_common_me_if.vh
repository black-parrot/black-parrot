/**
 * bp_common_me_if.vh
 *
 * This file defines the interface between the CCEs and LCEs, and the CCEs and L2 memory in the
 * BlackParrot cohrence system. For ease of reuse and flexiblity, this interface is defined as a
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
 * At a high level, the coherence system works as follows. This flow omits the actions between
 * the CCE and Memory, since they are hidden from the LCEs. All cache misses (load-miss and
 * store-miss) result in the LCE requesting a cache block and appropriate permissions from a CCE.
 *
 * 1. An LCE takes a cache miss and issues a bp_lce_cce_req_s to a CCE. The LCE stalls after
 *    issuing the request. At this point, the LCE waits to be "woken up".
 * 2. If the request was a write-miss (upgrade), the CCE will respond with a bp_cce_lce_cmd_s
 *    set tag and wakeup message to grant write permissions and wake up the LCE. The LCE also sends
 *    a coherence ack in a bp_lce_cce_resp_s, which completes the upgrade request.
 * 3. The CCE will invalidate any LCE's that have a copy of the requested block by sending an
 *    invalidation command in bp_cce_lce_cmd_s, and wait for all acks in bp_lce_cce_resp_s
 *    messages.
 * 4. If needed, the CCE will perform a writeback for the cache block in the requesting LCE's
 *    LRU way. The CCE sends a bp_cce_lce_cmd_s for writeback and waits for a
 *    bp_lce_cce_data_resp_s from the LCE.
 * 5. At this point, the CCE coordinates either reading a block from memory or directing an LCE
 *    to LCE transfer to satisfy the request.
 * 5a. In the case of reading from memory, the CCE will retrieve the block then send both a
 *     bp_cce_lce_cmd_s to set the tag and bp_cce_lce_data_cmd_s to provide the data block. Once
 *     the LCE receives both messages, the LCE sends a coherence ack in a bp_lce_cce_resp_s message
 *     to the CCE. The cache miss is complete and the LCE is now "woken up".
 * 5b. In the case of an LCE to LCE transfer, the CCE sends a bp_cce_lce_cmd_s to the LCE that
 *     will provide the block to initiate a transfer to the requesting LCE, and then sends a
 *     bp_cce_lce_cmd_s set tag message to the requesting LCE. The LCE sending the transfer sends
 *     a bp_lce_lce_tr_resp_s to supply the requested data. Once the cache-missing LCE receives
 *     both the transfer response and set tag command, it sends a bp_lce_cce_resp_s to ack the
 *     receipt of the data transfer and set tag command, and it considers itself "woken up".
 * 6. If an LCE to LCE transfer occurred, the CCE will also perform a writeback of the block
 *    that was in the source LCE of the transfer. It does this by sending a bp_cce_lce_cmd_s
 *    for writeback and then waits for a bp_lce_cce_data_resp_s. The CCE finishes the writeback to
 *    the memory.
 *
 * LCE Input Message Priorities (highest to lowest)
 * 1. bp_cce_lce_data_cmd_s
 * 2. bp_lce_lce_tr_resp_s
 * 3. bp_cce_lce_cmd_s
 *
 * CCE Input Message Priorities
 * 1. bp_mem_cce_data_resp_s
 * 2. bp_mem_cce_resp_s
 * 3. bp_lce_cce_req_s
 *
 *
 * Clients should use declare_bp_me_if(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp)
 *   to declare all me_if structs at once.
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
typedef enum bit 
{
  e_lce_req_type_rd          = 1'b0 // Read-miss
  , e_lce_req_type_wr        = 1'b1 // Write-miss
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
  , e_lce_req_not_excl       = 1'b1 // non-exclusive cache line request (read-only, shared request)
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
`define declare_bp_lce_cce_req_s(num_cce_mp, num_lce_mp, addr_width_mp, lce_assoc_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      dst_id;        \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id;        \
    bp_lce_cce_req_type_e                        msg_type;      \
    bp_lce_cce_req_non_excl_e                    non_exclusive; \
    logic [addr_width_mp-1:0]                    addr;          \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    lru_way_id;    \
    bp_lce_cce_lru_dirty_e                       lru_dirty;     \
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
typedef enum bit [2:0] 
{
  e_lce_cmd_sync             = 3'b000
  ,e_lce_cmd_set_clear       = 3'b001
  ,e_lce_cmd_transfer        = 3'b010
  ,e_lce_cmd_writeback       = 3'b011
  ,e_lce_cmd_set_tag         = 3'b100
  ,e_lce_cmd_set_tag_wakeup  = 3'b101
  ,e_lce_cmd_invalidate_tag  = 3'b110
} bp_cce_lce_cmd_type_e;

`define bp_cce_lce_cmd_type_width $bits(bp_cce_lce_cmd_type_e)

/*
 * bp_cce_coh_mesi_e defines the coherence states for a MESI protocol
 * e_MESI_I means the block is invalid and the LCE does not have read or write permissions
 * e_MESI_S means the block is valid and the LCE has read permissions
 * e_MESI_E means the block is valid and the LCE has read and write permissions. The block may or
 *   may not be dirty in the LCE.
 * e_MESI_M has the same meaning as e_MESI_E, but the CCE knows the block is dirty
 */
typedef enum bit [1:0] 
{
  e_MESI_I                   = 2'b00
  ,e_MESI_S                  = 2'b01
  ,e_MESI_E                  = 2'b10
  ,e_MESI_M                  = 2'b11
} bp_cce_coh_mesi_e;

/*
 * bp_cce_coh_vi_e defines the coherence states for a Valid/Invalid style protocol.
 * In VI, the V state is equivalent to e_MESI_E, and I is the same as e_MESI_I.
 */
typedef enum bit [1:0] 
{
  e_VI_I                     = 2'b00
  ,e_VI_V                    = 2'b10
} bp_cce_coh_vi_e;

typedef union packed 
{
  bp_cce_coh_vi_e            vi;
  bp_cce_coh_mesi_e          mesi;
}  bp_cce_coh_u;

`define bp_cce_coh_bits $bits(bp_cce_coh_u)

/*
 * bp_cce_lce_cmd_s defines a command sent by a CCE to and LCE
 * dst_id is the LCE receiving the command
 * src_id is the CCE sending the command
 * msg_type is the command
 * addr specifies the memory address associated with the command
 * way_id is the way within the set that addr maps to in the LCE that should be used for the command
 * state specifies the Coherence State to be used for invalidate, set_tag, and set_tag_wakeup
 * target is the LCE that will receive a transfer for a transfer command
 * target_way_id is the way within the target LCE's set (computed from addr) to fill the data in to
 */
`define declare_bp_cce_lce_cmd_s(num_cce_mp, num_lce_mp, addr_width_mp, lce_assoc_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      dst_id;        \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      src_id;        \
    bp_cce_lce_cmd_type_e                        msg_type;      \
    logic [addr_width_mp-1:0]                    addr;          \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;        \
    logic [`bp_cce_coh_bits-1:0]                 state;         \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      target;        \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    target_way_id; \
  }  bp_cce_lce_cmd_s

/*
 *
 * CCE to LCE Data Command
 *
 */

/*
 * bp_cce_lce_data_cmd_s is used to send cache block data from an CCE to an LCE in response to a
 *   cache miss request. Once an LCE receives this message and a set tag message, it considers
 *   itself to be woken up and can resume normal execution.
 * dst_id is the LCE receiving the cache block data
 * src_id is the CCE sending the cache block data
 * msg_type indicates if this cache block data is in response to a read or write cache miss
 * way_id is the way within the receiving LCE's target set to fill the data in to
 * addr is the memory address of the cache miss
 * data is the cache block data
 */
`define declare_bp_cce_lce_data_cmd_s(num_cce_mp, num_lce_mp, addr_width_mp, data_width_mp, lce_assoc_mp) \
  typedef struct packed                                    \
  {                                                        \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      dst_id;   \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      src_id;   \
    bp_lce_cce_req_type_e                        msg_type; \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;   \
    logic [addr_width_mp-1:0]                    addr;     \
    logic [data_width_mp-1:0]                    data;     \
  }  bp_cce_lce_data_cmd_s

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
 * e_lce_cce_tr_ack acknowledges that an LCE has received both a set tag command AND an LCE to
 *   LCE data transfer message to complete its cache miss. The sending LCE considers itself woken
 *   up after sending this ACK.
 * e_lce_cce_coh_ack acknowledges than an LCE has received both a set tag command AND a data
 *   command, or a set tag and wakeup command from the CCE. The sending LCE considers itself woken
 *   up after sending this ACK.
 */
typedef enum bit [1:0] 
{
  e_lce_cce_sync_ack         = 2'b00
  ,e_lce_cce_inv_ack         = 2'b01
  ,e_lce_cce_tr_ack          = 2'b10
  ,e_lce_cce_coh_ack         = 2'b11
} bp_lce_cce_ack_type_e;

`define bp_lce_cce_ack_type_width $bits(bp_lce_cce_ack_type_e)

/*
 * bp_lce_cce_resp_s is sent from an LCE to an CCE to acknowledge a command
 * dst_id is the CCE that sent the command causing this ack message response
 * src_id is the LCE sending the ack
 * msg_type is the type of ack being sent
 * addr is the address associated with the command sent by the CCE
 *
 * NOTE: addr is not valid for e_lce_cce_sync_ack
 */
`define declare_bp_lce_cce_resp_s(num_cce_mp, num_lce_mp, addr_width_mp) \
  typedef struct packed                                    \
  {                                                        \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      dst_id;   \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id;   \
    bp_lce_cce_ack_type_e                        msg_type; \
    logic [addr_width_mp-1:0]                    addr;     \
  } bp_lce_cce_resp_s

/*
 *
 * LCE to LCE Transfer Response
 *
 */

/*
 * bp_lce_lce_tr_resp_s is sent from one LCE to another to satisfy a transfer command from a CCE.
 *   This message performs a direct LCE to LCE data transfer.
 * dst_id is the LCE receiving the cache block transfer
 * src_id is the LCE sending the cache block transfer
 * way_id is the way within the receiving LCE's target set to fill the data in to
 * addr is the memory address of the cache block being written back
 * data is the cache block data (if this is not a null writeback)
 */
`define declare_bp_lce_lce_tr_resp_s(num_lce_mp, addr_width_mp, data_width_mp, lce_assoc_mp) \
  typedef struct packed                                  \
  {                                                      \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      dst_id; \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id; \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id; \
    logic [addr_width_mp-1:0]                    addr;   \
    logic [data_width_mp-1:0]                    data;   \
  } bp_lce_lce_tr_resp_s

/*
 *
 * LCE to CCE Data Response
 *
 */

/*
 * bp_lce_cce_wb_resp_type_e is an enum that is used by the LCE when sending a writeback response
 *   to indicate if the response contains valid data
 * e_lce_resp_wb indicates the data field (cache block data) is valid, and that the LCE ahd the
 *   cache block in a dirty state
 * e_lce_resp_null_wb indicates that the LCE never wrote to the cache block and the block is still
 *   clean. The data field should be 0 and is invalid.
 */
typedef enum bit 
{
  e_lce_resp_wb              = 1'b0 // Normal Writeback Response
  ,e_lce_resp_null_wb        = 1'b1 // Null Writeback Response
} bp_lce_cce_wb_resp_type_e;

`define bp_lce_cce_wb_resp_type_width $bits(bp_lce_cce_wb_resp_type_e)

/*
 * bp_lce_cce_data_resp_s is used by an LCE to respond to a writeback command from the CCE
 * dst_id is the CCE that commanded the writeback
 * src_id is the LCE responding to the command
 * msg_type indicates if the target cache block was dirty or clean in the LCE
 * addr is the memory address of the cache block being written back
 * data is the cache block data (if this is not a null writeback)
 */
`define declare_bp_lce_cce_data_resp_s(num_cce_mp, num_lce_mp, addr_width_mp, data_width_mp) \
  typedef struct packed                                    \
  {                                                        \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      dst_id;   \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id;   \
    bp_lce_cce_wb_resp_type_e                    msg_type; \
    logic [addr_width_mp-1:0]                    addr;     \
    logic [data_width_mp-1:0]                    data;     \
  } bp_lce_cce_data_resp_s

/*
 *
 * CCE-Memory Interface
 *
 */

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
`define declare_bp_cce_mem_cmd_s(addr_width_mp) \
  typedef struct packed                                    \
  {                                                        \
    bp_lce_cce_req_type_e                        msg_type; \
    logic [addr_width_mp-1:0]                    addr;     \
    bp_cce_mem_cmd_payload_s                     payload;  \
  }  bp_cce_mem_cmd_s

/*
 *
 * Mem to CCE Data Response
 *
 */

/*
 * bp_mem_cce_data_resp_s is sent from the Memory to a CCE to supply a requested cache block
 * msg_type indicates if this block is for a read or write cache miss
 * addr is the memory address from the cache miss
 * payload is data sent to mem and returned to cce unmodified
 * data is the cache block data supplied by memory
 */
`define declare_bp_mem_cce_data_resp_s(addr_width_mp, data_width_mp) \
  typedef struct packed                                    \
  {                                                        \
    bp_lce_cce_req_type_e                        msg_type; \
    logic [addr_width_mp-1:0]                    addr;     \
    bp_cce_mem_cmd_payload_s                     payload;  \
    logic [data_width_mp-1:0]                    data;     \
  } bp_mem_cce_data_resp_s

/*
 *
 * CCE to Mem Data Command
 *
 */

/*
 * bp_cce_mem_data_cmd_payload_s defines a payload that is sent to the memory system by the CCE and
 * returned unmodified back to the CCE
 *
 * lce_id is the LCE that sent the initial cache miss request
 * way_id is the way within the cache miss address target set to fill the data in to
 * req_addr is the memory address from the cache miss
 * tr_lce_id is the LCE that will supply the data for an LCE to LCE transfer if required
 * tr_way_id is the way in the tr_lce_id's set that will supply the data
 * transfer is a bit that indicates if the cache miss that caused this writeback will be satisfied
 *   with an LCE to LCE transfer (1) or reading from memory (0)
 * replacement is a bit that indicates if this is a response to a writeback command that occured
 *   while performing a cache line replacement/eviction in the requesting LCE
 *
 * NOTE: lce_id, way_id, req_addr, tr_lce_id, tr_way_id, transfer, and replacement fields are
 * sent to memory and will be return to the CCE unmodified in an bp_mem_cce_resp_s
 */

`define declare_bp_cce_mem_data_cmd_payload_s(num_lce_mp, lce_assoc_mp, addr_width_mp) \
  typedef struct packed                                       \
  {                                                           \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      lce_id;      \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;      \
    logic [addr_width_mp-1:0]                    req_addr;    \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      tr_lce_id;   \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    tr_way_id;   \
    logic                                        transfer;    \
    logic                                        replacement; \
  } bp_cce_mem_data_cmd_payload_s

/*
 * bp_cce_mem_data_cmd_s is sent from a CCE to the Memory to perform a cache block writeback
 * dst_id is the memory that will perform the writeback
 * src_id is the CCE initiating the writeback
 * msg_type indicates if this block is for a read or write cache miss
 * payload is information included by the CCE that the memory system will return unmodified
 *
 */
`define declare_bp_cce_mem_data_cmd_s(addr_width_mp, data_width_mp) \
  typedef struct packed                                       \
  {                                                           \
    bp_lce_cce_req_type_e                        msg_type;    \
    logic [addr_width_mp-1:0]                    addr;        \
    bp_cce_mem_data_cmd_payload_s                payload;     \
    logic [data_width_mp-1:0]                    data;        \
  } bp_cce_mem_data_cmd_s

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
 * payload is information included by the CCE that the memory system will return unmodified
 *
 */
`define declare_bp_mem_cce_resp_s(addr_width_mp) \
  typedef struct packed                                       \
  {                                                           \
    bp_lce_cce_req_type_e                        msg_type;    \
    logic [addr_width_mp-1:0]                    addr;        \
    bp_cce_mem_data_cmd_payload_s                payload;     \
  } bp_mem_cce_resp_s

/*
 *
 * Memory End Interface Macro
 *
 * This macro defines all of the memory end interface structs at once
 *
 */

`define declare_bp_me_if(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  `declare_bp_cce_mem_cmd_payload_s(num_lce_mp, lce_assoc_mp);                     \
  `declare_bp_cce_mem_data_cmd_payload_s(num_lce_mp, lce_assoc_mp, addr_width_mp); \
  `declare_bp_cce_mem_cmd_s(addr_width_mp);                                        \
  `declare_bp_mem_cce_data_resp_s(addr_width_mp, data_width_mp);                   \
  `declare_bp_cce_mem_data_cmd_s(addr_width_mp, data_width_mp);                    \
  `declare_bp_mem_cce_resp_s(addr_width_mp);

/*
 * Width Macros
 */

// CCE-LCE Interface
`define bp_lce_cce_req_width(num_cce_mp, num_lce_mp, addr_width_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cce_req_type_width \
   +`bp_lce_cce_req_non_excl_width+addr_width_mp+`BSG_SAFE_CLOG2(lce_assoc_mp) \
   +`bp_lce_cce_lru_dirty_width)

`define bp_cce_lce_cmd_width(num_cce_mp, num_lce_mp, addr_width_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_cce_lce_cmd_type_width \
   +addr_width_mp+(2*`BSG_SAFE_CLOG2(lce_assoc_mp))+`bp_cce_coh_bits+`BSG_SAFE_CLOG2(num_lce_mp))

`define bp_cce_lce_data_cmd_width(num_cce_mp, num_lce_mp, addr_width_mp, data_width_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cce_req_type_width \
   +`BSG_SAFE_CLOG2(lce_assoc_mp)+addr_width_mp+data_width_mp)

`define bp_lce_cce_resp_width(num_cce_mp, num_lce_mp, addr_width_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cce_ack_type_width+addr_width_mp)

`define bp_lce_lce_tr_resp_width(num_lce_mp, addr_width_mp, data_width_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(lce_assoc_mp) \
    +addr_width_mp+data_width_mp)

`define bp_lce_cce_data_resp_width(num_cce_mp, num_lce_mp, addr_width_mp, data_width_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+`bp_lce_cce_wb_resp_type_width \
   +addr_width_mp+data_width_mp)

// CCE-MEM Interface
`define bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_cce_mem_data_cmd_payload_width(num_lce_mp, lce_assoc_mp, addr_width_mp) \
  ((2*`BSG_SAFE_CLOG2(num_lce_mp))+(2*`BSG_SAFE_CLOG2(lce_assoc_mp))+addr_width_mp+2)

`define bp_cce_mem_cmd_width(addr_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_lce_cce_req_type_width+addr_width_mp+`bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp))

`define bp_cce_mem_data_cmd_width(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_lce_cce_req_type_width+addr_width_mp+data_width_mp \
   +`bp_cce_mem_data_cmd_payload_width(num_lce_mp, lce_assoc_mp, addr_width_mp))

`define bp_mem_cce_resp_width(addr_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_lce_cce_req_type_width+addr_width_mp \
   +`bp_cce_mem_data_cmd_payload_width(num_lce_mp, lce_assoc_mp, addr_width_mp))

`define bp_mem_cce_data_resp_width(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_lce_cce_req_type_width+addr_width_mp+data_width_mp \
   +`bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp))

`endif
